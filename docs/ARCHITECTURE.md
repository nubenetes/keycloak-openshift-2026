# Multi-Cluster Enterprise Architecture: Red Hat Build of Keycloak on OpenShift 4.20+

This document outlines the multi-cluster identity architecture deployed across 3 OpenShift Container Platform (OCP) 4.20+ clusters on AWS, integrated with Microsoft Entra ID (Azure AD), on-premises Active Directory, and an optional 4th Central Parent Hub Keycloak.

---

## 1. Global Multi-Cluster Topology

```mermaid
graph TD
    subgraph CorpID["Corporate Identity Layer (Hybrid)"]
        Entra["<b>Microsoft Entra ID</b><br/>Cloud Users & Groups<br/>Conditional Access & MFA<br/>App Registrations"]
        AD["<b>Active Directory</b><br/>On-Premises LDAPS<br/>Domain User Accounts"]
        EntraSync["<b>Entra Cloud Sync</b><br/>Hybrid DirSync Engine"]
        AD <-->|Password Hash Sync| EntraSync
        EntraSync <-->|OIDC Provisioning| Entra
    end

    subgraph HubCluster["(Optional) Central Identity Hub (OCP)"]
        HubKC["<b>Parent Keycloak (RHBK)</b><br/>Central Broker & Policy Engine"]
        HubDB[("<b>AWS Aurora DB</b><br/>Global PostgreSQL")]
        HubKC <--> HubDB
    end

    subgraph SpokeDev["Cluster 1: Alpha (Dev)"]
        KC1["<b>Keycloak Dev</b><br/>1 Replica"]
        Apps1["<b>Dev Workloads</b><br/>ArgoCD & Backstage"]
        KC1 <--> Apps1
    end

    subgraph SpokeStage["Cluster 2: Bravo (Stage)"]
        KC2["<b>Keycloak Stage</b><br/>2 Replicas (HA)"]
        Apps2["<b>Stage Workloads</b><br/>Microservices & APIs"]
        KC2 <--> Apps2
    end

    subgraph SpokeProd["Cluster 3: Charlie (Prod HA)"]
        KC3["<b>Keycloak Prod HA</b><br/>3+ Replicas (Multi-AZ)"]
        Apps3["<b>Production Apps</b><br/>Angular SPA & APIs"]
        KC3 <--> Apps3
    end

    Entra -->|OIDC Federation| HubKC
    AD -->|LDAPS Sync| HubKC
    Entra -.->|Direct OIDC| KC1
    Entra -.->|Direct OIDC| KC2
    Entra -.->|Direct OIDC| KC3
    HubKC -->|Hub Delegation| KC1
    HubKC -->|Hub Delegation| KC2
    HubKC -->|Hub Delegation| KC3

    classDef corp fill:#e0f2fe,stroke:#0284c7,stroke-width:2px,color:#0f172a;
    classDef hub fill:#fef3c7,stroke:#d97706,stroke-width:2px,color:#0f172a;
    classDef spoke fill:#f0fdf4,stroke:#16a34a,stroke-width:2px,color:#0f172a;

    class Entra,AD,EntraSync corp;
    class HubKC,HubDB hub;
    class KC1,Apps1,KC2,Apps2,KC3,Apps3 spoke;
```

---

## 2. Topology Comparison & Architectural Trade-offs

| Topology Pattern | Deployment Mode | Description | Pros | Considerations |
| :--- | :--- | :--- | :--- | :--- |
| **Independent Multi-Cluster** | Spoke Clusters 1, 2, 3 connect directly to Entra ID | Each OpenShift cluster hosts its own RHBK instance with identical declarative realm imports | • Autonomous failure domains<br/>• Low latency (local cluster DB)<br/>• Simple GitOps reconciliation | Requires Entra ID redirect URI registration for each cluster route |
| **Hub-Spoke Hierarchical** | Cluster 4 acts as Parent Hub; Clusters 1-3 act as Spokes | The Parent Keycloak acts as the single federated IdP to Entra ID; spoke clusters federate to Parent Keycloak | • Single Entra ID App Registration<br/>• Centralized audit & session revocation<br/>• Standardized cross-cluster policies | WAN dependency on Hub cluster if offline caching is not enabled |
| **Cross-Site Replicated HA** | Multi-Region OpenShift with Infinispan Cross-Site | Active-Active Keycloak deployment with WAN state replication over JGroups RELAY2 | • Near-instant failover<br/>• Shared user sessions across regions | Complex networking (AWS Transit Gateway / Submariner) |

---

## 3. High Availability, Caching & Data Persistence

1. **Quarkus Runtime & Memory Footprint**:
   - RHBK uses the optimized Quarkus runtime, achieving sub-second startup times and lower memory footprint (~1.5 GB per pod vs ~3.5 GB in legacy WildFly RHSSO).
2. **Infinispan Distributed Caching**:
   - `sessions`, `authenticationSessions`, `offlineSessions`, `loginFailures`, `actionTokens` are distributed across pods with 2 owner copies (`owners=2`).
   - Discovery is managed natively via Kubernetes DNS ping (`jgroups.dns.query=keycloak-discovery.keycloak.svc`).
3. **Database Tier**:
   - High availability PostgreSQL 16 managed via Crunchy Data PGO with automated streaming replication across AWS availability zones and continuous WAL archiving to S3.
