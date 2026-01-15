#!/usr/bin/env bash
# scripts/db_clean.sh
# Очистка базы данных

set -e

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

# Подсчет текущего количества записей
COUNT=$(docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -t -c "SELECT COUNT(*) FROM news;")

echo "⚠️  WARNING: This will delete all data from the 'news' table!"
echo "Current entries: $(echo $COUNT | xargs)"
echo ""
read -p "Are you sure? Type 'yes' to continue: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

echo "Truncating table 'news'..."
docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "TRUNCATE TABLE news CASCADE;"

echo ""
echo "✓ Table 'news' has been cleared!"
echo ""
echo "To populate with test data, run:"
echo "  ./scripts/db_seed.sh"