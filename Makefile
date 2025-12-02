# TeaPot Platform Builder - Docker Image Build System
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
NC := \033[0m

.PHONY: help
help: ## Show available commands
	@echo "\n$(BLUE)TeaPot Image Builder$(NC)\n"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(BLUE)%-15s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: prepare
prepare: ## Clone repos and collect SQL scripts
	@python3 scripts/prepare_build.py

.PHONY: list
list: ## List configured images
	@python3 -c 'import json; data=json.load(open("images.json")); [print(f"{k}: {v[\"deploy_image\"]}") for k,v in data["services"].items()]'

.PHONY: build
build: ## Build deployable images (default)
	@python3 scripts/build_images.py --deploys

.PHONY: build-all
build-all: ## Build both builder and deployable images
	@python3 scripts/build_images.py --all

.PHONY: clean
clean: ## Remove all teapot images
	@docker images | grep teapot | awk '{print $$3}' | xargs docker rmi -f 2>/dev/null || echo "No images to remove"
