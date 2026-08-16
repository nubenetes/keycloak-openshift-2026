# Day 1: GitOps Provisioning & Operator Lifecycle

This runbook covers Day 1 deployment of the Red Hat Build of Keycloak Operator, Quarkus-based Keycloak custom resources, and declarative realm imports across development, staging, and production clusters.

---

## 1. GitOps Multi-Cluster Architecture

```mermaid
graph TD
    Repo["GitOps Repository<br/>(github.com/nubenetes/keycloak-openshift-2026)"] --> AppSet["ArgoCD ApplicationSet<br/>(openshift-gitops)"]

    AppSet -->|Kustomize Overlay: dev| DevCluster["Cluster Alpha (Dev)<br/>• 1 Replica<br/>• Dev Hostname"]
    AppSet -->|Kustomize Overlay: stage| StageCluster["Cluster Bravo (Stage)<br/>• 2 Replicas<br/>• Staging Hostname"]
    AppSet -->|Kustomize Overlay: prod| ProdCluster["Cluster Charlie (Prod HA)<br/>• 3+ Replicas<br/>• Multi-AZ HPA<br/>• sso.enterprise.example.com"]
    AppSet -.->|Optional Hub Overlay| HubCluster["Cluster Hub (Central)<br/>• Parent Master IdP"]

    style Repo fill:#dbeafe,stroke:#1d4ed8,stroke-width:2px;
    style AppSet fill:#fef3c7,stroke:#b45309,stroke-width:2px;
    style DevCluster fill:#f1f5f9,stroke:#64748b,stroke-width:2px;
    style StageCluster fill:#f1f5f9,stroke:#64748b,stroke-width:2px;
    style ProdCluster fill:#dcfce7,stroke:#15803d,stroke-width:2px;
    style HubCluster fill:#ede9fe,stroke:#6d28d9,stroke-width:2px;
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
