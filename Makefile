# Makefile для panoramdle
.PHONY: help build up down restart logs status clean backup restore deploy nginx-reload nginx-test db-init db-seed db-status health

GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m

help: ## Показать справку
	@echo "$(GREEN)Доступные команды:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

##@ Docker

build: ## Собрать Docker образы
	@echo "$(GREEN)Building Docker images...$(NC)"
	docker-compose build

up: ## Запустить все сервисы
	@echo "$(GREEN)Starting services...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)Services started!$(NC)"
	@sleep 3
	@make status

down: ## Остановить все сервисы
	@echo "$(YELLOW)Stopping services...$(NC)"
	docker-compose down

restart: ## Перезапустить все сервисы
	@make down
	@make up

logs: ## Показать логи (использование: make logs SERVICE=backend)
	@if [ -z "$(SERVICE)" ]; then \
		docker-compose logs -f; \
	else \
		docker-compose logs -f $(SERVICE); \
	fi

status: ## Показать статус сервисов
	@echo "$(GREEN)=== Docker Services Status ===$(NC)"
	@docker-compose ps
	@echo ""
	@echo "$(GREEN)=== Container Health ===$(NC)"
	@docker ps --format "table {{.Names}}\t{{.Status}}" | grep panoramdle || echo "No panoramdle containers running"

clean: ## Очистить неиспользуемые Docker ресурсы
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	docker system prune -f
	@echo "$(GREEN)Cleanup complete!$(NC)"

##@ Database

db-init: ## Инициализировать базу данных
	@echo "$(GREEN)Initializing database...$(NC)"
	./scripts/db_init.sh

db-status: ## Показать статус БД
	./scripts/db_status.sh

db-backup: ## Создать резервную копию БД
	@echo "$(GREEN)Creating database backup...$(NC)"
	./scripts/db_backup.sh

db-backups: ## Показать список всех бэкапов
	@echo "$(GREEN)=== Available Backups ===$(NC)"
	@ls -lht backups/ | head -10 || echo "No backups found"
	@echo ""
	@echo "Restore with: make db-restore FILE=backups/filename.sql"

db-restore: ## Восстановить БД из бэкапа (использование: make db-restore FILE=backups/file.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Error: Please specify FILE=backups/file.sql$(NC)"; \
		exit 1; \
	fi
	./scripts/db_restore.sh $(FILE)

db-clean: ## Очистить БД
	@echo "$(RED)Warning: This will delete all data!$(NC)"
	./scripts/db_clean.sh

db-shell: ## Открыть psql в БД
	docker-compose exec panoramdle_db psql -U postgres newsdb

##@ Nginx (on host)

nginx-install: ## Установить Nginx конфигурацию (первый раз)
	./scripts/nginx_reload.sh install

nginx-reload: ## Перезагрузить Nginx
	./scripts/nginx_reload.sh reload

nginx-test: ## Проверить конфигурацию Nginx
	./scripts/nginx_reload.sh test

nginx-restart: ## Перезапустить Nginx
	./scripts/nginx_reload.sh restart

nginx-status: ## Статус Nginx
	./scripts/nginx_reload.sh status

nginx-logs: ## Показать логи Nginx
	./scripts/nginx_reload.sh logs

nginx-disable: ## Отключить сайт в Nginx
	./scripts/nginx_reload.sh disable

##@ Development

dev: ## Запустить в режиме разработки (с логами)
	@echo "$(GREEN)Starting development environment...$(NC)"
	docker-compose up

shell-backend: ## Открыть shell в контейнере backend
	docker-compose exec panoramdle_backend sh

shell-db: ## Открыть psql в БД
	docker-compose exec panoramdle_db psql -U postgres newsdb

##@ Deployment

deploy: ## Деплой на production
	@echo "$(GREEN)Deploying to production...$(NC)"
	./scripts/deploy.sh

rollback: ## Откатить последний деплой
	@echo "$(YELLOW)Rolling back...$(NC)"
	./scripts/rollback.sh

health: ## Проверить здоровье сервисов
	@echo "$(GREEN)=== Backend Health ===$(NC)"
	@if [ -f .env.docker ]; then \
		source .env.docker && \
		BACKEND_PORT=${BACKEND_PORT:-8000} && \
		curl -f http://localhost:$BACKEND_PORT/health 2>/dev/null && echo "$(GREEN)✓ Backend OK$(NC)" || echo "$(RED)✗ Backend DOWN$(NC)"; \
	else \
		curl -f http://localhost:8000/health 2>/dev/null && echo "$(GREEN)✓ Backend OK$(NC)" || echo "$(RED)✗ Backend DOWN$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)=== Database Health ===$(NC)"
	@docker-compose exec panoramdle_db pg_isready -U postgres 2>/dev/null && echo "$(GREEN)✓ Database OK$(NC)" || echo "$(RED)✗ Database DOWN$(NC)"

##@ Monitoring

stats: ## Показать статистику Docker
	docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep panoramdle

disk: ## Показать использование диска
	@echo "$(GREEN)=== Docker Disk Usage ===$(NC)"
	docker system df
	@echo ""
	@echo "$(GREEN)=== Database Size ===$(NC)"
	@docker-compose exec panoramdle_db psql -U postgres newsdb -c "SELECT pg_size_pretty(pg_database_size('newsdb'));" 2>/dev/null || echo "Database not available"

##@ Quick Start

first-run: ## Первый запуск проекта (build + init + up)
	@echo "$(GREEN)=== First Run Setup ===$(NC)"
	@make build
	@make up
	@sleep 5
	@make db-init
	@echo ""
	@echo "$(GREEN)✓ Setup complete!$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  - Add news at: http://localhost:8000/addnews"
	@echo "  - Install Nginx config: make nginx-install"
	@echo "  - Check status: make status"
	@echo "  - View logs: make logs"