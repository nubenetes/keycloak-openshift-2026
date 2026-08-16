#!/usr/bin/env bash
# ==============================================================================
# DAY 0: Infrastructure Prerequisites & Cluster Preparation
# OpenShift 4.20+ / AWS / Red Hat Build of Keycloak
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

print_banner "DAY 0: CLUSTER PREREQUISITES & NETWORKING SETUP"
check_prerequisites

log_step "1. Creating Target Namespace '$NAMESPACE' with Monitoring Labels"
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    oc apply -f "$REPO_ROOT/gitops/base/operator/namespace.yaml"
    log_success "Namespace '$NAMESPACE' created."
else
    log_info "Namespace '$NAMESPACE' already exists. Reconciling labels..."
    oc label namespace "$NAMESPACE" openshift.io/user-monitoring=true openshift.io/cluster-monitoring=true --overwrite
fi

log_step "2. Applying Network Policies & Security Baselines"
oc apply -f "$REPO_ROOT/gitops/base/networking/networkpolicy.yaml" -n "$NAMESPACE"
log_success "NetworkPolicies applied to '$NAMESPACE'."

log_step "3. Provisioning Database Secrets & Configuration"
# Check if secret already exists
if ! oc get secret keycloak-db-secret -n "$NAMESPACE" &>/dev/null; then
    log_info "Provisioning default database secret template..."
    DB_USER="${DB_USER:-keycloak}"
    DB_PASS="${DB_PASS:-$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)}"
    DB_HOST="${DB_HOST:-keycloak-db-primary.keycloak.svc.cluster.local}"
    DB_PORT="${DB_PORT:-5432}"
    DB_NAME="${DB_NAME:-keycloak}"

    oc create secret generic keycloak-db-secret \
        --from-literal=username="$DB_USER" \
        --from-literal=password="$DB_PASS" \
        --from-literal=host="$DB_HOST" \
        --from-literal=port="$DB_PORT" \
        --from-literal=database="$DB_NAME" \
        -n "$NAMESPACE"
    log_success "Created database secret 'keycloak-db-secret' in '$NAMESPACE'."
else
    log_info "Database secret 'keycloak-db-secret' already exists in '$NAMESPACE'."
fi

log_step "4. Provisioning TLS Edge/Re-encrypt Certificate Secret"
if ! oc get secret keycloak-tls-secret -n "$NAMESPACE" &>/dev/null; then
    log_info "Generating self-signed development/staging TLS certificates (Replace with cert-manager / AWS ACM in production)..."
    TMP_DIR=$(mktemp -d)
    openssl req -x509 -newkey rsa:4096 -nodes \
        -keyout "$TMP_DIR/tls.key" \
        -out "$TMP_DIR/tls.crt" \
        -days 365 \
        -subj "/CN=sso.enterprise.example.com/O=Enterprise IAM/OU=Platform Engineering" \
        -addext "subjectAltName=DNS:sso.enterprise.example.com,DNS:keycloak-service.keycloak.svc,DNS:localhost" 2>/dev/null

    oc create secret tls keycloak-tls-secret \
        --cert="$TMP_DIR/tls.crt" \
        --key="$TMP_DIR/tls.key" \
        -n "$NAMESPACE"
    rm -rf "$TMP_DIR"
    log_success "Created TLS secret 'keycloak-tls-secret' in '$NAMESPACE'."
else
    log_info "TLS secret 'keycloak-tls-secret' already exists in '$NAMESPACE'."
fi

log_step "5. Summary of Day 0 Setup"
cat <<EOF
------------------------------------------------------------------------------
Day 0 Cluster Prerequisites Completed:
  * Namespace:               $NAMESPACE (Monitoring enabled)
  * NetworkPolicies:         Enforced (Ingress & Egress lockdown)
  * Database Secret:         Configured (PostgreSQL connection pool)
  * TLS Certificates:        Installed (keycloak-tls-secret)
  * OpenShift 4.20+ Status: Ready for Day 1 Operator Deployment
------------------------------------------------------------------------------
Next Step: Run ./scripts/day1-deploy-operator-and-keycloak.sh or sync ArgoCD
EOF
