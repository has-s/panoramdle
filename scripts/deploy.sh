#!/usr/bin/env bash
# scripts/deploy.sh
# Скрипт для безопасного деплоя приложения

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Starting Deployment ===${NC}"
echo ""

# 1. Проверка текущего состояния (с автозапуском)
echo -e "${YELLOW}[1/9] Checking current state...${NC}"
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${YELLOW}Services are not running. Starting them...${NC}"
    docker-compose up -d
    sleep 10
    echo -e "${GREEN}✓ Services started${NC}"
fi

# 2. ОБЯЗАТЕЛЬНЫЙ бэкап БД перед каждым деплоем
echo -e "${YELLOW}[2/9] Creating database backup (CRITICAL)...${NC}"
if [ -f "./scripts/db_backup.sh" ]; then
    ./scripts/db_backup.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Backup failed! Aborting deployment.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Backup completed successfully${NC}"
else
    echo -e "${RED}Error: Backup script not found! Aborting deployment.${NC}"
    exit 1
fi

# 3. Сохранение текущей версии для возможного отката
echo -e "${YELLOW}[3/9] Saving current version...${NC}"
CURRENT_VERSION=$(docker-compose images -q backend)
echo "$CURRENT_VERSION" > .deploy_previous_version
echo "Previous version saved: $CURRENT_VERSION"

# 4. Pull последних изменений из Git (если используется)
if [ -d .git ]; then
    echo -e "${YELLOW}[4/9] Pulling latest changes from Git...${NC}"
    git pull origin main
else
    echo -e "${YELLOW}[4/9] Skipping Git pull (not a git repository)${NC}"
fi

# 5. Сборка новых образов
echo -e "${YELLOW}[5/9] Building new images...${NC}"
docker-compose build --no-cache backend

# 6. Проверка конфигурации Nginx (если есть)
if command -v nginx &> /dev/null; then
    echo -e "${YELLOW}[6/9] Testing Nginx configuration...${NC}"
    if ! sudo nginx -t > /dev/null 2>&1; then
        echo -e "${RED}Error: Nginx configuration test failed!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}[6/9] Skipping Nginx test (not installed on host)${NC}"
fi

# 7. Деплой с минимальным downtime
echo -e "${YELLOW}[7/9] Deploying new version...${NC}"

# Останавливаем backend
docker-compose stop backend

# Удаляем старый контейнер
docker-compose rm -f backend

# Запускаем новый
docker-compose up -d backend

# Ждем запуска
echo "Waiting for backend to start..."
sleep 10

# 8. Health check
echo -e "${YELLOW}[8/9] Running health check...${NC}"
MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Health check passed!${NC}"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Health check attempt $RETRY_COUNT/$MAX_RETRIES..."
    sleep 3
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}✗ Health check failed! Rolling back...${NC}"

    # Откат
    if [ -f .deploy_previous_version ]; then
        PREVIOUS_VERSION=$(cat .deploy_previous_version)
        docker tag $PREVIOUS_VERSION panoramdle_backend:latest
        docker-compose up -d --no-deps backend
        echo -e "${YELLOW}Rolled back to previous version${NC}"

        # Предложить восстановить бэкап
        echo ""
        echo -e "${YELLOW}To restore database from backup:${NC}"
        echo "  ls backups/"
        echo "  make db-restore FILE=backups/panoramdle_YYYY-MM-DD_HH-MM-SS.sql"
    fi

    exit 1
fi

# 9. Очистка
echo -e "${YELLOW}[9/9] Cleaning up old images...${NC}"
docker system prune -f

echo ""
echo -e "${GREEN}=== Deployment Successful! ===${NC}"
echo ""
echo "Database backup saved in: backups/"
echo ""
echo "Next steps:"
echo "  - Check logs: make logs SERVICE=backend"
echo "  - Check status: make status"
echo "  - If issues occur, rollback: make rollback"
echo "  - Latest backup: $(ls -t backups/ | head -1)"