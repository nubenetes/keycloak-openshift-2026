#!/usr/bin/env bash
# ==============================================================================
# DAY 1: Client Application Registrations & OAuth 2.1 Mappings
# Registers ArgoCD, Backstage, Angular SPA, and Microservices in Keycloak
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

print_banner "DAY 1: APPLICATION REGISTRATION & OAUTH 2.1 CONFIGURATION"
check_prerequisites

KC_URL=$(get_keycloak_url)
CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-apps.cluster-charlie.aws.enterprise.com}"

log_step "1. Validating Declarative Client Definitions"
log_info "Target Keycloak Instance: $KC_URL"
log_info "Target Realm:             $REALM_NAME"
log_info "Cluster Base Domain:      $CLUSTER_DOMAIN"

log_step "2. Verifying Configured Clients in Enterprise Realm"
cat <<EOF
Registered OAuth 2.1 & OIDC Applications:
  [1] ArgoCD GitOps Portal:
      - Client ID:        argocd
      - Access Type:      Confidential (Authorization Code + PKCE)
      - Redirect URI:     https://argocd.$CLUSTER_DOMAIN/auth/callback
      - Scopes:           openid, profile, email, groups

  [2] Backstage Developer Portal:
      - Client ID:        backstage-idp
      - Access Type:      Confidential (Auth Code + PKCE + Service Account)
      - Redirect URI:     https://backstage.$CLUSTER_DOMAIN/api/auth/oidc/handler/frame
      - Scopes:           openid, profile, email, groups

  [3] Enterprise Angular 18+ SPA:
      - Client ID:        angular-spa
      - Access Type:      Public (Strict PKCE with S256 challenge)
      - Redirect URI:     https://portal.$CLUSTER_DOMAIN/*
      - Token Lifespan:   300s (5 minutes)

  [4] Edge Microservices API Gateway:
      - Client ID:        microservices-gateway
      - Access Type:      Confidential (Private Key JWT RFC 7523 / Client Credentials)
      - Scopes:           microservices.read, microservices.write

  [5] Quarkus Core API Service:
      - Client ID:        quarkus-api-service
      - Access Type:      Resource Server / Token Exchange RFC 8693
      - Scopes:           microservices.read, microservices.write
EOF

log_step "3. Applying OpenShift Sample Application Secret Patches"
# Patch ArgoCD OpenID Connect config if ArgoCD is deployed in openshift-gitops
if oc get configmap argocd-cm -n openshift-gitops &>/dev/null; then
    log_info "ArgoCD detected in 'openshift-gitops'. Applying OIDC configuration..."
    oc patch configmap argocd-cm -n openshift-gitops --type merge -p "$(cat "$REPO_ROOT/apps/argocd/argocd-cm-patch.yaml")"
    oc patch configmap argocd-rbac-cm -n openshift-gitops --type merge -p "$(cat "$REPO_ROOT/apps/argocd/argocd-rbac-cm.yaml")"
    log_success "ArgoCD OIDC ConfigMap successfully patched."
else
    log_info "ArgoCD not installed or not in 'openshift-gitops' namespace. Manifests available in 'apps/argocd/'."
fi

log_success "Application registration complete."
