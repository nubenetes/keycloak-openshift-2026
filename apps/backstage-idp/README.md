# Backstage IDP Authentication & User Sync via Keycloak

This module configures the Spotify Backstage Internal Developer Platform (IDP) running in OpenShift to authenticate developers via Red Hat Build of Keycloak using OpenID Connect (OIDC) with Authorization Code Flow and PKCE.

---

## 1. Authentication Architecture

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer
    participant BS_UI as Backstage Frontend (React)
    participant BS_BE as Backstage Backend Node.js
    participant KC as Keycloak (RHBK)

    Dev->>BS_UI: Open Backstage Catalog
    BS_UI->>KC: Redirect to /auth (clientId=backstage-idp)
    KC-->>BS_UI: Prompt Login / Entra ID SSO
    KC-->>BS_UI: Return Authorization Code
    BS_UI->>BS_BE: Pass code to /api/auth/oidc/handler
    BS_BE->>KC: Exchange Code for Tokens (/token)
    KC-->>BS_BE: Return ID Token & Access Token
    BS_BE->>BS_BE: Resolve User Identity & Issue Session Token
    BS_BE-->>BS_UI: Set HttpOnly Session Cookie
    BS_UI-->>Dev: Render Catalog Dashboard
```

---

## 2. Environment Variables Required

| Variable | Description | Example |
| :--- | :--- | :--- |
| `BACKSTAGE_CLIENT_SECRET` | Client Secret from Keycloak client `backstage-idp` | `s3cr3t-t0k3n` |
| `POSTGRES_HOST` | Backstage PostgreSQL host | `backstage-db.internal` |
| `AUTH_SESSION_SECRET` | Encryption secret for Backstage cookie sessions | `super-secure-key` |
