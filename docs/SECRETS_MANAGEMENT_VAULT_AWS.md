# Enterprise Secrets Management: AWS Secrets Manager vs. HashiCorp Vault Multi-Cluster Architecture

This architectural analysis evaluates secrets management strategies across 3 OpenShift Container Platform (OCP) clusters on AWS, specifically answering whether to synchronize HashiCorp Vault across clusters in a **Hub-Spoke topology** or maintain **independent in-cluster Vault instances / External Secrets Operator (ESO)**.

---

## 1. Secrets Management Architectural Decision Matrix

| Strategy | Architecture Model | Key Strengths | Operational Overhead | License Model | Recommended Use Case |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Strategy A: Cloud-Native ESO + AWS Secrets Manager** *(Recommended)* | AWS Secrets Manager acts as central root authority; ESO in each OCP cluster synchronizes secrets via AWS IRSA | • Zero cluster-hosted database state<br/>• Native AWS IAM & KMS encryption<br/>• Automated key rotation<br/>• Seamless OCP GitOps integration | **Very Low** (Managed AWS service + lightweight operator) | Standard AWS Pay-As-You-Go | **Best for AWS OpenShift Clusters (ROSA / IPI on AWS)** |
| **Strategy B: Central Hub Vault + Performance Replication (PR)** | Primary Vault cluster in AWS/Central region; Spoke Vaults in each OCP cluster replicating via WAN | • Centralized audit logs & access policies<br/>• Cross-cloud consistency<br/>• Dynamic secrets generation | **High** (Requires managing Raft consensus, unsealing, monitoring, WAN links) | Requires **HashiCorp Vault Enterprise** license for WAN PR | Large heterogeneous multi-cloud enterprises |
| **Strategy C: Per-Cluster Dedicated Vault + ESO Federation** | Lightweight in-cluster Vault (or Open-Source Vault) per OCP cluster; ESO synchronizes shared secrets from AWS Secrets Manager | • Local cluster autonomy<br/>• No cross-cluster network dependency<br/>• Supports local dynamic DB leasing & Transit encryption | **Medium** (Per-cluster Vault maintenance) | Open Source / Free | Teams needing local Vault Transit Encryption / Dynamic DB credentials without Enterprise license |

---

## 2. Recommended Architecture: Hybrid Cloud-Native (Strategy A + C)

```mermaid
graph TD
    subgraph AWS_Cloud["AWS Cloud Infrastructure (eu-west-1)"]
        AWS_SM["<b>AWS Secrets Manager</b><br/>Enterprise Cloud Authority<br/>(KMS Encrypted · Automated Rotation)"]
        KMS["<b>AWS KMS Key</b><br/>Hardware Security Module"]
        AWS_SM <--> KMS
    end

    subgraph OCP_MultiCluster["OpenShift 4.20+ Multi-Cluster Fleet"]
        subgraph Cluster_Alpha["Cluster 1: Alpha (Dev)"]
            ESO1["<b>External Secrets Operator</b><br/>AWS IRSA ServiceAccount"]
            K8s_Sec1["<b>Kubernetes Secrets</b><br/>(keycloak-db-secret, oidc-keys)"]
            KC1["<b>Keycloak Dev</b>"]
            ESO1 -->|Reconcile| K8s_Sec1 --> KC1
        end

        subgraph Cluster_Bravo["Cluster 2: Bravo (Stage)"]
            ESO2["<b>External Secrets Operator</b><br/>AWS IRSA ServiceAccount"]
            K8s_Sec2["<b>Kubernetes Secrets</b><br/>(keycloak-db-secret, oidc-keys)"]
            KC2["<b>Keycloak Stage</b>"]
            ESO2 -->|Reconcile| K8s_Sec2 --> KC2
        end

        subgraph Cluster_Charlie["Cluster 3: Charlie (Prod HA)"]
            ESO3["<b>External Secrets Operator</b><br/>AWS IRSA ServiceAccount"]
            LocalVault["<b>(Optional) Local Vault</b><br/>Transit Encryption Engine"]
            K8s_Sec3["<b>Kubernetes Secrets</b><br/>(keycloak-db-secret, oidc-keys)"]
            KC3["<b>Keycloak Prod HA</b>"]
            ESO3 -->|Reconcile| K8s_Sec3 --> KC3
            LocalVault -.->|Transit Encryption| KC3
        end
    end

    AWS_SM ===>|Secure IAM STS / IRSA| ESO1
    AWS_SM ===>|Secure IAM STS / IRSA| ESO2
    AWS_SM ===>|Secure IAM STS / IRSA| ESO3

    style AWS_Cloud fill:#fef3c7,stroke:#d97706,stroke-width:2px,color:#0f172a;
    style OCP_MultiCluster fill:#f0fdf4,stroke:#16a34a,stroke-width:2px,color:#0f172a;
    style AWS_SM fill:#fed7aa,stroke:#ea580c,stroke-width:2px,color:#0f172a;
    style ESO1 fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#0f172a;
    style ESO2 fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#0f172a;
    style ESO3 fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#0f172a;
```

---

## 3. Detailed Analysis: Should Vault Clusters be Synchronized as a Hub-Spoke?

### Why Hub-Spoke Vault Replication is Often an Anti-Pattern on AWS OpenShift
1. **License Constraint**: Native cross-cluster WAN synchronization in HashiCorp Vault (**Performance Replication**) is a proprietary feature restricted exclusively to **Vault Enterprise**. The open-source community edition does not support cross-cluster multi-primary replication.
2. **Network Resilience & Latency**: If a spoke OpenShift cluster relies on a remote parent Vault over WAN for token verification or secret leasing, network partitions or high latency directly degrade Keycloak and application startup times.
3. **Blast Radius & Operational Complexity**: Managing Raft consensus quorum across multiple Kubernetes clusters introduces operational overhead (split-brain recovery, leader elections, unseal key distribution).

### The Recommended Modern Approach (2026)
1. **Source of Truth**: Keep static and root credentials (Entra ID Client Secret, Active Directory Bind Credentials, Database Master Passwords) in **AWS Secrets Manager** with KMS encryption.
2. **Cluster Ingestion**: Deploy **External Secrets Operator (ESO)** on each OpenShift cluster. ESO authenticates via **AWS IAM Roles for Service Accounts (IRSA)**, eliminating long-lived AWS access keys.
3. **Optional Local Vault Instances**: If workloads require advanced Vault capabilities (such as dynamic PostgreSQL credential generation or encryption-as-a-service via the Transit engine), deploy a standalone, autonomous Vault instance per cluster without WAN replication dependencies.
