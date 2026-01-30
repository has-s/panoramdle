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

BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/newsdb_*.sql 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 5 ]; then
  echo ""
  echo "Cleaning up old backups (keeping last 5)..."
  BACKUPS_TO_DELETE=$((BACKUP_COUNT - 5))
  ls -1t "$BACKUP_DIR"/newsdb_*.sql | tail -n +6 | xargs rm -f
  echo "✓ Removed $BACKUPS_TO_DELETE old backup(s)"
fi