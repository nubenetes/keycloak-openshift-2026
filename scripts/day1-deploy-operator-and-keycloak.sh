#!/usr/bin/env bash
# ==============================================================================
# DAY 1: Operator Deployment & Keycloak Instance Provisioning
# OpenShift 4.20+ / Red Hat Build of Keycloak Operator (RHBK)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

CLUSTER_OVERLAY="${1:-cluster-alpha-dev}"

print_banner "DAY 1: OPERATOR INSTALLATION & KEYCLOAK DEPLOYMENT ($CLUSTER_OVERLAY)"
check_prerequisites

log_step "1. Deploying Red Hat Build of Keycloak Operator via OLM"
oc apply -f "$REPO_ROOT/gitops/base/operator/subscription.yaml" -n "$NAMESPACE"
log_success "Operator Subscription created in '$NAMESPACE'."

log_info "Waiting for RHBK Operator CSV to achieve 'Succeeded' status (up to 180s)..."
CSV_FOUND=false
for i in {1..36}; do
    CSV_NAME=$(oc get sub rhbk-operator -n "$NAMESPACE" -o jsonpath='{.status.installedCSV}' 2>/dev/null || echo "")
    if [ -n "$CSV_NAME" ]; then
        CSV_PHASE=$(oc get csv "$CSV_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [ "$CSV_PHASE" == "Succeeded" ]; then
            log_success "Operator CSV '$CSV_NAME' is in Succeeded state."
            CSV_FOUND=true
            break
        fi
        log_info "CSV '$CSV_NAME' phase: $CSV_PHASE (attempt $i/36)..."
    else
        log_info "Waiting for OLM to resolve subscription... (attempt $i/36)"
    fi
    sleep 5
done

if [ "$CSV_FOUND" = false ]; then
    log_warn "Operator CSV did not reach Succeeded in time. Proceeding with CR deployment in case it is already installed."
fi

log_step "2. Deploying Keycloak Cluster via Kustomize ($CLUSTER_OVERLAY)"
TARGET_OVERLAY_PATH="$REPO_ROOT/gitops/clusters/$CLUSTER_OVERLAY"
if [ ! -d "$TARGET_OVERLAY_PATH" ]; then
    log_error "Target overlay '$TARGET_OVERLAY_PATH' does not exist."
    exit 1
fi

oc apply -k "$TARGET_OVERLAY_PATH" -n "$NAMESPACE"
log_success "Applied Kustomize overlay for '$CLUSTER_OVERLAY'."

log_step "3. Waiting for Keycloak StatefulSet & Pods to Initialize"
log_info "Watching Keycloak status in namespace '$NAMESPACE'..."
sleep 5

# Wait for keycloak custom resource readiness
log_info "Waiting for Keycloak Custom Resource '$KEYCLOAK_CR_NAME' to report Ready status..."
for i in {1..30}; do
    READY_STATUS=$(oc get keycloak "$KEYCLOAK_CR_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    if [ "$READY_STATUS" == "True" ]; then
        log_success "Keycloak instance '$KEYCLOAK_CR_NAME' is Ready."
        break
    fi
    log_info "Keycloak Ready condition: $READY_STATUS (attempt $i/30)..."
    sleep 10
done

log_step "4. Applying Declarative Realm Import ($REALM_NAME)"
oc apply -f "$REPO_ROOT/gitops/base/realms/enterprise-realm-import.yaml" -n "$NAMESPACE"
log_success "Submitted KeycloakRealmImport for realm '$REALM_NAME'."

log_step "5. Verifying Deployment & Endpoints"
KC_URL=$(get_keycloak_url)

cat <<EOF
------------------------------------------------------------------------------
Keycloak Day 1 Deployment Summary:
  * Namespace:               $NAMESPACE
  * Cluster Overlay:         $CLUSTER_OVERLAY
  * Base Endpoint:           $KC_URL
  * Realm OIDC Discovery:    $KC_URL/realms/$REALM_NAME/.well-known/openid-configuration
  * Metrics Endpoint:        $KC_URL/metrics (Prometheus / OCP User Workload)
  * Health Endpoint:         $KC_URL/health
------------------------------------------------------------------------------
Next Step: Configure Entra ID Federation via ./scripts/day1-configure-entra-federation.sh
EOF
