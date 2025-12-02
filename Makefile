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

.PHONY: build-postgres
build-postgres: ## Build PostgreSQL image only
	@echo "$(BLUE)Building PostgreSQL image...$(NC)"
	@python3 scripts/prepare_build.py
	@docker build -f docker/postgres.Dockerfile -t teapot/postgres:latest .
	@echo "$(GREEN)Built teapot/postgres:latest$(NC)"

.PHONY: build-redis
build-redis: ## Build Redis image only
	@echo "$(BLUE)Building Redis image...$(NC)"
	@docker build -f docker/redis.Dockerfile -t teapot/redis:latest .
	@echo "$(GREEN)Built teapot/redis:latest$(NC)"

.PHONY: build-user-service
build-user-service: ## Build user-service image only
	@echo "$(BLUE)Building user-service image...$(NC)"
	@cd repos/teapot-user-service && make fetch-spec && make generate && make build
	@cd repos/teapot-user-service && docker build -f ../../docker/user-service.Dockerfile -t teapot/user-service:latest .
	@echo "$(GREEN)Built teapot/user-service:latest$(NC)"

.PHONY: clean
clean: ## Remove all teapot images
	@docker images | grep teapot | awk '{print $$3}' | xargs docker rmi -f 2>/dev/null || echo "No images to remove"

.PHONY: run-postgres
run-postgres: ## Run PostgreSQL container
	@docker run -d --name teapot-postgres \
		-e POSTGRES_USER=teapot \
		-e POSTGRES_PASSWORD=teapot123 \
		-e POSTGRES_DB=teapot_users \
		-p 5432:5432 \
		teapot/postgres:latest
	@echo "$(GREEN)PostgreSQL running on port 5432$(NC)"

.PHONY: run-redis
run-redis: ## Run Redis container
	@docker run -d --name teapot-redis \
		-p 6379:6379 \
		teapot/redis:latest
	@echo "$(GREEN)Redis running on port 6379$(NC)"

.PHONY: run-user-service
run-user-service: ## Run user-service container
	@docker run -d --name teapot-user-service \
		-e DATABASE_URL="postgres://teapot:teapot123@host.docker.internal:5432/teapot_users?sslmode=disable" \
		-e PORT=8080 \
		-p 8080:8080 \
		teapot/user-service:latest
	@echo "$(GREEN)User service running on port 8080$(NC)"

.PHONY: stop-all
stop-all: ## Stop and remove all containers
	@docker rm -f teapot-postgres teapot-redis teapot-user-service 2>/dev/null || true
	@echo "$(GREEN)All containers stopped$(NC)"
