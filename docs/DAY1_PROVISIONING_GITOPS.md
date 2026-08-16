# Day 1: GitOps Provisioning & Operator Lifecycle

This runbook covers Day 1 deployment of the Red Hat Build of Keycloak Operator, Quarkus-based Keycloak custom resources, and declarative realm imports across development, staging, and production clusters.

---

## 1. GitOps Multi-Cluster Architecture

```mermaid
graph TD
    Repo["<b>GitOps Repository</b><br/>keycloak-openshift-2026"] --> AppSet["<b>ArgoCD ApplicationSet</b><br/>openshift-gitops"]

    AppSet -->|Overlay: dev| DevCluster["<b>Cluster Alpha (Dev)</b><br/>1 Replica · Dev Route"]
    AppSet -->|Overlay: stage| StageCluster["<b>Cluster Bravo (Stage)</b><br/>2 Replicas · Stage Route"]
    AppSet -->|Overlay: prod| ProdCluster["<b>Cluster Charlie (Prod)</b><br/>3+ Replicas · Multi-AZ HPA<br/>sso.enterprise.example.com"]
    AppSet -.->|Overlay: hub| HubCluster["<b>Cluster Hub (Central)</b><br/>Parent Master IdP"]

    style Repo fill:#dbeafe,stroke:#1d4ed8,stroke-width:2px,color:#0f172a;
    style AppSet fill:#fef3c7,stroke:#b45309,stroke-width:2px,color:#0f172a;
    style DevCluster fill:#f1f5f9,stroke:#64748b,stroke-width:2px,color:#0f172a;
    style StageCluster fill:#f1f5f9,stroke:#64748b,stroke-width:2px,color:#0f172a;
    style ProdCluster fill:#dcfce7,stroke:#15803d,stroke-width:2px,color:#0f172a;
    style HubCluster fill:#ede9fe,stroke:#6d28d9,stroke-width:2px,color:#0f172a;
```

---

## 2. Operator Lifecycle & CR Management

The deployment utilizes the Red Hat Build of Keycloak Operator (`rhbk-operator`), which manages the full lifecycle of Keycloak instances via the Kubernetes Operator pattern:
- **Automatic Schema Migration**: The operator orchestrates Liquibase database schema migrations before starting new pods.
- **Infinispan Clustering**: Configures pod discovery and cluster forming via JGroups DNS_PING.
- **Declarative Realm Import**: Custom Resource `KeycloakRealmImport` reconciles realm configuration idempotently without manual UI intervention.

---

## 3. Deployment Commands

```bash
# Automated Day 1 Deployment for Dev
./scripts/day1-deploy-operator-and-keycloak.sh cluster-alpha-dev

# Automated Day 1 Deployment for Prod
./scripts/day1-deploy-operator-and-keycloak.sh cluster-charlie-prod
```
