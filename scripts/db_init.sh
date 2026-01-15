#!/usr/bin/env bash
# scripts/db_init.sh
# Инициализация базы данных (создание таблиц)

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

echo "Initializing database schema..."

# SQL для создания таблиц
read -r -d '' INIT_SQL <<'EOF' || true
-- Создание расширения для UUID (если еще не создано)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Создание таблицы news
CREATE TABLE IF NOT EXISTS news (
    id TEXT PRIMARY KEY,
    headline TEXT NOT NULL,
    text TEXT,
    format VARCHAR(10) NOT NULL,
    is_real BOOLEAN NOT NULL,
    media_url TEXT,
    source_name TEXT
);

-- Создание индекса для уникальности заголовков (для ON CONFLICT)
CREATE UNIQUE INDEX IF NOT EXISTS idx_news_headline ON news(headline);

-- Создание индекса для быстрой фильтрации
CREATE INDEX IF NOT EXISTS idx_news_is_real ON news(is_real);
EOF

# Выполнение SQL
echo "$INIT_SQL" | docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB"

echo ""
echo "✓ Database initialized successfully!"
echo ""
echo "Available tables:"
docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "\dt"

echo ""
echo "Next steps:"
echo "  Run: ./scripts/db_seed.sh - to populate with test data"