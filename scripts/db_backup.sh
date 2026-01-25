#!/usr/bin/env bash
# scripts/db_backup.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

APP_ENV=${APP_ENV:-docker}
if [ "$APP_ENV" = "docker" ]; then
  ENV_FILE="$PROJECT_ROOT/.env.docker"
  CONTAINER_NAME="panoramdle_db"
else
  ENV_FILE="$PROJECT_ROOT/.env.local"
  CONTAINER_NAME="panoramdle_db"
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE not found!"
  exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

BACKUP_DIR="$PROJECT_ROOT/backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILE="$BACKUP_DIR/newsdb_${TIMESTAMP}.sql"

if ! docker ps | grep -q "$CONTAINER_NAME"; then
  echo "Error: Container '$CONTAINER_NAME' is not running!"
  exit 1
fi

echo "Creating backup..."
docker exec -t "$CONTAINER_NAME" \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$FILE"

FILE_SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null)
if [ "$FILE_SIZE" -lt 100 ]; then
  echo "Warning: Backup file seems too small ($FILE_SIZE bytes). Check for errors."
  exit 1
fi

echo "✓ Backup saved to $FILE"
echo "  Size: $(du -h "$FILE" | cut -f1)"

# Опционально: удаление старых бэкапов (старше 30 дней)
#find "$BACKUP_DIR" -name "newsdb_*.sql" -mtime +30 -delete 2>/dev/null || true
#echo "✓ Old backups cleaned up (>30 days)"