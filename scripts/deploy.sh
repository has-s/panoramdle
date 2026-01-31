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

echo -e "${YELLOW}[1/10] Creating database backup...${NC}"
if [ -f "./scripts/db_backup.sh" ]; then
    ./scripts/db_backup.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Backup failed! Aborting.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Backup completed${NC}"
else
    echo -e "${RED}✗ db_backup.sh not found! Aborting.${NC}"
    exit 1
fi

echo -e "${YELLOW}[2/10] Saving current backend version...${NC}"
if docker ps --format '{{.Names}}' | grep -q "panoramdle_backend"; then
    CURRENT_IMAGE=$(docker inspect panoramdle_backend --format='{{.Image}}' 2>/dev/null || echo "")
    if [ -n "$CURRENT_IMAGE" ]; then
        echo "$CURRENT_IMAGE" > .deploy_previous_version
        echo "Saved: $CURRENT_IMAGE"
    else
        echo "Could not save current version"
    fi
else
    echo "Backend not running (first deployment)"
fi

echo -e "${YELLOW}[3/10] Applying database migrations...${NC}"
if [ -f "./scripts/db_migrate.sh" ]; then
    ./scripts/db_migrate.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Migrations failed! Aborting.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Migrations applied${NC}"
else
    echo -e "${YELLOW}db_migrate.sh not found, skipping${NC}"
fi

echo -e "${YELLOW}[4/10] Checking for admin user...${NC}"
if [ -f "./scripts/create_admin.sh" ]; then
    USE_ENV_VARS=true ./scripts/create_admin.sh 2>&1 | grep -q "успешно создан" && \
        echo -e "${GREEN}✓ Admin created${NC}" || \
        echo "Admin already exists, skipping"
else
    echo -e "${YELLOW}create_admin.sh not found, skipping${NC}"
fi

echo -e "${YELLOW}[5/10] Building new backend image...${NC}"
docker-compose build backend
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Build failed! Aborting.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Image built${NC}"

if command -v nginx &> /dev/null; then
    echo -e "${YELLOW}[6/10] Testing Nginx configuration...${NC}"
    if sudo nginx -t > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Nginx OK${NC}"
    else
        echo -e "${RED}✗ Nginx config invalid! Aborting.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}[6/10] Nginx not installed, skipping${NC}"
fi

echo -e "${YELLOW}[7/10] Stopping old backend...${NC}"
if docker ps --format '{{.Names}}' | grep -q "panoramdle_backend"; then
    docker-compose stop backend
    docker-compose rm -f backend
    echo -e "${GREEN}✓ Old backend stopped${NC}"
else
    echo "No backend running"
fi

echo -e "${YELLOW}[8/10] Starting new backend...${NC}"
docker-compose up -d backend
echo "Waiting for startup..."
sleep 10

echo -e "${YELLOW}[9/10] Health check...${NC}"
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
    echo ""
    echo -e "${RED}✗✗✗ DEPLOYMENT FAILED ✗✗✗${NC}"
    echo ""
    echo "=== Backend Logs ==="
    docker-compose logs --tail=100 backend
    echo ""

    if [ -f .deploy_previous_version ]; then
        echo -e "${YELLOW}Attempting rollback...${NC}"
        PREVIOUS_IMAGE=$(cat .deploy_previous_version)

        docker-compose stop backend
        docker-compose rm -f backend
        docker tag "$PREVIOUS_IMAGE" panoramdle-backend:latest
        docker-compose up -d backend

        echo -e "${YELLOW}✓ Rolled back to previous version${NC}"
        echo ""
        echo "To restore database backup:"
        echo "  Latest: $(ls -t backups/ | head -1)"
        echo "  Command: make db-restore FILE=backups/[filename]"
    fi

    exit 1
fi

echo -e "${YELLOW}[10/10] Cleanup...${NC}"
docker system prune -f > /dev/null 2>&1
echo -e "${GREEN}✓ Cleanup done${NC}"

echo ""
echo -e "${GREEN}=== ✓ DEPLOYMENT SUCCESSFUL ✓ ===${NC}"
echo "Latest backup: $(ls -t backups/ | head -1 2>/dev/null || echo 'none')"