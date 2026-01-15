#!/usr/bin/env bash
# scripts/db_restore.sh
# Восстановление базы данных из бэкапа

set -e

# Проверка аргументов
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

# Проверка существования файла
if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file '$BACKUP_FILE' not found!"
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# Определение окружения
APP_ENV=${APP_ENV:-docker}
if [ "$APP_ENV" = "docker" ]; then
  ENV_FILE="$PROJECT_ROOT/.env.docker"
  CONTAINER_NAME="db"
else
  ENV_FILE="$PROJECT_ROOT/.env.local"
  CONTAINER_NAME="db"
fi

# Загрузка переменных окружения
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE not found!"
  exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

# Проверка, что контейнер запущен
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

  # Очистка таблицы
  echo "Truncating table 'news'..."
  docker exec -i "$CONTAINER_NAME" \
    psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "TRUNCATE TABLE news CASCADE;"

  # Восстановление без модификаций
  cat "$BACKUP_FILE" > "$TMP_FILE"

else
  echo "Mode: Overlay (ON CONFLICT DO NOTHING)"

  # Модификация INSERT для игнорирования конфликтов по headline
  sed -E 's/INSERT INTO news \(([^)]+)\) VALUES \(([^)]+)\);/INSERT INTO news (\1) VALUES (\2) ON CONFLICT (headline) DO NOTHING;/' "$BACKUP_FILE" > "$TMP_FILE"
fi

# Восстановление
echo "Restoring database..."
docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" < "$TMP_FILE"

# Очистка временного файла
rm "$TMP_FILE"

# Проверка количества записей
COUNT=$(docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -t -c "SELECT COUNT(*) FROM news;")

echo ""
echo "✓ Database restored successfully!"
echo "  Total news entries: $(echo $COUNT | xargs)"