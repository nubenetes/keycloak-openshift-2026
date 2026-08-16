# Quarkus Microservice Resource Server & Token Exchange

This service demonstrates:
1. **OAuth 2.0 Resource Server**: Validating incoming JWTs from Keycloak against JWKS public keys.
2. **RBAC & Group Authorization**: Enforcing `@RolesAllowed` based on Keycloak / Entra ID group membership.
3. **RFC 8693 Token Exchange**: Securely exchanging an inbound client/user token for a downstream microservice token with scoped audience.

---

## 1. RFC 8693 Token Exchange Architecture

```mermaid
sequenceDiagram
    autonumber
    actor User as Authenticated User
    participant Frontend as Angular SPA / BFF
    participant Gateway as Quarkus API Service
    participant KC as Keycloak (RHBK)
    participant Downstream as Downstream Payment Service

    User->>Frontend: Initiate Checkout Action
    Frontend->>Gateway: POST /api/v1/workloads (Bearer UserToken)
    Gateway->>Gateway: Validate UserToken via JWKS & check @RolesAllowed
    Gateway->>KC: POST /token (grant_type=token-exchange, subject_token=UserToken, audience=payment-service)
    KC->>KC: Verify Token Exchange permissions & generate new scoped JWT
    KC-->>Gateway: Return DownstreamToken (audience=payment-service, original caller preserved)
    Gateway->>Downstream: POST /process-payment (Bearer DownstreamToken)
    Downstream-->>Gateway: 200 OK Payment Processed
    Gateway-->>Frontend: 200 OK Checkout Success
```

---

## 2. Build & Run

```bash
cd apps/microservices/quarkus-api-service
mvn quarkus:dev
```
Service starts on `http://localhost:8081`.
