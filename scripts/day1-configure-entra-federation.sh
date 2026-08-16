#!/usr/bin/env bash
# ==============================================================================
# DAY 1: Microsoft Entra ID (Azure AD) & Active Directory Federation Setup
# Configures OIDC Brokering and LDAPS User Federation in Keycloak
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

print_banner "DAY 1: IDENTITY PROVIDER FEDERATION CONFIGURATION"
check_prerequisites

# Configurable Parameters
ENTRA_TENANT_ID="${ENTRA_TENANT_ID:-YOUR_AZURE_TENANT_ID_GUID}"
ENTRA_CLIENT_ID="${ENTRA_CLIENT_ID:-YOUR_AZURE_CLIENT_ID_GUID}"
ENTRA_CLIENT_SECRET="${ENTRA_CLIENT_SECRET:-YOUR_AZURE_CLIENT_SECRET}"
AD_LDAP_URL="${AD_LDAP_URL:-ldaps://ad.enterprise.corp:636}"
AD_BIND_DN="${AD_BIND_DN:-CN=svc-keycloak,OU=ServiceAccounts,DC=enterprise,DC=corp}"
AD_BIND_PASSWORD="${AD_BIND_PASSWORD:-SecretPassword123!}"

log_step "1. Validating Environment & Entra ID Parameters"
log_info "Target Realm: $REALM_NAME"
log_info "Entra ID Tenant ID: $ENTRA_TENANT_ID"
log_info "Entra ID Client ID: $ENTRA_CLIENT_ID"
log_info "Active Directory LDAPS URL: $AD_LDAP_URL"

log_step "2. Generating Patched KeycloakRealmImport Manifest"
TMP_REALM_FILE=$(mktemp)

sed -e "s/YOUR_TENANT_ID/$ENTRA_TENANT_ID/g" \
    -e "s/00000000-0000-0000-0000-000000000000/$ENTRA_CLIENT_ID/g" \
    -e "s/CHANGE_ME_ENTRA_CLIENT_SECRET/$ENTRA_CLIENT_SECRET/g" \
    -e "s|ldaps://ad.enterprise.corp:636|$AD_LDAP_URL|g" \
    -e "s|CHANGE_ME_AD_BIND_PASSWORD|$AD_BIND_PASSWORD|g" \
    "$REPO_ROOT/gitops/base/realms/enterprise-realm-import.yaml" > "$TMP_REALM_FILE"

oc apply -f "$TMP_REALM_FILE" -n "$NAMESPACE"
rm -f "$TMP_REALM_FILE"
log_success "Applied updated KeycloakRealmImport with Entra ID & AD LDAP configuration."

log_step "3. Keycloak Admin REST API Automation Helper"
KC_URL=$(get_keycloak_url)
log_info "Keycloak URL: $KC_URL"

cat <<EOF
------------------------------------------------------------------------------
Entra ID & Active Directory Federation Setup Complete:
  * Entra ID OIDC Broker: Enabled (Azure SSO, PKCE, claims mapping)
  * Active Directory LDAP: Configured (LDAPS, group inheritance, sync: 1h)
  * Auto User Sync:        Active (periodic changed users sync: 3600s)

To verify Entra ID SSO login flow:
  1. Open: $KC_URL/realms/$REALM_NAME/account
  2. Click 'Microsoft Entra ID (Corporate SSO)' button
  3. Authenticate with corporate Microsoft 365 / Entra credentials
------------------------------------------------------------------------------
EOF
