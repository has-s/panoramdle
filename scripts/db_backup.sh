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
docker exec "$CONTAINER_NAME" \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$FILE"

FILE_SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null)
if [ "$FILE_SIZE" -lt 100 ]; then
  echo "Warning: Backup file seems too small ($FILE_SIZE bytes). Check for errors."
  exit 1
fi

echo "✓ Backup saved: $FILE"
echo "  Size: $(du -h "$FILE" | cut -f1)"

echo ""
echo "Cleaning up old backups..."

CURRENT_TIME=$(date +%s)
THIRTY_DAYS_AGO=$((CURRENT_TIME - 30*24*60*60))

RECENT_BACKUPS=()
OLD_BACKUPS=()

for backup in $(ls -1t "$BACKUP_DIR"/newsdb_*.sql 2>/dev/null); do
  BACKUP_TIME=$(stat -f %m "$backup" 2>/dev/null || stat -c %Y "$backup" 2>/dev/null)

  if [ "$BACKUP_TIME" -gt "$THIRTY_DAYS_AGO" ]; then
    RECENT_BACKUPS+=("$backup")
  else
    OLD_BACKUPS+=("$backup")
  fi
done

RECENT_COUNT=${#RECENT_BACKUPS[@]}
OLD_COUNT=${#OLD_BACKUPS[@]}

echo "  Recent backups (<30 days): $RECENT_COUNT"
echo "  Old backups (>30 days): $OLD_COUNT"

if [ $OLD_COUNT -gt 0 ]; then
  if [ $RECENT_COUNT -eq 0 ]; then
    echo "  All backups are old, keeping last 5"

    if [ $OLD_COUNT -gt 5 ]; then
      SORTED_OLD=($(printf '%s\n' "${OLD_BACKUPS[@]}" | sort -r))

      for i in "${!SORTED_OLD[@]}"; do
        if [ $i -ge 5 ]; then
          rm -f "${SORTED_OLD[$i]}"
          echo "  Deleted: $(basename "${SORTED_OLD[$i]}")"
        fi
      done
      echo "✓ Removed $((OLD_COUNT - 5)) old backup(s)"
    else
      echo "✓ Keeping all $OLD_COUNT old backups (less than 5)"
    fi
  else
    echo "  Deleting all old backups (recent backups exist)"

    for backup in "${OLD_BACKUPS[@]}"; do
      rm -f "$backup"
      echo "  Deleted: $(basename "$backup")"
    done
    echo "✓ Removed $OLD_COUNT old backup(s)"
  fi
else
  echo "✓ No old backups to clean"
fi