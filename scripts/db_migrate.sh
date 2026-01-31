#!/usr/bin/env bash
# scripts/db_migrate.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_ENV=${APP_ENV:-docker}
if [ "$APP_ENV" = "docker" ]; then
  ENV_FILE="$PROJECT_ROOT/.env.docker"
  CONTAINER_NAME="panoramdle_db"
else
  ENV_FILE="$PROJECT_ROOT/.env.local"
  CONTAINER_NAME="panoramdle_db"
fi

if [ ! -f "$ENV_FILE" ]; then
  echo -e "${RED}Error: $ENV_FILE not found!${NC}"
  exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

if ! docker ps | grep -q "$CONTAINER_NAME"; then
  echo -e "${RED}Error: Container '$CONTAINER_NAME' is not running!${NC}"
  exit 1
fi

MIGRATIONS_DIR="$PROJECT_ROOT/migrations"

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo -e "${RED}Error: Migrations directory not found: $MIGRATIONS_DIR${NC}"
  exit 1
fi

echo -e "${GREEN}=== Applying Migrations ===${NC}"
echo ""

for migration in $(ls "$MIGRATIONS_DIR"/*.sql 2>/dev/null | sort); do
  MIGRATION_NAME=$(basename "$migration")
  echo -e "${YELLOW}Applying: $MIGRATION_NAME${NC}"

  if docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" "$POSTGRES_DB" < "$migration"; then
    echo -e "${GREEN}✓ $MIGRATION_NAME applied successfully${NC}"
  else
    echo -e "${RED}✗ Error applying $MIGRATION_NAME${NC}"
    exit 1
  fi
  echo ""
done

echo -e "${GREEN}=== All migrations applied ===${NC}"
echo ""

echo "Database tables:"
docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "\dt"