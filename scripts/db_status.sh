#!/usr/bin/env bash
# scripts/db_status.sh
# Проверка состояния базы данных

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
  echo "❌ Container '$CONTAINER_NAME' is not running!"
  exit 1
fi

echo "================================"
echo "Database Status"
echo "================================"
echo ""
echo "Environment: $APP_ENV"
echo "Container: $CONTAINER_NAME"
echo "Database: $POSTGRES_DB"
echo ""

# Проверка подключения
echo "Connection: "
if docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "SELECT 1;" > /dev/null 2>&1; then
  echo "  ✓ Connected"
else
  echo "  ❌ Connection failed!"
  exit 1
fi

echo ""
echo "================================"
echo "Tables"
echo "================================"
docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "\dt"

echo ""
echo "================================"
echo "News Statistics"
echo "================================"

# Общее количество записей
TOTAL=$(docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -t -c "SELECT COUNT(*) FROM news;")
echo "Total entries: $(echo $TOTAL | xargs)"

# Количество реальных новостей
REAL=$(docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -t -c "SELECT COUNT(*) FROM news WHERE is_real = true;")
echo "Real news: $(echo $REAL | xargs)"

# Количество фейковых новостей
FAKE=$(docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -t -c "SELECT COUNT(*) FROM news WHERE is_real = false;")
echo "Fake news: $(echo $FAKE | xargs)"

echo ""
echo "By format:"
docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "SELECT format, COUNT(*) as count FROM news GROUP BY format ORDER BY count DESC;"

echo ""
echo "Recent entries:"
docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "SELECT id, headline, format, is_real FROM news LIMIT 5;"

echo ""
echo "================================"
echo "Database Size"
echo "================================"
docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "SELECT pg_size_pretty(pg_database_size('$POSTGRES_DB')) as size;"