# Decommissioning & Cluster Teardown Runbook

This runbook outlines the steps for safely decommissioning a Keycloak deployment on OpenShift without leaving orphaned DNS records, cloud storage artifacts, or sensitive credentials.

---

## 1. Decommissioning Procedure Workflow

```mermaid
graph TD
    A[Start Decommissioning] --> B[Export Realm & Backup DB to S3]
    B --> C[Remove OpenShift Route / Ingress]
    C --> D[Delete Keycloak & Realm Import CRs]
    D --> E[Delete Database StatefulSets & PVCs]
    E --> F[Remove Operator Subscriptions]
    F --> G[Shred Local Secret Caches]
    G --> H[Terminate Namespace]

    style A fill:#e0f2fe,stroke:#0284c7,stroke-width:2px;
    style B fill:#dbeafe,stroke:#1e40af,stroke-width:2px;
    style C fill:#fef3c7,stroke:#b45309,stroke-width:2px;
    style D fill:#fee2e2,stroke:#b91c1c,stroke-width:2px;
    style E fill:#fee2e2,stroke:#b91c1c,stroke-width:2px;
    style F fill:#fee2e2,stroke:#b91c1c,stroke-width:2px;
    style G fill:#fee2e2,stroke:#b91c1c,stroke-width:2px;
    style H fill:#f87171,stroke:#991b1b,stroke-width:3px;
```

---

## 2. Automated Decommissioning Script

Execute the interactive teardown script:
```bash
./scripts/decommission-cluster.sh
```
To run non-interactively in automated CI/CD pipelines:
```bash
./scripts/decommission-cluster.sh --force
```
