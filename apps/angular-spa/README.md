# Enterprise Angular 18+ Single Page Application (OAuth 2.1 & BFF)

This module demonstrates the recommended OAuth 2.1 architecture for frontend Single Page Applications (SPAs) on OpenShift.

---

## 1. Security Architecture: PKCE vs BFF Pattern

```mermaid
graph LR
    subgraph Browser["User Browser"]
        SPA["Angular 18+ App"]
    end

    subgraph OpenShift["OpenShift 4.20+ Cluster"]
        BFF["OAuth2-Proxy / BFF Gateway<br/>(HttpOnly SameSite=Strict Cookie)"]
        KC["Keycloak (RHBK)<br/>OAuth 2.1 Provider"]
        API["Quarkus / Node.js Microservices<br/>(Bearer JWT Verification)"]
    end

    SPA <-->|"Encrypted Session Cookie"| BFF
    BFF <-->|"Auth Code + PKCE / Token Refresh"| KC
    BFF -->|"Injected Bearer Authorization Header"| API

    style Browser fill:#f8fafc,stroke:#64748b,stroke-width:2px;
    style OpenShift fill:#f0fdf4,stroke:#16a34a,stroke-width:2px;
    style BFF fill:#dbeafe,stroke:#2563eb,stroke-width:2px;
    style KC fill:#fef3c7,stroke:#d97706,stroke-width:2px;
    style API fill:#f3e8ff,stroke:#9333ea,stroke-width:2px;
```

### Why OAuth 2.1 Bans Implicit Grant & ROPC
1. **No Tokens in URLs**: Implicit grant exposes access tokens in browser history and referrer headers.
2. **No Credential Harvesting**: Resource Owner Password Credentials (ROPC) teaches users to share their corporate passwords with client applications directly, bypassing MFA and conditional access.
3. **PKCE Mandatory**: Proof Key for Code Exchange (RFC 7636) prevents authorization code interception attacks.
4. **BFF Pattern Recommended**: Storing access tokens in browser memory/storage leaves them vulnerable to XSS. The Backend-For-Frontend (BFF) pattern maintains tokens in secure server-side sessions with encrypted `HttpOnly` cookies.

---

## 2. Running Locally

```bash
cd apps/angular-spa
npm install
npm start
```
Open `http://localhost:4200` to initiate the login flow against Keycloak.
