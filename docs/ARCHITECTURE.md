# Multi-Cluster Enterprise Architecture: Red Hat Build of Keycloak on OpenShift 4.20+

This document outlines the multi-cluster identity architecture deployed across 3 OpenShift Container Platform (OCP) 4.20+ clusters on AWS, integrated with Microsoft Entra ID (Azure AD), on-premises Active Directory, and an optional 4th Central Parent Hub Keycloak.

---

## 1. Global Multi-Cluster Topology

```mermaid
graph TD
    subgraph Corporate_Identity["Corporate Identity Layer (Hybrid)"]
        Entra["Microsoft Entra ID (Azure AD)<br/>• Cloud Users & Groups<br/>• Conditional Access / MFA<br/>• Enterprise App Registrations"]
        AD["On-Premises Active Directory<br/>• Windows Server Kerberos/LDAPS<br/>• Corporate Domain Accounts"]
        EntraConnect["Entra Cloud Sync / Connect<br/>Hybrid Identity Synchronization"]
        AD <-->|DirSync / Password Hash| EntraConnect
        EntraConnect <-->|Sync| Entra
    end

    subgraph Hub_Cluster["(Optional) Central Identity Hub (OCP Cluster-Hub)"]
        HubKC["Central Parent Keycloak<br/>(Master Broker & Policy Engine)"]
        HubDB[("AWS Aurora PostgreSQL<br/>Global Multi-Region")]
        HubKC <--> HubDB
    end

    subgraph AWS_Spoke_Clusters["OpenShift 4.20+ Spoke Clusters (AWS)"]
        subgraph Cluster1["Cluster 1: Alpha (Dev)"]
            KC1["RHBK Operator<br/>Keycloak Instance (1 replica)"]
            Apps1["ArgoCD / Backstage / Dev Apps"]
            KC1 <--> Apps1
        end

        subgraph Cluster2["Cluster 2: Bravo (Stage)"]
            KC2["RHBK Operator<br/>Keycloak Instance (2 replicas)"]
            Apps2["Stage Workloads & Microservices"]
            KC2 <--> Apps2
        end

        subgraph Cluster3["Cluster 3: Charlie (Prod HA)"]
            KC3["RHBK Operator<br/>Keycloak HA (3+ replicas, Multi-AZ)"]
            Apps3["Production APIs & Angular SPA"]
            KC3 <--> Apps3
        end
    end

    Entra -->|OIDC Brokering| HubKC
    AD -->|LDAPS User Federation| HubKC
    Entra -.->|Direct OIDC Brokering| KC1
    Entra -.->|Direct OIDC Brokering| KC2
    Entra -.->|Direct OIDC Brokering| KC3
    HubKC -->|Hub-to-Spoke OIDC Delegation| KC1
    HubKC -->|Hub-to-Spoke OIDC Delegation| KC2
    HubKC -->|Hub-to-Spoke OIDC Delegation| KC3

    classDef corporate fill:#e0f2fe,stroke:#0284c7,stroke-width:2px,color:#0f172a;
    classDef hub fill:#fef3c7,stroke:#d97706,stroke-width:2px,color:#0f172a;
    classDef spoke fill:#f0fdf4,stroke:#16a34a,stroke-width:2px,color:#0f172a;

    class Entra,AD,EntraConnect corporate;
    class HubKC,HubDB hub;
    class KC1,KC2,KC3,Apps1,Apps2,Apps3 spoke;
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
