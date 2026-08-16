.PHONY: help lint validate test-oauth2 day0 day1-dev day1-prod day2 local-up local-down decommission

help: ## Display available make targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

lint: ## Lint and validate bash scripts syntax
	@echo "==> Linting shell scripts..."
	@chmod +x scripts/*.sh
	@bash -n scripts/*.sh
	@echo "All scripts passed syntax validation."

validate: lint ## Validate all Kustomize overlays
	@echo "==> Validating Kustomize overlays..."
	@kubectl kustomize gitops/clusters/cluster-alpha-dev > /dev/null
	@kubectl kustomize gitops/clusters/cluster-bravo-stage > /dev/null
	@kubectl kustomize gitops/clusters/cluster-charlie-prod > /dev/null
	@kubectl kustomize gitops/clusters/cluster-hub-central > /dev/null
	@echo "All Kustomize overlays are valid."

test-oauth2: ## Run end-to-end OAuth 2.1 / OIDC protocol validation
	@./scripts/validate-oauth2-flows.sh

day0: ## Run Day 0 cluster prerequisites and network policies
	@./scripts/day0-prereqs.sh

day1-dev: ## Deploy Operator and Keycloak to Dev cluster
	@./scripts/day1-deploy-operator-and-keycloak.sh cluster-alpha-dev

day1-prod: ## Deploy Operator and Keycloak to Prod HA cluster
	@./scripts/day1-deploy-operator-and-keycloak.sh cluster-charlie-prod

day2: ## Open Day 2 interactive maintenance and operations suite
	@./scripts/day2-operations-suite.sh

local-up: ## Start local testing sandbox (Keycloak, OpenLDAP, Postgres, Apps)
	@./scripts/local-sandbox-up.sh

local-down: ## Stop local testing sandbox
	@docker compose -f local-dev/docker-compose.yml down

decommission: ## Run cluster decommissioning runbook
	@./scripts/decommission-cluster.sh
