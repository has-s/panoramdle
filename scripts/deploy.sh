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

echo -e "${YELLOW}[1/11] Pulling latest changes...${NC}"
if [ -d "$PROJECT_ROOT/.git" ]; then
    cd "$PROJECT_ROOT"
    git fetch origin main
    git reset --hard origin/main
    echo -e "${GREEN}✓ Code updated${NC}"
else
    echo -e "${YELLOW}Not a git repository, skipping${NC}"
fi

echo -e "${YELLOW}[2/11] Creating database backup...${NC}"
if [ -f "./scripts/db_backup.sh" ]; then
    ./scripts/db_backup.sh || { echo -e "${RED}✗ Backup failed! Aborting.${NC}"; exit 1; }
    echo -e "${GREEN}✓ Backup completed${NC}"
else
    echo -e "${RED}✗ db_backup.sh not found! Aborting.${NC}"
    exit 1
fi

echo -e "${YELLOW}[3/11] Saving current backend version...${NC}"
if docker ps --format '{{.Names}}' | grep -q "panoramdle_backend"; then
    CURRENT_IMAGE=$(docker inspect panoramdle_backend --format='{{.Image}}' 2>/dev/null || echo "")
    [ -n "$CURRENT_IMAGE" ] && echo "$CURRENT_IMAGE" > .deploy_previous_version && echo "Saved: $CURRENT_IMAGE"
else
    echo "Backend not running (first deployment)"
fi

echo -e "${YELLOW}[4/11] Applying database migrations...${NC}"
[ -f "./scripts/db_migrate.sh" ] && ./scripts/db_migrate.sh || echo -e "${YELLOW}db_migrate.sh not found, skipping${NC}"

echo -e "${YELLOW}[5/11] Checking for admin user...${NC}"
if [ -f "./scripts/create_admin.sh" ]; then
    if USE_ENV_VARS=true ./scripts/create_admin.sh 2>&1 | grep -q "successfully created"; then
        echo -e "${GREEN}✓ Admin created${NC}"
    else
        echo "Admin already exists, skipping"
    fi
else
    echo -e "${YELLOW}create_admin.sh not found, skipping${NC}"
fi

echo -e "${YELLOW}[6/11] Building new backend image...${NC}"
docker-compose build backend || { echo -e "${RED}✗ Build failed! Aborting.${NC}"; exit 1; }
echo -e "${GREEN}✓ Image built${NC}"

if command -v nginx &> /dev/null; then
    echo -e "${YELLOW}[7/11] Testing Nginx configuration...${NC}"
    sudo nginx -t > /dev/null 2>&1 || { echo -e "${RED}✗ Nginx config invalid! Aborting.${NC}"; exit 1; }
    echo -e "${GREEN}✓ Nginx OK${NC}"
else
    echo -e "${YELLOW}[7/11] Nginx not installed, skipping${NC}"
fi

echo -e "${YELLOW}[8/11] Stopping old backend...${NC}"
if docker ps --format '{{.Names}}' | grep -q "panoramdle_backend"; then
    docker-compose stop backend
    docker-compose rm -f backend
    echo -e "${GREEN}✓ Old backend stopped${NC}"
else
    echo "No backend running"
fi

echo -e "${YELLOW}[9/11] Starting new backend...${NC}"
docker-compose up -d backend
echo "Waiting for startup..."
sleep 10

echo -e "${YELLOW}[10/11] Running health check...${NC}"
MAX_RETRIES=24
RETRY_COUNT=0
HEALTH_OK=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    CONTAINER_STATUS=$(docker inspect panoramdle_backend --format='{{.State.Status}}' 2>/dev/null || echo "not_found")

    case "$CONTAINER_STATUS" in
        "not_found")
            echo -e "${RED}✗ Container not found!${NC}"
            break
            ;;
        "restarting")
            echo -e "${RED}✗ Container in restart loop!${NC}"
            docker-compose logs --tail=50 backend
            break
            ;;
        "exited")
            echo -e "${RED}✗ Container exited!${NC}"
            docker-compose logs --tail=50 backend
            break
            ;;
        "running")
            if curl -f http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
                echo -e "${GREEN}✓ Health check passed!${NC}"
                HEALTH_OK=true
                break
            fi
            ;;
    esac

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES (status: $CONTAINER_STATUS)"
    sleep 5
done

if [ "$HEALTH_OK" != "true" ]; then
    echo -e "${RED}✗✗✗ DEPLOYMENT FAILED ✗✗✗${NC}"
    echo "=== Backend Logs (last 100 lines) ==="
    docker-compose logs --tail=100 backend

    if [ -f .deploy_previous_version ]; then
        echo -e "${YELLOW}Attempting rollback...${NC}"
        PREVIOUS_IMAGE=$(cat .deploy_previous_version)
        docker-compose stop backend || true
        docker-compose rm -f backend || true
        docker tag "$PREVIOUS_IMAGE" panoramdle-backend:latest
        docker-compose up -d backend
        echo -e "${YELLOW}✓ Rolled back to previous version${NC}"
        echo "To restore database backup:"
        echo "  Latest: $(ls -t backups/ | head -1)"
        echo "  Command: make db-restore FILE=backups/[filename]"
    fi
fi

echo -e "${GREEN}=== Deployment complete ===${NC}"