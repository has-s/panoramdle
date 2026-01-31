#!/usr/bin/env bash
# scripts/db_restore.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
BACKUP_DIR="$PROJECT_ROOT/backups"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Error: Backups directory not found: $BACKUP_DIR"
  exit 1
fi

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
  echo "=== Available Backups ==="
  echo ""

  BACKUPS=($(ls -1t "$BACKUP_DIR"/newsdb_*.sql 2>/dev/null))

  if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo "No backups found in $BACKUP_DIR"
    exit 1
  fi

  for i in "${!BACKUPS[@]}"; do
    BACKUP_NAME=$(basename "${BACKUPS[$i]}")
    BACKUP_SIZE=$(du -h "${BACKUPS[$i]}" | cut -f1)
    BACKUP_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "${BACKUPS[$i]}" 2>/dev/null || stat -c "%y" "${BACKUPS[$i]}" 2>/dev/null | cut -d'.' -f1)
    echo "  [$((i+1))] $BACKUP_NAME"
    echo "      Size: $BACKUP_SIZE, Created: $BACKUP_DATE"
  done

  echo ""
  read -p "Select backup number (1-${#BACKUPS[@]}): " BACKUP_NUM

  if ! [[ "$BACKUP_NUM" =~ ^[0-9]+$ ]] || [ "$BACKUP_NUM" -lt 1 ] || [ "$BACKUP_NUM" -gt ${#BACKUPS[@]} ]; then
    echo "Invalid selection"
    exit 1
  fi

  BACKUP_FILE="${BACKUPS[$((BACKUP_NUM-1))]}"
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file '$BACKUP_FILE' not found!"
  exit 1
fi

MODE="${2}"

if [ -z "$MODE" ]; then
  echo ""
  echo "Select restore mode:"
  echo "  [1] Overlay - add data (ignore duplicates)"
  echo "  [2] Replace - full replace (delete all old data)"
  echo ""
  read -p "Enter mode (1/2): " MODE_INPUT

  case "$MODE_INPUT" in
    1)
      MODE="overlay"
      ;;
    2)
      MODE="replace"
      ;;
    *)
      echo "Invalid mode. Using 'overlay' by default."
      MODE="overlay"
      ;;
  esac
fi

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

echo ""
echo "Restore settings:"
echo "  File: $(basename "$BACKUP_FILE")"
echo "  Mode: $MODE"
echo ""
echo "⚠️  WARNING: This will modify your database!"
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "Step 1: Applying migrations..."
if [ -f "$SCRIPT_DIR/db_migrate.sh" ]; then
  "$SCRIPT_DIR/db_migrate.sh"
  echo "✓ Migrations applied"
else
  echo "Warning: db_migrate.sh not found, skipping migrations"
fi

echo ""
echo "Step 2: Restoring data..."

TMP_FILE=$(mktemp)

if [ "$MODE" = "replace" ]; then
  echo "Mode: Full replace (TRUNCATE + INSERT)"

  echo "Truncating tables..."
  docker exec -i "$CONTAINER_NAME" \
    psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "TRUNCATE TABLE news CASCADE;"

  cat "$BACKUP_FILE" > "$TMP_FILE"

else
  echo "Mode: Overlay (ON CONFLICT DO NOTHING)"

  sed -E 's/INSERT INTO news \(([^)]+)\) VALUES \(([^)]+)\);/INSERT INTO news (\1) VALUES (\2) ON CONFLICT (id) DO NOTHING;/' "$BACKUP_FILE" > "$TMP_FILE"
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