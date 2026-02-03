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

echo -e "${YELLOW}[1/11] Pulling latest changes...${NC}"
if [ -d "$PROJECT_ROOT/.git" ]; then
    cd "$PROJECT_ROOT"
    git fetch origin main
    git reset --hard origin/main
    echo -e "${GREEN}✓ Code updated${NC}"
else
    echo -e "${YELLOW}Not a git repository, skipping${NC}"
fi

echo ""
echo -e "${YELLOW}[2/11] Creating database backup...${NC}"
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

echo ""
echo -e "${YELLOW}[3/11] Saving current backend version...${NC}"
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

echo ""
echo -e "${YELLOW}[4/11] Applying database migrations...${NC}"
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

echo ""
echo -e "${YELLOW}[5/11] Checking for admin user...${NC}"
if [ -f "./scripts/create_admin.sh" ]; then
    USE_ENV_VARS=true ./scripts/create_admin.sh 2>&1 | grep -q "successfully created" && \
        echo -e "${GREEN}✓ Admin created${NC}" || \
        echo "Admin already exists, skipping"
else
    echo -e "${YELLOW}create_admin.sh not found, skipping${NC}"
fi

echo ""
echo -e "${YELLOW}[6/11] Building new backend image...${NC}"
docker-compose build backend
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Build failed! Aborting.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Image built${NC}"

if command -v nginx &> /dev/null; then
    echo ""
    echo -e "${YELLOW}[7/11] Testing Nginx configuration...${NC}"
    if sudo nginx -t > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Nginx OK${NC}"
    else
        echo -e "${RED}✗ Nginx config invalid! Aborting.${NC}"
        exit 1
    fi
else
    echo ""
    echo -e "${YELLOW}[7/11] Nginx not installed, skipping${NC}"
fi

echo ""
echo -e "${YELLOW}[8/11] Stopping old backend...${NC}"
if docker ps --format '{{.Names}}' | grep -q "panoramdle_backend"; then
    docker-compose stop backend
    docker-compose rm -f backend
    echo -e "${GREEN}✓ Old backend stopped${NC}"
else
    echo "No backend running"
fi

echo ""
echo -e "${YELLOW}[9/11] Starting new backend...${NC}"
docker-compose up -d backend
echo "Waiting for startup..."
sleep 10

echo ""
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
    echo ""
    echo -e "${RED}✗✗✗ DEPLOYMENT FAILED ✗✗✗${NC}"
    echo ""
    echo "=== Backend Logs (last 100 lines) ==="
    docker-compose logs --tail=100 backend
    echo ""

    if [ -f .deploy_previous_version ]; then
        echo -e "${YELLOW}Attempting rollback...${NC}"
        PREVIOUS_IMAGE=$(cat .deploy_previous_version)

        docker-compose stop backend
        docker-compose rm -f backend
        docker tag "$PREVIOUS_IMAGE" panoramdle-backend:latest
        docker-compose up -d backend

        echo -e "${YELLOW}✓ Ro