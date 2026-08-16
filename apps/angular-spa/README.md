# Enterprise Angular 18+ Single Page Application (OAuth 2.1 & BFF)

This module demonstrates the recommended OAuth 2.1 architecture for frontend Single Page Applications (SPAs) on OpenShift.

---

## 1. Security Architecture: PKCE vs BFF Pattern

```mermaid
graph LR
    subgraph Browser["User Browser"]
        SPA["<b>Angular 18+ SPA</b><br/>Frontend Client"]
    end

    subgraph OpenShift["OpenShift 4.20+ Cluster"]
        BFF["<b>OAuth2-Proxy (BFF)</b><br/>HttpOnly Session Cookie<br/>No browser token storage"]
        KC["<b>Keycloak (RHBK)</b><br/>OAuth 2.1 Provider<br/>Token Authority"]
        API["<b>Microservices</b><br/>Quarkus & Node.js<br/>Bearer JWT Auth"]
    end

    SPA <-->|"Encrypted Cookie"| BFF
    BFF <-->|"Auth Code + PKCE"| KC
    BFF -->|"Bearer JWT"| API

    style Browser fill:#f8fafc,stroke:#64748b,stroke-width:2px,color:#0f172a;
    style OpenShift fill:#f0fdf4,stroke:#16a34a,stroke-width:2px,color:#0f172a;
    style BFF fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#0f172a;
    style KC fill:#fef3c7,stroke:#d97706,stroke-width:2px,color:#0f172a;
    style API fill:#f3e8ff,stroke:#9333ea,stroke-width:2px,color:#0f172a;
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
