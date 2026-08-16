#!/usr/bin/env bash
# ==============================================================================
# Local Sandbox Startup & Validation Script
# Spins up Keycloak, OpenLDAP, Postgres & Sample Apps in Docker Compose
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

print_banner "LOCAL OFFLINE DEVELOPMENT SANDBOX"

log_step "1. Validating Docker / Podman Engine"
if ! command -v docker &>/dev/null && ! command -v podman &>/dev/null; then
    log_error "Neither Docker nor Podman CLI was detected. Please install container runtime."
    exit 1
fi

DOCKER_CMD="docker compose"
if command -v docker-compose &>/dev/null; then
    DOCKER_CMD="docker-compose"
fi

log_step "2. Starting Local Services via Docker Compose"
$DOCKER_CMD -f "$REPO_ROOT/local-dev/docker-compose.yml" up -d

log_step "3. Waiting for Keycloak Health Probe"
log_info "Probing http://localhost:8080/health/ready..."
for i in {1..30}; do
    if curl -sk "http://localhost:8080/health/ready" | grep -q '"status": "UP"'; then
        log_success "Local Keycloak instance is UP and healthy!"
        break
    fi
    log_info "Waiting for Keycloak to boot... ($i/30)"
    sleep 3
done

log_step "4. Local Sandbox Environment Ready"
cat <<EOF
------------------------------------------------------------------------------
Local Development Stack Active:
  * Keycloak Admin UI:   http://localhost:8080 (admin / admin)
  * Enterprise Realm:    http://localhost:8080/realms/enterprise
  * Angular 18+ SPA:     http://localhost:4200 (Test PKCE Auth)
  * Node.js API Gateway: http://localhost:8085/health
  * OpenLDAP Server:     ldap://localhost:389
------------------------------------------------------------------------------
To run automated test suite against local stack:
  KEYCLOAK_URL=http://localhost:8080 ./scripts/validate-oauth2-flows.sh
------------------------------------------------------------------------------
To stop local stack:
  $DOCKER_CMD -f local-dev/docker-compose.yml down
EOF
