#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

if [ -f "$PROJECT_ROOT/.env.docker" ]; then
    set -a
    source "$PROJECT_ROOT/.env.docker"
    set +a
fi

BACKEND_PORT=${BACKEND_PORT:-8000}

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Starting Deployment ===${NC}"
echo ""

echo -e "${YELLOW}[1/11] Checking current state...${NC}"
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${YELLOW}Services are not running. Starting them...${NC}"
    docker-compose up -d
    sleep 10
    echo -e "${GREEN}✓ Services started${NC}"
fi

echo -e "${YELLOW}[2/11] Creating database backup...${NC}"
if [ -f "./scripts/db_backup.sh" ]; then
    ./scripts/db_backup.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Backup failed! Aborting deployment.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Backup completed${NC}"
else
    echo -e "${RED}✗ Backup script not found! Aborting.${NC}"
    exit 1
fi

echo -e "${YELLOW}[3/11] Saving current version...${NC}"
CURRENT_VERSION=$(docker-compose images -q backend)
echo "$CURRENT_VERSION" > .deploy_previous_version
echo "Previous version: $CURRENT_VERSION"

if [ -d .git ]; then
    echo -e "${YELLOW}[4/11] Pulling latest changes...${NC}"
    git fetch origin main
    git reset --hard origin/main
    echo -e "${GREEN}✓ Updated from GitHub${NC}"
else
    echo -e "${YELLOW}[4/11] Skipping Git pull (not a repository)${NC}"
fi

echo -e "${YELLOW}[5/11] Applying database migrations...${NC}"
if [ -f "./scripts/migrate.sh" ]; then
    ./scripts/migrate.sh
    echo -e "${GREEN}✓ Migrations applied${NC}"
else
    echo -e "${YELLOW}No migrations script, skipping${NC}"
fi

echo -e "${YELLOW}[6/11] Checking for admin user...${NC}"
if [ -f "./scripts/create_admin.sh" ]; then
    USE_ENV_VARS=true ./scripts/create_admin.sh || echo "Admin exists or creation skipped"
else
    echo -e "${YELLOW}No create_admin script, skipping${NC}"
fi

echo -e "${YELLOW}[7/11] Building new images...${NC}"
docker-compose build --no-cache backend

if command -v nginx &> /dev/null; then
    echo -e "${YELLOW}[8/11] Testing Nginx configuration...${NC}"
    if ! sudo nginx -t > /dev/null 2>&1; then
        echo -e "${RED}✗ Nginx test failed!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}[8/11] Skipping Nginx test (not installed)${NC}"
fi

echo -e "${YELLOW}[9/11] Deploying new version...${NC}"
docker-compose stop backend
docker-compose rm -f backend
docker-compose up -d backend

echo "Waiting for backend..."
sleep 5

echo -e "${YELLOW}[10/11] Health check on port $BACKEND_PORT...${NC}"
MAX_RETRIES=20
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    CONTAINER_STATUS=$(docker inspect panoramdle_backend --format='{{.State.Status}}' 2>/dev/null || echo "not_found")

    if [ "$CONTAINER_STATUS" = "restarting" ]; then
        echo -e "${RED}✗ Container in restart loop!${NC}"
        docker-compose logs --tail=100 backend
        exit 1
    fi

    if [ "$CONTAINER_STATUS" != "running" ]; then
        echo -e "${RED}✗ Container status: $CONTAINER_STATUS${NC}"
        docker-compose logs --tail=100 backend
        exit 1
    fi

    if curl -f http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Health check passed!${NC}"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES (container: $CONTAINER_STATUS)..."
    sleep 5
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}✗ Health check failed! Rolling back...${NC}"
    echo ""
    echo "=== Backend logs ==="
    docker-compose logs --tail=30 backend
    echo ""

    if [ -f .deploy_previous_version ]; then
        PREVIOUS_VERSION=$(cat .deploy_previous_version)
        docker tag $PREVIOUS_VERSION panoramdle_backend:latest
        docker-compose up -d --no-deps backend
        echo -e "${YELLOW}Rolled back to previous version${NC}"
    fi

    exit 1
fi

echo -e "${YELLOW}[11/11] Cleaning up...${NC}"
docker system prune -f

echo ""
echo -e "${GREEN}=== Deployment Successful! ===${NC}"
echo "Backup: $(ls -t backups/ | head -1)"