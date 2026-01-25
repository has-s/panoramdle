#!/usr/bin/env bash
# scripts/db_init.sh

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

if ! docker ps | grep -q "$CONTAINER_NAME"; then
  echo "Error: Container '$CONTAINER_NAME' is not running!"
  exit 1
fi

echo "Initializing database schema..."

read -r -d '' INIT_SQL <<'EOF' || true
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS news (
    id TEXT PRIMARY KEY,
    headline TEXT NOT NULL,
    text TEXT,
    format VARCHAR(10) NOT NULL,
    is_real BOOLEAN NOT NULL,
    media_url TEXT,
    source_name TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_news_headline ON news(headline);

CREATE INDEX IF NOT EXISTS idx_news_is_real ON news(is_real);
EOF

echo "$INIT_SQL" | docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB"

echo ""
echo "✓ Database initialized successfully!"
echo ""
echo "Available tables:"
docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "\dt"