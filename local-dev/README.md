# Local Development & Offline Testing Sandbox

This directory allows engineers to run and test the complete Enterprise Keycloak architecture locally via Docker Compose without connecting to an OpenShift cluster.

---

## 1. Stack Components

1. **Keycloak 24/26 (Quarkus Engine)**: Running on `http://localhost:8080` with pre-imported `enterprise` realm.
2. **OpenLDAP**: Running on `ldap://localhost:389` pre-seeded with test users (`john.doe`, `jane.admin`) and groups (`/Admins`, `/Developers`).
3. **PostgreSQL 16**: Local relational store on port `5432`.
4. **Node.js API Gateway**: Running on `http://localhost:8085` validating Bearer JWTs.
5. **Angular 18+ SPA**: Running on `http://localhost:4200` testing PKCE authorization flow.

---

## 2. Quick Start

```bash
# 1-Click Startup Script
./scripts/local-sandbox-up.sh
```
Or manually:
```bash
docker compose -f local-dev/docker-compose.yml up -d
```

---

## 3. Test Credentials

| Username | Password | Email | Group | Role |
| :--- | :--- | :--- | :--- | :--- |
| `jane.admin` | `Password123!` | `jane.admin@enterprise.com` | `/Admins` | `realm-admin`, `argocd-admin` |
| `john.doe` | `Password123!` | `john.doe@enterprise.com` | `/Developers` | `platform-developer` |
| `admin` (Keycloak Master) | `admin` | `admin@local` | Master Admin | Master Realm Admin |
