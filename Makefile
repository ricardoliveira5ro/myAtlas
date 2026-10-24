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

dev: ## Run the application locally (services + web shell)
	@printf 'dev: not wired yet (see M3.2 and M4)\n'

format: ## Format Java and TypeScript/JavaScript sources
	@printf 'format: not wired yet (see M3.2 and M6)\n'

lint: ## Run static analysis across the monorepo
	@printf 'lint: not wired yet (see M6)\n'

test: ## Run backend and web test suites
	@printf 'test: not wired yet (see M3.2 and M6)\n'

build: ## Build all services and the web application
	@printf 'build: not wired yet (see M3.2 and M6)\n'

contracts: ## Export OpenAPI documents and generate TypeScript types
	@printf 'contracts: not wired yet (see M5.1)\n'

infra-validate: ## Validate the Terraform skeleton (fmt + validate)
	@printf 'infra-validate: not wired yet (see M8.2)\n'
