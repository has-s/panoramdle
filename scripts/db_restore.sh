#!/usr/bin/env bash
# scripts/db_restore.sh

set -e

if [ -z "$1" ]; then
  echo "Usage: ./db_restore.sh <backup_file.sql> [mode]"
  echo ""
  echo "Modes:"
  echo "  overlay  - добавить данные с игнорированием конфликтов (по умолчанию)"
  echo "  replace  - полная замена (TRUNCATE + INSERT)"
  echo ""
  echo "Example:"
  echo "  ./db_restore.sh backups/newsdb_2025-01-13.sql overlay"
  exit 1
fi

BACKUP_FILE="$1"
MODE="${2:-overlay}"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file '$BACKUP_FILE' not found!"
  exit 1
fi

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

if ! docker ps | grep -q "$CONTAINER_NAME"; then
  echo "Error: Container '$CONTAINER_NAME' is not running!"
  exit 1
fi

echo "Restore mode: $MODE"
echo "Backup file: $BACKUP_FILE"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

TMP_FILE=$(mktemp)

if [ "$MODE" = "replace" ]; then
  echo "Mode: Full replace (TRUNCATE + INSERT)"

  echo "Truncating table 'news'..."
  docker exec -i "$CONTAINER_NAME" \
    psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "TRUNCATE TABLE news CASCADE;"

  cat "$BACKUP_FILE" > "$TMP_FILE"

else
  echo "Mode: Overlay (ON CONFLICT DO NOTHING)"

  sed -E 's/INSERT INTO news \(([^)]+)\) VALUES \(([^)]+)\);/INSERT INTO news (\1) VALUES (\2) ON CONFLICT (headline) DO NOTHING;/' "$BACKUP_FILE" > "$TMP_FILE"
fi

echo "Restoring database..."
docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" < "$TMP_FILE"

rm "$TMP_FILE"

COUNT=$(docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -t -c "SELECT COUNT(*) FROM news;")

echo ""
echo "✓ Database restored successfully!"
echo "  Total news entries: $(echo $COUNT | xargs)"