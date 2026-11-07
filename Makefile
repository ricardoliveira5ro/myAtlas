.DEFAULT_GOAL := help
SHELL := /bin/bash

# Declares these names as phony targets — "not a file."
# Prevents if someone creates, in the repo root, a file literally named a target here (i.e. test) and Make thinks the target already exists
.PHONY: help dev-infra dev-infra-down dev format lint test build contracts infra-validate

help: ## Show this help
	@printf 'myAtlas - root command surface\n\n'
	@printf 'Usage: make <target>\n\n'
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dev-infra: ## Start local infrastructure (Postgres/PostGIS + Mailpit)
	docker compose up -d --wait

dev-infra-down: ## Stop and remove local infrastructure
	docker compose down

dev: dev-infra ## Start local infrastructure, backend services, and web app
	bash scripts/dev.sh

format: ## Format Java and apply ESLint auto-fixes to web sources
	@set -e; for service in account atlas media social; do \
		printf '\nFormatting %s service...\n' "$$service"; \
		(cd "services/$$service" && ./mvnw -B -ntp spotless:apply); \
	done
	npm run lint -w @my-atlas/web -- --fix

lint: ## Run static analysis across the monorepo
	@set -e; for service in account atlas media social; do \
		printf '\nChecking %s service...\n' "$$service"; \
		(cd "services/$$service" && ./mvnw -B -ntp spotless:check); \
		(cd "services/$$service" && ./mvnw -B -ntp -DskipTests package spotbugs:check); \
	done
	npm run lint -w @my-atlas/web
	npm run contracts:lint

test: ## Run backend and web test suites
	@set -e; for service in account atlas media social; do \
		printf '\nTesting %s service...\n' "$$service"; \
		(cd "services/$$service" && ./mvnw -B -ntp test); \
	done
	npm run typecheck -w @my-atlas/web

build: ## Build all services and the web application
	@set -e; for service in account atlas media social; do \
		printf '\nBuilding %s service...\n' "$$service"; \
		(cd "services/$$service" && ./mvnw -B -ntp -DskipTests package); \
	done
	npm run build -w @my-atlas/web

contracts: ## Export OpenAPI from running services and generate TypeScript types
	bash services/account/scripts/export-openapi.sh
	bash services/atlas/scripts/export-openapi.sh
	bash services/media/scripts/export-openapi.sh
	bash services/social/scripts/export-openapi.sh
	npm run contracts:types

infra-validate: ## Format and validate Terraform without provisioning resources
	@if ! find infra/terraform -type f -name '*.tf' -print -quit | grep -q .; then \
		printf 'No Terraform configuration found under infra/terraform; nothing to validate.\n'; \
	else \
		terraform -chdir=infra/terraform fmt -check -recursive && \
		terraform -chdir=infra/terraform init -backend=false -input=false -lockfile=readonly && \
		terraform -chdir=infra/terraform validate; \
	fi
