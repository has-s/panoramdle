include .env.docker

# Makefile for Panoramdle
.PHONY: help build up down restart logs status clean migrate db-init db-backup db-restore db-shell create-admin bootstrap-admin deploy rollback health first-run

GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m

help: ## Show available commands
	@echo "$(GREEN)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

##@ Docker

build: ## Build Docker images
	@echo "$(GREEN)Building Docker images...$(NC)"
	docker compose build --build-arg VITE_API_URL=${VITE_API_URL}

up: ## Start all services
	@echo "$(GREEN)Starting services...$(NC)"
	docker compose up -d
	@echo "$(GREEN)Services started!$(NC)"
	@sleep 3
	@make status

down: ## Stop all services
	@echo "$(YELLOW)Stopping services...$(NC)"
	docker compose down

restart: ## Restart all services
	@make down
	@make up

logs: ## Show logs (usage: make logs SERVICE=backend)
	@if [ -z "$(SERVICE)" ]; then \
		docker compose logs -f; \
	else \
		docker compose logs -f $(SERVICE); \
	fi

status: ## Show services status
	@echo "$(GREEN)=== Docker Services Status ===$(NC)"
	@docker compose ps
	@echo ""
	@echo "$(GREEN)=== Container Health ===$(NC)"
	@docker ps --format "table {{.Names}}\t{{.Status}}" | grep panoramdle || echo "No panoramdle containers running"

clean: ## Clean unused Docker resources
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	docker system prune -f
	@echo "$(GREEN)Cleanup complete!$(NC)"

##@ Database

migrate: ## Apply database migrations
	@echo "$(GREEN)Applying database migrations...$(NC)"
	@./scripts/db_migrate.sh

db-backup: ## Create database backup
	@echo "$(GREEN)Creating database backup...$(NC)"
	@./scripts/db_backup.sh

db-backups: ## List all available backups
	@echo "$(GREEN)=== Available Backups ===$(NC)"
	@ls -lht backups/ 2>/dev/null | head -10 || echo "No backups found"
	@echo ""
	@echo "Restore: make db-restore"

db-restore: ## Restore database from backup (interactive)
	@./scripts/db_restore.sh

db-shell: ## Open psql shell in database
	@docker exec -it panoramdle_db sh -c 'psql -U $$POSTGRES_USER $$POSTGRES_DB'

##@ User Management

create-admin: ## Create administrator (interactive)
	@echo "$(GREEN)Creating administrator (interactive)...$(NC)"
	@./scripts/create_admin.sh

bootstrap-admin: ## Create administrator from .env (automatic)
	@echo "$(GREEN)Creating administrator from environment...$(NC)"
	@USE_ENV_VARS=true ./scripts/create_admin.sh

##@ Deployment

deploy: ## Deploy to production
	@echo "$(GREEN)Deploying to production...$(NC)"
	@./scripts/deploy.sh

rollback: ## Rollback last deployment
	@echo "$(YELLOW)Rolling back deployment...$(NC)"
	@./scripts/rollback.sh

health: ## Check services health
	@echo "$(GREEN)=== Backend Health ===$(NC)"
	@if [ -f .env.docker ]; then \
		set -a && source .env.docker && set +a && \
		BACKEND_PORT=$${BACKEND_PORT:-8000} && \
		curl -f http://localhost:$$BACKEND_PORT/health 2>/dev/null && echo "$(GREEN)✓ Backend OK$(NC)" || echo "$(RED)✗ Backend DOWN$(NC)"; \
	else \
		curl -f http://localhost:8000/health 2>/dev/null && echo "$(GREEN)✓ Backend OK$(NC)" || echo "$(RED)✗ Backend DOWN$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)=== Database Health ===$(NC)"
	@docker compose exec panoramdle_db pg_isready 2>/dev/null && echo "$(GREEN)✓ Database OK$(NC)" || echo "$(RED)✗ Database DOWN$(NC)"

##@ Development

dev: ## Start development environment (with logs)
	@echo "$(GREEN)Starting development environment...$(NC)"
	docker compose up

shell-backend: ## Open shell in backend container
	@docker compose exec panoramdle_backend sh

shell-db: ## Open psql in database
	@docker compose exec panoramdle_db sh -c 'psql -U $$POSTGRES_USER $$POSTGRES_DB'

##@ Monitoring

stats: ## Show Docker stats
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep panoramdle

disk: ## Show disk usage
	@echo "$(GREEN)=== Docker Disk Usage ===$(NC)"
	@docker system df
	@echo ""
	@echo "$(GREEN)=== Database Size ===$(NC)"
	@docker compose exec panoramdle_db sh -c 'psql -U $$POSTGRES_USER $$POSTGRES_DB -c "SELECT pg_size_pretty(pg_database_size('"'"'$$POSTGRES_DB'"'"'));"' 2>/dev/null || echo "Database not available"

##@ Quick Start

first-run: up migrate bootstrap-admin ## First run setup (start + migrate + create admin)
	@echo ""
	@echo "$(GREEN)✓ First run complete!$(NC)"
	@echo ""
	@echo "Application: http://localhost:8000"
	@echo "Login: http://localhost:8000/moderation/login"
	@echo ""
	@echo "Admin credentials are in .env.docker"
	@echo "Change password after first login!"
