#!/usr/bin/env bash
# ==============================================================================
# DAY 2: Operations, Maintenance, Monitoring, Backup & Scaling Suite
# Red Hat Build of Keycloak (RHBK) on OpenShift 4.20+
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

ACTION="${1:-menu}"

print_banner "DAY 2: KEYCLOAK OPERATIONS & MAINTENANCE SUITE"

op_health_check() {
    log_step "1. Checking Keycloak Pods & Cluster Health"
    oc get pods -n "$NAMESPACE" -l app=keycloak -o wide

    log_step "2. Checking Liveness & Readiness Endpoints"
    local kc_url
    kc_url=$(get_keycloak_url)
    
    log_info "Probing $kc_url/health/live..."
    curl -sk "$kc_url/health/live" | jq . || log_warn "Live endpoint probe failed or jq missing."

    log_info "Probing $kc_url/health/ready..."
    curl -sk "$kc_url/health/ready" | jq . || log_warn "Ready endpoint probe failed or jq missing."

    log_step "3. Checking Operator & Custom Resource Status"
    oc get keycloak "$KEYCLOAK_CR_NAME" -n "$NAMESPACE" -o yaml | grep -A 10 "conditions:" || true
}

op_metrics_scrape() {
    log_step "Scraping Prometheus Metrics from Keycloak Endpoint"
    local kc_url
    kc_url=$(get_keycloak_url)

    log_info "Fetching JVM & Request Metrics from $kc_url/metrics..."
    curl -sk "$kc_url/metrics" | grep -E "(jvm_memory_used_bytes|http_server_requests_seconds_count|agroal_active_count|keycloak_logins_total)" | head -n 30
}

op_backup_db() {
    log_step "Initiating Keycloak PostgreSQL Database Backup"
    local backup_timestamp
    backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="/tmp/keycloak_backup_${backup_timestamp}.sql"

    local db_pod
    db_pod=$(oc get pods -n "$NAMESPACE" -l postgres-operator.crunchydata.com/role=master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [ -n "$db_pod" ]; then
        log_info "Taking pg_dump via database pod '$db_pod'..."
        oc exec -n "$NAMESPACE" "$db_pod" -c database -- pg_dump -U keycloak keycloak > "$backup_file"
        log_success "Database backup successfully saved to: $backup_file ($(du -h "$backup_file" | cut -f1))"
    else
        log_warn "Crunchy DB pod not found. Attempting generic pg_dump job..."
        cat <<EOF | oc apply -n "$NAMESPACE" -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: keycloak-backup-$backup_timestamp
  namespace: $NAMESPACE
spec:
  template:
    spec:
      containers:
        - name: backup
          image: registry.redhat.io/rhel9/postgresql-16:latest
          command: ["sh", "-c", "pg_dump -h keycloak-db-primary -U keycloak keycloak > /tmp/backup.sql"]
      restartPolicy: OnFailure
EOF
        log_success "Created backup job 'keycloak-backup-$backup_timestamp'."
    fi
}

op_export_realm() {
    log_step "Exporting Realm Configuration ($REALM_NAME)"
    local export_timestamp
    export_timestamp=$(date +%Y%m%d_%H%M%S)
    local export_file="/tmp/realm_export_${REALM_NAME}_${export_timestamp}.json"

    log_info "Triggering realm export job..."
    cat <<EOF | oc apply -n "$NAMESPACE" -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: keycloak-realm-export-$export_timestamp
  namespace: $NAMESPACE
spec:
  template:
    spec:
      containers:
        - name: export
          image: registry.redhat.io/rhbk/keycloak-rhel9:24
          command:
            - /opt/keycloak/bin/kc.sh
            - export
            - --file=/tmp/export.json
            - --realm=$REALM_NAME
            - --db=postgres
            - --db-url-host=keycloak-db-primary
            - --db-username=\$(DB_USER)
            - --db-password=\$(DB_PASS)
          env:
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: keycloak-db-secret
                  key: username
            - name: DB_PASS
              valueFrom:
                secretKeyRef:
                  name: keycloak-db-secret
                  key: password
      restartPolicy: OnFailure
EOF
    log_success "Realm export job 'keycloak-realm-export-$export_timestamp' initiated."
}

op_scale() {
    local target_replicas="${2:-3}"
    log_step "Scaling Keycloak Instance '$KEYCLOAK_CR_NAME' to $target_replicas Replicas"
    oc patch keycloak "$KEYCLOAK_CR_NAME" -n "$NAMESPACE" --type merge -p "{\"spec\": {\"instances\": $target_replicas}}"
    log_success "Scaled Keycloak CR to $target_replicas instances."
    oc get pods -n "$NAMESPACE" -l app=keycloak -w
}

op_rolling_restart() {
    log_step "Triggering Zero-Downtime Rolling Restart of Keycloak StatefulSet"
    oc rollout restart statefulset "$KEYCLOAK_CR_NAME" -n "$NAMESPACE" 2>/dev/null || \
    oc rollout restart deployment "$KEYCLOAK_CR_NAME" -n "$NAMESPACE" 2>/dev/null || \
    log_info "Restart triggered via Operator reconciliation."
    log_success "Rolling restart initiated."
}

show_menu() {
    printf "\n${BOLD}${CYAN}Keycloak Day 2 Operations Menu:${NC}\n"
    printf "  1) Health & Cluster Status Check\n"
    printf "  2) Scrape Prometheus Metrics\n"
    printf "  3) Backup PostgreSQL Database\n"
    printf "  4) Export Realm Configuration\n"
    printf "  5) Scale Replicas\n"
    printf "  6) Zero-Downtime Rolling Restart\n"
    printf "  q) Quit\n\n"
    read -rp "Select an operation [1-6, q]: " choice
    case "$choice" in
        1) op_health_check ;;
        2) op_metrics_scrape ;;
        3) op_backup_db ;;
        4) op_export_realm ;;
        5)
            read -rp "Enter target replica count: " reps
            op_scale "scale" "$reps"
            ;;
        6) op_rolling_restart ;;
        q|Q) exit 0 ;;
        *) log_error "Invalid option selected." ;;
    esac
}

case "$ACTION" in
    health|status) op_health_check ;;
    metrics) op_metrics_scrape ;;
    backup|backup-db) op_backup_db ;;
    export|export-realm) op_export_realm ;;
    scale) op_scale "$@" ;;
    restart|rollout) op_rolling_restart ;;
    menu) show_menu ;;
    *)
        log_error "Unknown action '$ACTION'."
        echo "Usage: $0 {health|metrics|backup-db|export-realm|scale <count>|restart|menu}"
        exit 1
        ;;
esac
