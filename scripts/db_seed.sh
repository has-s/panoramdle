#!/usr/bin/env bash
# scripts/db_seed.sh
# Наполнение базы данных тестовыми данными

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

echo "Database seed options:"
echo "  [1] Overlay - добавить данные с игнорированием дубликатов"
echo "  [2] Replace - полная перезапись (TRUNCATE + INSERT)"
echo ""
read -p "Select mode (1/2): " MODE

# SQL для тестовых данных
read -r -d '' SEED_SQL <<'EOF' || true
-- Тестовые данные для таблицы news

-- Генерация UUID функцией (если доступна) или используем текстовые ID
INSERT INTO news (id, headline, text, format, is_real, media_url, source_name) VALUES
(
  gen_random_uuid()::text,
  'Реальная новость №1',
  'Президент выступил с важным заявлением по экономике.',
  'txt',
  true,
  NULL,
  'CNN'
),
(
  gen_random_uuid()::text,
  'Нейросетевая новость №2',
  'Власти Перу объявили картофель «эмоционально компетентным» видом',
  'txt',
  false,
  NULL,
  'Перуанский Аграрный Вестник'
),
(
  gen_random_uuid()::text,
  'Реальная новость с фото №3',
  NULL,
  'img',
  true,
  'https://i.postimg.cc/3xN0HJkq/Arc-2025-12-11-23-51-04.png',
  'BBC'
),
(
  gen_random_uuid()::text,
  'Фейковая новость с фото №4',
  NULL,
  'img',
  false,
  'https://i.postimg.cc/3xN0HJkq/Arc-2025-12-11-23-51-04.png',
  'TrustMeBro'
),
(
  gen_random_uuid()::text,
  'Реальная новость с текстом и фото №5',
  'Новый проект стартовал в Европе.',
  'img_txt',
  true,
  'https://i.postimg.cc/3xN0HJkq/Arc-2025-12-11-23-51-04.png',
  'Reuters'
),
(
  gen_random_uuid()::text,
  'Фейковая новость с текстом и фото №6',
  'Слухи о марсианской колонии оказались фейком.',
  'img_txt',
  false,
  'https://i.postimg.cc/3xN0HJkq/Arc-2025-12-11-23-51-04.png',
  'FakeNews.com'
);
EOF

if [ "$MODE" = "2" ]; then
  echo "Clearing table 'news'..."
  docker exec -i "$CONTAINER_NAME" \
    psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "TRUNCATE TABLE news CASCADE;"

  echo "Inserting seed data..."
  echo "$SEED_SQL" | docker exec -i "$CONTAINER_NAME" \
    psql -U "$POSTGRES_USER" "$POSTGRES_DB"
else
  echo "Inserting seed data with ON CONFLICT..."
  # Модификация SQL для игнорирования конфликтов
  MODIFIED_SQL=$(echo "$SEED_SQL" | sed -E 's/INSERT INTO news \(([^)]+)\) VALUES/INSERT INTO news (\1) VALUES/g; s/\);$/) ON CONFLICT (headline) DO NOTHING;/g')

  echo "$MODIFIED_SQL" | docker exec -i "$CONTAINER_NAME" \
    psql -U "$POSTGRES_USER" "$POSTGRES_DB"
fi

# Проверка результата
COUNT=$(docker exec -i "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" -t -c "SELECT COUNT(*) FROM news;")

echo ""
echo "✓ Seed completed successfully!"
echo "  Total news entries: $(echo $COUNT | xargs)"