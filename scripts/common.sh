#!/usr/bin/env bash
# ==============================================================================
# Common Helper Functions for Keycloak on OpenShift 4.20+ Automation Suite
# ==============================================================================

set -eo pipefail

# ANSI Colors for Output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color

# Global Configuration
export NAMESPACE="${KEYCLOAK_NAMESPACE:-keycloak}"
export OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE:-keycloak}"
export KEYCLOAK_CR_NAME="${KEYCLOAK_CR_NAME:-keycloak-enterprise}"
export REALM_NAME="${REALM_NAME:-enterprise}"

log_info() {
    printf "${CYAN}[INFO] %b${NC}\n" "$*"
}

log_success() {
    printf "${GREEN}[SUCCESS] %b${NC}\n" "$*"
}

log_warn() {
    printf "${YELLOW}[WARN] %b${NC}\n" "$*"
}

log_error() {
    printf "${RED}[ERROR] %b${NC}\n" "$*" >&2
}

log_step() {
    printf "\n${BOLD}${PURPLE}==> %b${NC}\n" "$*"
}

print_banner() {
    local title="$1"
    printf "${BOLD}${BLUE}"
    printf "==============================================================================\n"
    printf " %s\n" "$title"
    printf " Red Hat Build of Keycloak (RHBK) - OpenShift 4.20+ (AWS / Entra ID)\n"
    printf "==============================================================================\n"
    printf "${NC}\n"
}

check_prerequisites() {
    log_info "Validating required CLI binaries..."
    local required_tools=("oc" "kubectl" "jq" "curl")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required CLI tools: ${missing_tools[*]}"
        log_error "Please install the missing tools before proceeding."
        exit 1
    fi

    # Check OpenShift Cluster Login
    if ! oc whoami &>/dev/null; then
        log_warn "Active OpenShift session not detected via 'oc whoami'."
        log_warn "If executing in live cluster mode, please login: 'oc login --server=<URL> --token=<TOKEN>'"
    else
        local current_user
        current_user=$(oc whoami)
        local current_server
        current_server=$(oc whoami --show-server)
        log_success "Authenticated as '$current_user' on '$current_server'"
    fi
}

wait_for_pod_ready() {
    local label_selector="$1"
    local namespace="${2:-$NAMESPACE}"
    local timeout="${3:-300s}"

    log_info "Waiting for pods with selector '$label_selector' in namespace '$namespace' to be ready..."
    if oc wait --for=condition=Ready pod -l "$label_selector" -n "$namespace" --timeout="$timeout"; then
        log_success "Pods matching '$label_selector' are Ready."
    else
        log_error "Timeout waiting for pods matching '$label_selector' to become Ready."
        return 1
    fi
}

get_keycloak_url() {
    local route_host
    route_host=$(oc get route keycloak -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    if [ -n "$route_host" ]; then
        echo "https://$route_host"
    else
        echo "https://sso.enterprise.example.com"
    fi
}
