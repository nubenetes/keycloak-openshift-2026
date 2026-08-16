# ArgoCD OpenID Connect & RBAC Integration with Keycloak

This guide details how OpenShift GitOps / ArgoCD authenticates users against Red Hat Build of Keycloak using OpenID Connect (OIDC) and enforces Role-Based Access Control (RBAC) via Keycloak group memberships (which originate from Microsoft Entra ID or Active Directory).

---

## 1. Authentication & Authorization Flow

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Platform Engineer
    participant Argo as ArgoCD UI / CLI
    participant KC as Keycloak (RHBK)
    participant Entra as Microsoft Entra ID

    Dev->>Argo: Click "Log in via Keycloak SSO"
    Argo->>KC: Redirect to /auth (PKCE + state)
    KC->>Entra: Federate to Azure Entra ID login
    Entra-->>KC: Return Entra Token (UPN & Groups)
    KC->>KC: Map Entra groups to Keycloak roles
    KC-->>Argo: Return Authorization Code
    Argo->>KC: Exchange Code for Tokens (/token)
    KC-->>Argo: Returns ID Token (groups: ["/Admins"])
    Argo->>Argo: Match claim in argocd-rbac-cm<br/>(assigns role:admin)
    Argo-->>Dev: Access Granted with Admin Privileges
```

---

## 2. Configuration Steps

1. Apply the OIDC configuration patch to `argocd-cm`:
   ```bash
   oc patch configmap argocd-cm -n openshift-gitops --type merge -p "$(cat argocd-cm-patch.yaml)"
   ```
2. Apply the RBAC group mapping to `argocd-rbac-cm`:
   ```bash
   oc patch configmap argocd-rbac-cm -n openshift-gitops --type merge -p "$(cat argocd-rbac-cm.yaml)"
   ```
3. Restart ArgoCD server pod to refresh configuration:
   ```bash
   oc rollout restart deployment openshift-gitops-server -n openshift-gitops
   ```

---

## 3. RBAC Mapping Matrix

| Keycloak Group (from Entra/AD) | ArgoCD Role | Allowed Actions | Target Clusters |
| :--- | :--- | :--- | :--- |
| `/Admins` | `role:admin` | Full Admin (Create, Delete, Sync, Exec) | All Clusters |
| `/Platform-Engineers` | `role:admin` | Full Admin | All Clusters |
| `/Developers` | `role:developer` | Sync, Get, Logs, Exec (Dev/Stage only) | Dev & Stage |
| `/SecOps` | `role:readonly` | Read-only inspection | All Clusters |
