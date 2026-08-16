# Node.js Express API Gateway (OAuth 2.1 & Private Key JWT)

This service demonstrates how an Edge API Gateway running on OpenShift:
1. Validates incoming Bearer JWT tokens from frontend SPAs or external systems against the Keycloak JWKS public endpoint.
2. Extracts user identity and group memberships originating from Azure Entra ID / Active Directory.
3. Authenticates against Keycloak using **Private Key JWT (RFC 7523)** for high-security service-to-service communication instead of shared secrets.

---

## 1. Running Locally

```bash
cd apps/microservices/nodejs-api-gateway
npm install
KEYCLOAK_URL=https://sso.enterprise.example.com REALM=enterprise npm start
```
Gateway starts on `http://localhost:8080`.
