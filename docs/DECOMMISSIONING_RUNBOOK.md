# Decommissioning & Cluster Teardown Runbook

This runbook outlines the steps for safely decommissioning a Keycloak deployment on OpenShift without leaving orphaned DNS records, cloud storage artifacts, or sensitive credentials.

---

## 1. Decommissioning Procedure Workflow

```mermaid
graph TD
    A["<b>1. Start Teardown</b><br/>Safety Confirmation"] --> B["<b>2. Export & Backup</b><br/>Archive DB & Realm"]
    B --> C["<b>3. Remove Ingress</b><br/>Delete OpenShift Route"]
    C --> D["<b>4. Delete CRs</b><br/>Keycloak & RealmImport"]
    D --> E["<b>5. Purge Database</b><br/>StatefulSets & PVCs"]
    E --> F["<b>6. Delete Operator</b><br/>Subscription & CSV"]
    F --> G["<b>7. Shred Secrets</b><br/>Purge Local Keys"]
    G --> H["<b>8. Clean Namespace</b><br/>Final Termination"]

    style A fill:#e0f2fe,stroke:#0284c7,stroke-width:2px,color:#0f172a;
    style B fill:#dbeafe,stroke:#1e40af,stroke-width:2px,color:#0f172a;
    style C fill:#fef3c7,stroke:#d97706,stroke-width:2px,color:#0f172a;
    style D fill:#fee2e2,stroke:#b91c1c,stroke-width:2px,color:#0f172a;
    style E fill:#fee2e2,stroke:#b91c1c,stroke-width:2px,color:#0f172a;
    style F fill:#fee2e2,stroke:#b91c1c,stroke-width:2px,color:#0f172a;
    style G fill:#fee2e2,stroke:#b91c1c,stroke-width:2px,color:#0f172a;
    style H fill:#f87171,stroke:#991b1b,stroke-width:3px,color:#0f172a;
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
