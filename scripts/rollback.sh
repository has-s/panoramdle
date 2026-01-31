#!/usr/bin/env bash
# scripts/rollback.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

if [ -f "$PROJECT_ROOT/.env.docker" ]; then
    set -a
    source "$PROJECT_ROOT/.env.docker"
    set +a
fi

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}=== Starting Rollback ===${NC}"
echo ""

echo -e "${YELLOW}[1/3] Checking for previous version...${NC}"
if [ ! -f .deploy_previous_version ]; then
    echo -e "${RED}✗ No previous version found!${NC}"
    echo "Cannot rollback without saved version."
    exit 1
fi

PREVIOUS_IMAGE=$(cat .deploy_previous_version)
echo "Previous version: $PREVIOUS_IMAGE"

echo -e "${YELLOW}[2/3] Rolling back backend...${NC}"
docker-compose stop backend
docker-compose rm -f backend

docker tag "$PREVIOUS_IMAGE" panoramdle-backend:latest
docker-compose up -d backend

echo "Waiting for backend to start..."
sleep 10

echo -e "${YELLOW}[3/3] Verifying rollback...${NC}"
BACKEND_PORT=${BACKEND_PORT:-8000}

if curl -f http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Rollback successful!${NC}"
    echo ""
    echo "Backend is running on previous version"
    echo ""
    echo -e "${YELLOW}⚠️  Database was NOT rolled back${NC}"
    echo "To restore database from backup:"
    echo "  1. List backups: ls -t backups/"
    echo "  2. Restore: make db-restore FILE=backups/[filename]"
else
    echo -e "${RED}✗ Rollback failed!${NC}"
    echo ""
    echo "=== Backend Logs ==="
    docker-compose logs --tail=50 backend
    exit 1
fi