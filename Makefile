# TeaPot Platform Builder - Master Build Orchestrator
# This Makefile coordinates building all services and apps

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Configuration
API_SPEC_REPO := https://github.com/Team-Tea-Pot/teapot-api-specs.git
USER_SERVICE_REPO := https://github.com/Team-Tea-Pot/teapot-user-service.git
SUPPLIER_APP_REPO := https://github.com/Team-Tea-Pot/supplier-app-ui.git

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

##@ General

.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(BLUE)<target>$(NC)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup

.PHONY: setup
setup: ## Initial setup - clones all repositories and prepares build
	@echo "$(GREEN)Setting up TeaPot Platform...$(NC)"
	@$(MAKE) -s ci-prepare
	@$(MAKE) -s install-tools
	@echo "$(GREEN)Setup complete!$(NC)"

.PHONY: ci-prepare
ci-prepare: ## Prepare repositories (clone, checkout, sync DB scripts)
	@echo "$(BLUE)Preparing repositories and syncing DB scripts...$(NC)"
	@python3 scripts/prepare_build.py

.PHONY: list-images
list-images: ## Print the list of images from images.json
	@python3 -c 'import json,sys;print(json.dumps(json.load(open("images.json")),indent=2))'

.PHONY: build-builders
build-builders: ## Build all builder images (tags: <name>-builder:latest)
	@echo "$(BLUE)Building builder images...$(NC)"
	@python3 scripts/build_images.py --builders

.PHONY: build-images
build-images: ## Build deployable images and tag as :latest
	@echo "$(BLUE)Building deployable images...$(NC)"
	@python3 scripts/build_images.py --deploys

.PHONY: build-all
build-all: ## Build both builder and deployable images
	@echo "$(BLUE)Building all images...$(NC)"
	@python3 scripts/build_images.py --all

.PHONY: install-tools
install-tools: ## Install required build tools
	@echo "$(BLUE)Installing build tools...$(NC)"
	@# Check Docker
	@if ! command -v docker &> /dev/null; then \
		echo "$(RED)[ERROR] Docker not found. Please install Docker first.$(NC)"; \
		exit 1; \
	else \
		echo "  [OK] Docker found"; \
	fi
	@# Check Go
	@if ! command -v go &> /dev/null; then \
		echo "$(YELLOW)[WARN] Go not found. Install from https://golang.org$(NC)"; \
	else \
		echo "  [OK] Go found"; \
	fi
	@# Check Flutter
	@if ! command -v flutter &> /dev/null; then \
		echo "$(YELLOW)[WARN] Flutter not found. Install from https://flutter.dev$(NC)"; \
	else \
		echo "  [OK] Flutter found"; \
	fi
	@# Pull OpenAPI Generator Docker image
	@docker pull openapitools/openapi-generator-cli:latest > /dev/null 2>&1 && echo "  [OK] OpenAPI Generator ready"

##@ Code Generation

.PHONY: generate-all
generate-all: ## Generate all code from API specs
	@echo "$(GREEN)Generating all code from API specs...$(NC)"
	@$(MAKE) -s generate-backend
	@echo "$(GREEN)All code generated!$(NC)"

.PHONY: generate-backend
generate-backend: ## Generate Go backend code from OpenAPI spec
	@echo "$(BLUE)Generating Go backend code...$(NC)"
	@if [ -d "repos/teapot-user-service" ]; then \
		cd repos/teapot-user-service && make generate; \
		echo "$(GREEN)  [OK] Backend code generated$(NC)"; \
	else \
		echo "$(RED)[ERROR] User service repo not found. Run 'make clone-repos' first.$(NC)"; \
	fi

##@ Build

.PHONY: build-backend
build-backend: ## Build Go backend service
	@echo "$(BLUE)Building user service...$(NC)"
	@cd repos/teapot-user-service && make build
	@echo "$(GREEN)  [OK] Backend built: repos/teapot-user-service/bin/server$(NC)"

##@ Run

.PHONY: run-backend
run-backend: ## Run the backend service
	@echo "$(GREEN)Starting user service on :8080...$(NC)"
	@cd repos/teapot-user-service && make run

.PHONY: run-app
run-app: ## Run the Flutter app
	@echo "$(GREEN)Starting Flutter app...$(NC)"
	@cd repos/supplier-app-ui && flutter run

.PHONY: dev
dev: ## Start development environment (backend + app)
	@echo "$(GREEN)Starting development environment...$(NC)"
	@echo "$(YELLOW)Starting backend in background...$(NC)"
	@cd repos/teapot-user-service && make run &
	@sleep 3
	@echo "$(YELLOW)Starting Flutter app...$(NC)"
	@cd repos/supplier-app-ui && flutter run

##@ Testing

.PHONY: test-backend
test-backend: ## Test backend service
	@echo "$(BLUE)Testing user service...$(NC)"
	@cd repos/teapot-user-service && go test ./... -v

.PHONY: test-app
test-app: ## Test Flutter app
	@echo "$(BLUE)Testing Flutter app...$(NC)"
	@cd repos/supplier-app-ui && flutter test

.PHONY: test-all
test-all: test-backend test-app ## Run all tests

##@ API Testing

.PHONY: test-api
test-api: ## Test API with sample requests
	@echo "$(BLUE)Testing User Service API...$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Creating a user...$(NC)"
	@curl -X POST http://localhost:8080/api/v1/users \
		-H "Content-Type: application/json" \
		-d '{"businessName":"Ceylon Tea Estates","ownerName":"Jayantha","email":"jay@tea.lk","phoneNumber":"+94771234567","tenantId":"tenant-001","farmSizeHectares":25.5}' \
		-s | jq '.'
	@echo ""
	@echo "$(YELLOW)2. Getting user by ID (replace USER_ID)...$(NC)"
	@echo "curl -X GET http://localhost:8080/api/v1/users/{USER_ID}"

##@ Deployment

.PHONY: deploy
deploy: docker-setup ## Deploy all services locally (build & start)
	@echo "$(BLUE)Deploying all services...$(NC)"
	@docker-compose up -d --build --remove-orphans
	@echo "$(YELLOW)Waiting for services to be ready...$(NC)"
	@sleep 5
	@echo "$(GREEN)Deployment complete!$(NC)"
	@echo "$(BLUE)Access Points:$(NC)"
	@echo "  • User Service: http://localhost:8080"
	@echo "  • pgAdmin:      http://localhost:5050"

.PHONY: undeploy
undeploy: ## Gracefully undeploy and clear all services & data
	@echo "$(YELLOW)Undeploying all services...$(NC)"
	@docker-compose down --volumes --remove-orphans
	@echo "$(GREEN)Undeployment complete (containers & volumes removed)$(NC)"

.PHONY: deploy-backend
deploy-backend: build-backend ## Deploy backend to Cloud Run (requires gcloud)
	@echo "$(BLUE)Deploying to Cloud Run...$(NC)"
	@cd repos/teapot-user-service && gcloud run deploy user-service \
		--source . \
		--region us-central1 \
		--platform managed \
		--allow-unauthenticated

##@ Clean

.PHONY: clean
clean: ## Clean all build artifacts
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@cd repos/teapot-user-service && make clean 2>/dev/null || true
	@cd repos/supplier-app-ui && flutter clean 2>/dev/null || true
	@rm -rf generated/
	@echo "$(GREEN)Cleaned!$(NC)"

.PHONY: clean-all
clean-all: clean ## Clean everything including repos
	@echo "$(RED)[WARN] This will delete all cloned repositories!$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@rm -rf repos/
	@echo "$(GREEN)All repositories removed$(NC)"

##@ Git Operations

.PHONY: pull-all
pull-all: ## Pull latest changes from all repos
	@echo "$(BLUE)Pulling latest changes...$(NC)"
	@cd repos/teapot-api-specs && git pull && echo "  [OK] API specs updated"
	@cd repos/teapot-user-service && git pull && echo "  [OK] User service updated"
	@cd repos/supplier-app-ui && git pull && echo "  [OK] Supplier app updated"

.PHONY: status-all
status-all: ## Show git status of all repos
	@echo "$(BLUE)Repository Status:$(NC)"
	@echo ""
	@echo "$(YELLOW)API Specs:$(NC)"
	@cd repos/teapot-api-specs && git status -s
	@echo ""
	@echo "$(YELLOW)User Service:$(NC)"
	@cd repos/teapot-user-service && git status -s
	@echo ""
	@echo "$(YELLOW)Supplier App:$(NC)"
	@cd repos/supplier-app-ui && git status -s

##@ Quick Commands

.PHONY: quick-build
quick-build: ## Quick rebuild (no code generation)
	@echo "$(GREEN)Quick build...$(NC)"
	@cd repos/teapot-user-service && go build -o bin/server cmd/server/main.go
	@cd repos/supplier-app-ui && flutter build apk --release
	@echo "$(GREEN)Quick build done!$(NC)"

.PHONY: update-spec
update-spec: ## Pull latest API spec and regenerate everything
	@echo "$(BLUE)Updating from latest API spec...$(NC)"
	@cd repos/teapot-api-specs && git pull
	@$(MAKE) -s generate-all
	@echo "$(GREEN)Updated and regenerated!$(NC)"

##@ Docker Operations

.PHONY: docker-setup
docker-setup: ## Setup Docker environment (create .env from example)
	@echo "$(BLUE)Setting up Docker environment...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)  [OK] Created .env from .env.example$(NC)"; \
		echo "$(YELLOW)  [INFO] Please review and update .env with your settings$(NC)"; \
	else \
		echo "$(YELLOW)  [INFO] .env already exists$(NC)"; \
	fi

.PHONY: docker-up
docker-up: ## Start all services with Docker Compose (syncs DB scripts first)
	@$(MAKE) -s ci-prepare
	@echo "$(GREEN)Starting all services...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)Services started!$(NC)"
	@echo "$(BLUE)Access:$(NC)"
	@echo "  • User Service: http://localhost:8080"
	@echo "  • pgAdmin:      http://localhost:5050"
	@echo ""
	@echo "$(YELLOW)Run 'make docker-logs' to view logs$(NC)"

.PHONY: docker-up-build
docker-up-build: ## Build and start all services
	@echo "$(GREEN)Building and starting services...$(NC)"
	@docker-compose up -d --build
	@echo "$(GREEN)Services built and started!$(NC)"

.PHONY: docker-down
docker-down: ## Stop all services
	@echo "$(YELLOW)Stopping all services...$(NC)"
	@docker-compose down
	@echo "$(GREEN)Services stopped$(NC)"

.PHONY: docker-down-volumes
docker-down-volumes: ## Stop services and remove volumes (clean slate)
	@echo "$(RED)[WARN] This will delete all data in Docker volumes!$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker-compose down -v
	@echo "$(GREEN)Services and volumes removed$(NC)"

.PHONY: docker-restart
docker-restart: ## Restart all services
	@echo "$(YELLOW)Restarting services...$(NC)"
	@docker-compose restart
	@echo "$(GREEN)Services restarted$(NC)"

.PHONY: docker-logs
docker-logs: ## View logs from all services
	@docker-compose logs -f

.PHONY: docker-logs-backend
docker-logs-backend: ## View user service logs
	@docker-compose logs -f user-service

.PHONY: docker-logs-db
docker-logs-db: ## View database logs
	@docker-compose logs -f postgres

.PHONY: docker-ps
docker-ps: ## Show status of all services
	@docker-compose ps

.PHONY: docker-shell-backend
docker-shell-backend: ## Open shell in user service container
	@docker-compose exec user-service sh

.PHONY: docker-shell-db
docker-shell-db: ## Open PostgreSQL shell
	@docker-compose exec postgres psql -U teapot -d teapot_users

.PHONY: docker-test
docker-test: ## Run integration tests in Docker
	@echo "$(BLUE)Running integration tests...$(NC)"
	@docker-compose --profile testing run --rm integration-tests
	@echo "$(GREEN)Tests complete!$(NC)"
	@echo "$(YELLOW)View results: ./test-results/report.html$(NC)"

.PHONY: docker-test-watch
docker-test-watch: ## Run integration tests in watch mode
	@echo "$(BLUE)Running tests in watch mode...$(NC)"
	@docker-compose --profile testing run --rm integration-tests \
		pytest /tests -v --looponfail

.PHONY: docker-clean
docker-clean: ## Clean Docker resources (containers, images)
	@echo "$(YELLOW)Cleaning Docker resources...$(NC)"
	@docker-compose down --rmi local --volumes --remove-orphans
	@echo "$(GREEN)Docker resources cleaned$(NC)"

.PHONY: docker-rebuild
docker-rebuild: docker-clean docker-up-build ## Clean rebuild of all services

##@ Database Operations

.PHONY: db-migrate
db-migrate: ## Run database migrations (if applicable)
	@echo "$(BLUE)Running database migrations...$(NC)"
	@docker-compose exec user-service /app/server migrate up
	@echo "$(GREEN)Migrations complete$(NC)"

.PHONY: db-seed
db-seed: ## Seed database with sample data
	@echo "$(BLUE)Seeding database...$(NC)"
	@docker-compose exec postgres psql -U teapot -d teapot_users -f /docker-entrypoint-initdb.d/01-init-database.sql
	@echo "$(GREEN)Database seeded$(NC)"

.PHONY: db-backup
db-backup: ## Backup database
	@echo "$(BLUE)Backing up database...$(NC)"
	@mkdir -p backups
	@docker-compose exec -T postgres pg_dump -U teapot teapot_users > backups/backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)Backup created in ./backups/$(NC)"

.PHONY: db-restore
db-restore: ## Restore database from backup (pass FILE=path/to/backup.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)[ERROR] Please specify backup file: make db-restore FILE=backups/backup.sql$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restoring database from $(FILE)...$(NC)"
	@docker-compose exec -T postgres psql -U teapot teapot_users < $(FILE)
	@echo "$(GREEN)Database restored$(NC)"

##@ Development Workflow

.PHONY: dev-docker
dev-docker: docker-setup docker-up ## Complete Docker development setup
	@echo "$(GREEN)Development environment ready!$(NC)"
	@echo ""
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  1. View logs:      make docker-logs"
	@echo "  2. Run tests:      make docker-test"
	@echo "  3. Open pgAdmin:   http://localhost:5050"
	@echo "  4. Test API:       curl http://localhost:8080/api/v1/users"

.PHONY: dev-status
dev-status: ## Show development environment status
	@echo "$(BLUE)Development Environment Status$(NC)"
	@echo ""
	@echo "$(YELLOW)Docker Services:$(NC)"
	@docker-compose ps
	@echo ""
	@echo "$(YELLOW)Service Health:$(NC)"
	@curl -s http://localhost:8080/health 2>/dev/null | jq '.' || echo "  [ERROR] User Service not responding"

##@ Custom Commands

.PHONY: api
api: ## Quick API test (create and list users)
	@echo "$(BLUE)Testing User Service API...$(NC)"
	@echo ""
	@echo "$(YELLOW)Creating a test user...$(NC)"
	@curl -s -X POST http://localhost:8080/api/v1/users \
		-H "Content-Type: application/json" \
		-d '{"businessName":"Quick Test Estate","ownerName":"Test User","email":"quick_test_$(shell date +%s)@example.com","phoneNumber":"+94771234567","tenantId":"tenant-quick","farmSizeHectares":10.5}' \
		| jq '.' || echo "$(RED)API not responding$(NC)"
	@echo ""
	@echo "$(YELLOW)Listing all users...$(NC)"
	@curl -s http://localhost:8080/api/v1/users | jq '.' || echo "$(RED)API not responding$(NC)"

.PHONY: db
db: docker-shell-db ## Quick access to database (alias for docker-shell-db)

.PHONY: logs
logs: docker-logs ## Quick access to logs (alias for docker-logs)

.PHONY: reset
reset: ## Reset entire environment (stop, remove volumes, restart)
	@echo "$(YELLOW)[WARN] Resetting entire environment...$(NC)"
	@docker-compose down -v
	@echo "$(BLUE)Starting fresh environment...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)Environment reset complete!$(NC)"
	@$(MAKE) -s dev-status

.PHONY: quicktest
quicktest: ## Quick smoke test (health + basic API test)
	@echo "$(BLUE)Running quick smoke test...$(NC)"
	@echo ""
	@echo -n "$(YELLOW)1. Health Check:$(NC) "
	@curl -s http://localhost:8080/health > /dev/null && echo "$(GREEN)[PASS]$(NC)" || echo "$(RED)[FAIL]$(NC)"
	@echo -n "$(YELLOW)2. List Users:$(NC)   "
	@curl -s http://localhost:8080/api/v1/users > /dev/null && echo "$(GREEN)[PASS]$(NC)" || echo "$(RED)[FAIL]$(NC)"
	@echo -n "$(YELLOW)3. Database:$(NC)     "
	@docker-compose exec -T postgres pg_isready -U teapot > /dev/null 2>&1 && echo "$(GREEN)[PASS]$(NC)" || echo "$(RED)[FAIL]$(NC)"

.PHONY: watch
watch: ## Watch backend logs in real-time
	@echo "$(BLUE)Watching backend logs (Ctrl+C to exit)...$(NC)"
	@docker-compose logs -f --tail=50 user-service

.PHONY: open-pgadmin
open-pgadmin: ## Open pgAdmin in browser
	@echo "$(BLUE)Opening pgAdmin...$(NC)"
	@open http://localhost:5050 2>/dev/null || xdg-open http://localhost:5050 2>/dev/null || echo "Open http://localhost:5050 in your browser"

.PHONY: open-api
open-api: ## Open API endpoint in browser
	@echo "$(BLUE)Opening API endpoint...$(NC)"
	@open http://localhost:8080/api/v1/users 2>/dev/null || xdg-open http://localhost:8080/api/v1/users 2>/dev/null || echo "Open http://localhost:8080/api/v1/users in your browser"

.PHONY: stats
stats: ## Show Docker resource usage
	@echo "$(BLUE)Docker Resource Usage$(NC)"
	@docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

.PHONY: health
health: ## Check health of all services
	@echo "$(BLUE)Service Health Check$(NC)"
	@echo ""
	@echo -n "$(YELLOW)Backend:$(NC)    "
	@curl -s http://localhost:8080/health > /dev/null 2>&1 && echo "$(GREEN)[OK] Healthy$(NC)" || echo "$(RED)[FAIL] Unhealthy$(NC)"
	@echo -n "$(YELLOW)Database:$(NC)   "
	@docker-compose exec -T postgres pg_isready -U teapot > /dev/null 2>&1 && echo "$(GREEN)[OK] Ready$(NC)" || echo "$(RED)[FAIL] Not Ready$(NC)"
	@echo -n "$(YELLOW)pgAdmin:$(NC)    "
	@curl -s http://localhost:5050 > /dev/null 2>&1 && echo "$(GREEN)[OK] Running$(NC)" || echo "$(RED)[FAIL] Not Running$(NC)"

.PHONY: fresh
fresh: ## Fresh start (clean, rebuild, test)
	@echo "$(BLUE)Fresh start - clean rebuild and test$(NC)"
	@$(MAKE) -s docker-clean
	@$(MAKE) -s docker-up-build
	@echo "$(YELLOW)Waiting for services...$(NC)"
	@sleep 5
	@$(MAKE) -s quicktest
	@echo "$(GREEN)Fresh environment ready!$(NC)"

.PHONY: peek
peek: ## Peek at database (show user count and latest users)
	@echo "$(BLUE)Database Peek$(NC)"
	@echo ""
	@docker-compose exec -T postgres psql -U teapot -d teapot_users -c \
		"SELECT COUNT(*) as total_users FROM users;" 2>/dev/null || echo "Database not available"
	@echo ""
	@echo "$(YELLOW)Latest 5 users:$(NC)"
	@docker-compose exec -T postgres psql -U teapot -d teapot_users -c \
		"SELECT id, business_name, email, created_at FROM users ORDER BY created_at DESC LIMIT 5;" 2>/dev/null || echo "Database not available"

.PHONY: ports
ports: ## Show all exposed ports
	@echo "$(BLUE)Exposed Ports$(NC)"
	@echo ""
	@echo "$(YELLOW)Service          Port    URL$(NC)"
	@echo "─────────────────────────────────────────────"
	@echo "User Service     8080    http://localhost:8080"
	@echo "PostgreSQL       5432    localhost:5432"
	@echo "pgAdmin          5050    http://localhost:5050"
	@echo ""
	@echo "$(BLUE)Port Usage:$(NC)"
	@lsof -i :8080 -i :5432 -i :5050 2>/dev/null | grep LISTEN || echo "No ports in use"

.PHONY: create-user
create-user: ## Create a sample user (interactive)
	@echo "$(BLUE)Create User$(NC)"
	@read -p "Business Name: " business && \
	read -p "Owner Name: " owner && \
	read -p "Email: " email && \
	read -p "Phone: " phone && \
	read -p "Tenant ID: " tenant && \
	read -p "Farm Size (hectares): " size && \
	curl -X POST http://localhost:8080/api/v1/users \
		-H "Content-Type: application/json" \
		-d "{\"businessName\":\"$$business\",\"ownerName\":\"$$owner\",\"email\":\"$$email\",\"phoneNumber\":\"$$phone\",\"tenantId\":\"$$tenant\",\"farmSizeHectares\":$$size}" \
		| jq '.'

.PHONY: clean-test-data
clean-test-data: ## Clean test results and cache
	@echo "$(YELLOW)Cleaning test data...$(NC)"
	@rm -rf test-results/
	@rm -rf .pytest_cache/
	@rm -rf repos/teapot-integration-tests/tests/__pycache__/
	@rm -rf repos/teapot-integration-tests/tests/*/__pycache__/
	@echo "$(GREEN)Test data cleaned$(NC)"

.PHONY: benchmark
benchmark: ## Run simple performance benchmark
	@echo "$(BLUE)Performance Benchmark$(NC)"
	@echo ""
	@echo "$(YELLOW)Running 10 requests...$(NC)"
	@for i in {1..10}; do \
		start=$$(date +%s%N); \
		curl -s http://localhost:8080/api/v1/users > /dev/null; \
		end=$$(date +%s%N); \
		echo "Request $$i: $$(((end - start) / 1000000))ms"; \
	done

.PHONY: full-cycle
full-cycle: ## Complete development cycle (reset, test, logs)
	@echo "$(BLUE)Running full development cycle...$(NC)"
	@$(MAKE) -s reset
	@sleep 5
	@$(MAKE) -s quicktest
	@$(MAKE) -s api
	@$(MAKE) -s peek
	@echo ""
	@echo "$(GREEN)Full cycle complete!$(NC)"
	@echo "$(YELLOW)Run 'make watch' to monitor logs$(NC)"

##@ CI/CD

.PHONY: ci-test
ci-test: ci-prepare ## Run full CI integration test suite
	@echo "$(BLUE)Starting CI Integration Tests...$(NC)"
	@echo "$(YELLOW)Building services with checked out branches...$(NC)"
	@docker-compose build
	@echo "$(YELLOW)Starting services...$(NC)"
	@docker-compose up -d
	@echo "$(YELLOW)Waiting for health checks...$(NC)"
	@sleep 10
	@echo "$(BLUE)Running tests...$(NC)"
	@docker-compose --profile testing run --rm integration-tests
	@echo "$(GREEN)CI Pipeline Complete!$(NC)"

##@ Documentation

.PHONY: docs
docs: ## Generate API documentation
	@echo "$(BLUE)Generating API documentation...$(NC)"
	@docker run --rm -v ${PWD}/repos/teapot-api-specs:/specs \
		openapitools/openapi-generator-cli generate \
		-i /specs/user-service/openapi.yaml \
		-g html2 \
		-o /specs/docs
	@echo "$(GREEN)  [OK] Docs generated: repos/teapot-api-specs/docs/index.html$(NC)"
	@open repos/teapot-api-specs/docs/index.html 2>/dev/null || true

##@ Docker Images

.PHONY: build-user-service
build-user-service: ## Build user-service image (usage: make build-user-service TAG=branch-1)
	@echo "$(BLUE)Building User Service image...$(NC)"
	@./scripts/build_docker.sh user-service repos/teapot-user-service docker/user-service.Dockerfile $(or $(TAG),latest)

.PHONY: release-user-service
release-user-service: ## Build and push user-service image (usage: make release-user-service TAG=v1.0.0)
	@if [ -z "$(TAG)" ]; then echo "$(RED)Error: TAG is required for release (e.g., make release-user-service TAG=v1.0.0)$(NC)"; exit 1; fi
	@echo "$(BLUE)Releasing User Service image...$(NC)"
	@./scripts/build_docker.sh user-service repos/teapot-user-service docker/user-service.Dockerfile $(TAG) true

.PHONY: build-integration-tests
build-integration-tests: ## Build integration-tests image
	@echo "$(BLUE)Building Integration Tests image...$(NC)"
	@./scripts/build_docker.sh integration-tests repos/teapot-integration-tests repos/teapot-integration-tests/Dockerfile $(or $(TAG),latest)

.PHONY: build-flutter-builder
build-flutter-builder: ## Build Flutter build environment image
	@echo "$(BLUE)Building Flutter Build Environment...$(NC)"
	@docker build -t teapot/flutter-build:latest -f docker/flutter-build.Dockerfile .
	@echo "$(GREEN)Built teapot/flutter-build:latest$(NC)"

.PHONY: build-app
build-app: ## Build Flutter app (requires APP=app-name)
	@if [ -z "$(APP)" ]; then \
		echo "$(RED)Error: APP parameter is required (e.g., make build-app APP=supplier-app-ui)$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Building $(APP) app...$(NC)"
	@docker run --rm -v $(PWD)/repos/$(APP):/app teapot/flutter-build:latest sh -c "cd /app && flutter pub get && flutter build apk --release"
	@echo "$(GREEN)APK built: repos/$(APP)/build/app/outputs/flutter-apk/app-release.apk$(NC)"

.PHONY: build-branch
build-branch: ## Build user-service from specific branch (usage: make build-branch BRANCH=feature-1)
	@if [ -z "$(BRANCH)" ]; then echo "$(RED)Error: BRANCH is required (e.g., make build-branch BRANCH=feature-1)$(NC)"; exit 1; fi
	@echo "$(BLUE)Preparing user-service branch: $(BRANCH)$(NC)"
	@cd repos/teapot-user-service && git fetch --all && git checkout $(BRANCH) && git pull origin $(BRANCH)
	@echo "$(BLUE)Building image for branch: $(BRANCH)$(NC)"
	@./scripts/build_docker.sh user-service repos/teapot-user-service docker/user-service.Dockerfile $(BRANCH)
	@echo "$(GREEN)Image built: teapot/user-service:$(BRANCH)$(NC)"

.PHONY: clean-images
clean-images: ## Remove all teapot images
	@echo "$(YELLOW)Removing all teapot images...$(NC)"
	@docker images | grep teapot | awk '{print $$3}' | xargs docker rmi -f || echo "No teapot images to remove"
	@echo "$(GREEN)Cleaned$(NC)"
