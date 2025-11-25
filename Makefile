# TeaPot Platform Builder - Docker Image Build System
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

##@ General

.PHONY: help
help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(BLUE)<target>$(NC)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup

.PHONY: setup
setup: prepare check-tools ## Initial setup (clone repos, verify tools)
	@echo "$(GREEN)Setup complete!$(NC)"

.PHONY: prepare
prepare: ## Clone repos, sync branches, collect SQL scripts
	@python3 scripts/prepare_build.py

.PHONY: check-tools
check-tools: ## Verify Docker and Python are installed
	@command -v docker >/dev/null 2>&1 && echo "  ✓ Docker" || (echo "  ✗ Docker required" && exit 1)
	@command -v python3 >/dev/null 2>&1 && echo "  ✓ Python3" || (echo "  ✗ Python3 required" && exit 1)

##@ Build Images

.PHONY: list
list: ## List all images defined in images.json
	@python3 -c 'import json; data=json.load(open("images.json")); [print(f"{k}: {v[\"deploy_image\"]}") for k,v in data["services"].items()]'

.PHONY: build-builders
build-builders: ## Build builder images only
	@python3 scripts/build_images.py --builders

.PHONY: build
build: ## Build deployable images (default)
	@python3 scripts/build_images.py --deploys

.PHONY: build-all
build-all: ## Build both builder and deployable images
	@python3 scripts/build_images.py --all

.PHONY: clean
clean: ## Remove all teapot Docker images
	@echo "$(YELLOW)Removing teapot images...$(NC)"
	@docker images | grep teapot | awk '{print $$3}' | xargs docker rmi -f 2>/dev/null || echo "No images found"
	@echo "$(GREEN)Cleaned$(NC)"

##@ Git Operations

.PHONY: pull
pull: ## Pull latest from all repos
	@cd repos/teapot-api-specs && git pull
	@cd repos/teapot-user-service && git pull

.PHONY: status
status: ## Git status of all repos
	@echo "$(YELLOW)teapot-api-specs:$(NC)" && cd repos/teapot-api-specs && git status -s
	@echo "$(YELLOW)teapot-user-service:$(NC)" && cd repos/teapot-user-service && git status -s

