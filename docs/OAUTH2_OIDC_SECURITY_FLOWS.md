# OAuth 2.1 & OpenID Connect Security Patterns (2026 Recommended)

This document details the OAuth 2.1 and OpenID Connect (OIDC) security flows implemented in this repository, contrasting deprecated legacy flows against hardened modern standards.

---

## 1. OAuth 2.1 Paradigm Shift

| Feature / Flow | Legacy OAuth 2.0 (Deprecated / Prohibited) | Modern OAuth 2.1 (Enforced in this Repo) | Enterprise Rationale |
| :--- | :--- | :--- | :--- |
| **Implicit Grant** | ❌ Allowed (`response_type=token`) | 🚫 **STRICTLY PROHIBITED** | Access tokens are exposed in URI fragments, browser history, and HTTP Referrer headers. |
| **Resource Owner Password Credentials (ROPC)** | ❌ Allowed (`grant_type=password`) | 🚫 **STRICTLY PROHIBITED** | Directly handling credentials bypasses Multi-Factor Authentication (MFA), Conditional Access, and FIDO2/WebAuthn. |
| **Authorization Code Grant** | Optional PKCE | ✅ **PKCE MANDATORY (RFC 7636)** | Enforces cryptographic binding between authorization code and token request using `code_challenge_method=S256`. |
| **Single Page Apps (SPAs)** | LocalStorage / SessionStorage | ✅ **Backend-For-Frontend (BFF)** | Tokens remain on the server; the browser interacts via encrypted `HttpOnly`, `SameSite=Strict`, `Secure` cookies. |
| **Service-to-Service Auth** | Shared Client Secret | ✅ **Private Key JWT (RFC 7523) / mTLS** | Asymmetric cryptography ensures credentials cannot be extracted from configuration or stolen in transit. |
| **Multi-Tier Delegation** | Forwarding Raw User JWT | ✅ **Token Exchange (RFC 8693)** | Downstream services receive scoped tokens with explicit audience restriction while preserving audit trails. |

---

## 2. Flow 1: Authorization Code Flow with PKCE (Public Clients)

```mermaid
sequenceDiagram
    autonumber
    actor User as Corporate User
    participant Browser as Web Browser (SPA)
    participant KC as Keycloak (RHBK)
    participant API as Resource Server (API)

    Note over Browser: 1. Generate code_verifier<br/>2. Compute code_challenge =<br/>Base64URL(SHA256(verifier))
    Browser->>KC: GET /auth?client_id=angular-spa&response_type=code<br/>&code_challenge=xyz...&code_challenge_method=S256
    KC-->>User: Present Login & MFA / Entra ID Federation
    User->>KC: Authenticate
    KC-->>Browser: 302 Redirect /callback?code=AUTH_CODE_123&state=abc
    Browser->>KC: POST /token (code=AUTH_CODE_123, verifier=RAW_VERIFIER)
    Note over KC: Verify SHA256(RAW_VERIFIER)<br/>== code_challenge
    KC-->>Browser: 200 OK (access_token, id_token, refresh_token)
    Browser->>API: GET /api/v1/resource (Bearer access_token)
    API-->>Browser: 200 OK (Protected Data)
```

---

## 3. Flow 2: Service-to-Service Private Key JWT (RFC 7523)

```mermaid
sequenceDiagram
    autonumber
    participant Client as Microservice / Gateway
    participant KC as Keycloak (RHBK)
    participant DB as Backend Database

    Note over Client: Sign short-lived client_assertion JWT with private RSA key<br/>(iss=client_id, sub=client_id, aud=Keycloak, exp=+5m)
    Client->>KC: POST /token (grant_type=client_credentials,<br/>client_assertion_type=jwt-bearer, client_assertion=JWT)
    Note over KC: Validate JWT signature<br/>via registered JWKS
    KC-->>Client: 200 OK (access_token with service account roles)
    Client->>DB: Query data with service account credentials
```

---

## 4. Flow 3: RFC 8693 Token Exchange (Delegation & Impersonation)

```mermaid
sequenceDiagram
    autonumber
    actor User as End User
    participant Edge as Edge Gateway / BFF
    participant SvcA as Order Service (Quarkus)
    participant KC as Keycloak (RHBK)
    participant SvcB as Payment Service

    User->>Edge: Submit Order
    Edge->>SvcA: POST /orders (Bearer UserAccessToken)
    Note over SvcA: SvcA needs to invoke SvcB on behalf of User<br/>with scoped audience
    SvcA->>KC: POST /token (grant_type=token-exchange,<br/>subject_token=UserToken, audience=payment-service)
    Note over KC: Verify exchange policy:<br/>SvcA permitted for payment-service
    KC-->>SvcA: Return DownstreamToken (aud: payment-service)
    SvcA->>SvcB: POST /payments (Bearer DownstreamToken)
    SvcB->>SvcB: Validate token: audience matches payment-service
    SvcB-->>SvcA: 200 OK Payment Success
```
