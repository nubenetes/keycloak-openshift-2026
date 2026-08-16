# Day 0: Infrastructure Prerequisites & AWS OpenShift Preparation

This runbook describes the Day 0 infrastructure, networking, certificate, and database requirements for deploying Red Hat Build of Keycloak across 3 OpenShift 4.20+ clusters on AWS.

---

## 1. Prerequisites Checklist

| Component | Specification | Deployment Method |
| :--- | :--- | :--- |
| **OpenShift Version** | 4.20+ (Kubernetes 1.31+) | AWS ROSA or IPI on AWS |
| **Database Tier** | PostgreSQL 16 (Multi-AZ HA) | Crunchy Data PGO / AWS RDS Aurora |
| **TLS Certificates** | TLS 1.3 / Valid CA certs | cert-manager / AWS ACM / OpenShift Ingress Router |
| **DNS Resolution** | Route53 Global Hosted Zone | AWS Route53 + Ingress Router records |
| **Monitoring** | User Workload Monitoring | OpenShift Cluster Monitoring Operator |

---

## 2. Day 0 Workflow Diagram

```mermaid
graph TD
    A["<b>1. Deploy Cluster</b><br/>OpenShift 4.20+"] --> B["<b>2. Enable Monitoring</b><br/>User Workload"]
    B --> C["<b>3. Create Namespace</b><br/>keycloak"]
    C --> D["<b>4. Enforce Policies</b><br/>Network Isolation"]
    D --> E["<b>5. Provision DB</b><br/>PostgreSQL & Secrets"]
    E --> F["<b>6. Inject TLS</b><br/>Edge/Re-encrypt Certs"]
    F --> G["<b>7. Ready for Day 1</b><br/>Operator Deployment"]

    style A fill:#e0f2fe,stroke:#0284c7,stroke-width:2px,color:#0f172a;
    style B fill:#e0f2fe,stroke:#0284c7,stroke-width:2px,color:#0f172a;
    style C fill:#fef3c7,stroke:#d97706,stroke-width:2px,color:#0f172a;
    style D fill:#fef3c7,stroke:#d97706,stroke-width:2px,color:#0f172a;
    style E fill:#f0fdf4,stroke:#16a34a,stroke-width:2px,color:#0f172a;
    style F fill:#f0fdf4,stroke:#16a34a,stroke-width:2px,color:#0f172a;
    style G fill:#dcfce7,stroke:#166534,stroke-width:3px,color:#0f172a;
```

---

## 3. Execution Script

Run the automated Day 0 setup script:
```bash
./scripts/day0-prereqs.sh
```
This script handles namespace creation, monitoring labels, database secrets, and TLS certificate setup.
