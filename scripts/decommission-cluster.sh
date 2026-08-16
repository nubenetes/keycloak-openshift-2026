#!/usr/bin/env bash
# ==============================================================================
# DECOMMISSIONING RUNBOOK: Clean Cluster Teardown & Realm Archival
# Red Hat Build of Keycloak (RHBK) on OpenShift 4.20+
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

FORCE="${1:-}"

print_banner "DECOMMISSIONING & TEARDOWN RUNBOOK"

if [ "$FORCE" != "--force" ]; then
    printf "${BOLD}${RED}WARNING: You are about to permanently decommission Keycloak in namespace '%s'.${NC}\n" "$NAMESPACE"
    printf "This will delete all Keycloak pods, PostgreSQL data, and realm secrets.\n\n"
    read -rp "Type 'DESTROY-KEYCLOAK' to proceed: " confirm
    if [ "$confirm" != "DESTROY-KEYCLOAK" ]; then
        log_info "Decommissioning aborted by user."
        exit 0
    fi
fi

log_step "1. Executing Final Safety Realm Export & Database Backup"
"$SCRIPT_DIR/day2-operations-suite.sh" export-realm || log_warn "Realm export failed or skipped."
"$SCRIPT_DIR/day2-operations-suite.sh" backup-db || log_warn "Database backup failed or skipped."

log_step "2. Disabling OpenShift Route (Stopping Ingress Traffic)"
if oc get route keycloak -n "$NAMESPACE" &>/dev/null; then
    oc delete route keycloak -n "$NAMESPACE" --wait=false
    log_success "OpenShift route removed."
fi

log_step "3. Deleting KeycloakRealmImport Custom Resources"
oc delete keycloakrealmimport --all -n "$NAMESPACE" --ignore-not-found=true
log_success "Deleted KeycloakRealmImport CRs."

log_step "4. Deleting Keycloak Instance Custom Resource"
oc delete keycloak "$KEYCLOAK_CR_NAME" -n "$NAMESPACE" --ignore-not-found=true
log_success "Deleted Keycloak CR '$KEYCLOAK_CR_NAME'."

log_step "5. Deleting PostgreSQL Cluster / Database StatefulSets"
oc delete postgrescluster keycloak-db -n "$NAMESPACE" --ignore-not-found=true
oc delete statefulset -l app=keycloak -n "$NAMESPACE" --ignore-not-found=true
log_success "Database resources deleted."

log_step "6. Deleting Operator Subscription & OperatorGroup"
oc delete sub rhbk-operator -n "$NAMESPACE" --ignore-not-found=true
oc delete operatorgroup keycloak-operator-group -n "$NAMESPACE" --ignore-not-found=true
log_success "Operator subscription removed."

log_step "7. Deleting Monitoring & Network Policies"
oc delete servicemonitor -l app.kubernetes.io/name=keycloak -n "$NAMESPACE" --ignore-not-found=true
oc delete prometheusrule -l app.kubernetes.io/name=keycloak -n "$NAMESPACE" --ignore-not-found=true
oc delete networkpolicy --all -n "$NAMESPACE" --ignore-not-found=true
log_success "Monitoring & Network policies deleted."

log_step "8. Deleting Namespace '$NAMESPACE' (Optional Cleanup)"
read -rp "Delete entire namespace '$NAMESPACE'? [y/N]: " del_ns
if [[ "$del_ns" =~ ^[Yy]$ ]]; then
    oc delete namespace "$NAMESPACE"
    log_success "Namespace '$NAMESPACE' deletion initiated."
else
    log_info "Namespace '$NAMESPACE' preserved."
fi

log_success "Decommissioning process completed cleanly."
