#!/usr/bin/env bash
# scripts/create_admin.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Creating Administrator ===${NC}"
echo ""

APP_ENV=${APP_ENV:-docker}
if [ "$APP_ENV" = "docker" ]; then
  ENV_FILE="$PROJECT_ROOT/.env.docker"
  CONTAINER_NAME="panoramdle_db"
else
  ENV_FILE="$PROJECT_ROOT/.env.local"
  CONTAINER_NAME="panoramdle_db"
fi

if [ ! -f "$ENV_FILE" ]; then
  echo -e "${RED}Error: $ENV_FILE not found!${NC}"
  exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

if ! docker ps | grep -q "$CONTAINER_NAME"; then
  echo -e "${RED}Error: Container '$CONTAINER_NAME' is not running!${NC}"
  exit 1
fi

USE_ENV_VARS=${USE_ENV_VARS:-false}

if [ "$USE_ENV_VARS" = "true" ]; then
  echo -e "${YELLOW}Using credentials from environment variables${NC}"

  USERNAME="${ADMIN_USERNAME:-admin}"
  PASSWORD="${ADMIN_PASSWORD}"
  EMAIL="${ADMIN_EMAIL}"

  if [ -z "$PASSWORD" ]; then
    echo -e "${RED}Error: ADMIN_PASSWORD not set in $ENV_FILE${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}Enter administrator credentials:${NC}"
  echo ""

  read -p "Username: " USERNAME
  if [ -z "$USERNAME" ]; then
    echo -e "${RED}Username cannot be empty${NC}"
    exit 1
  fi

  read -s -p "Password: " PASSWORD
  echo ""
  if [ -z "$PASSWORD" ]; then
    echo -e "${RED}Password cannot be empty${NC}"
    exit 1
  fi

  read -s -p "Repeat password: " PASSWORD_CONFIRM
  echo ""
  if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Passwords do not match${NC}"
    exit 1
  fi

  read -p "Email (optional): " EMAIL
fi

echo ""
echo -e "${YELLOW}Checking if admin already exists...${NC}"

ADMIN_EXISTS=$(docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" "$POSTGRES_DB" -t -c \
  "SELECT COUNT(*) FROM moderators WHERE username = '$USERNAME' AND role = 'admin';" 2>/dev/null | xargs || echo "0")

if [ "$ADMIN_EXISTS" != "0" ]; then
  echo -e "${YELLOW}Admin '$USERNAME' already exists, skipping creation${NC}"
  exit 0
fi

echo -e "${YELLOW}Creating administrator...${NC}"

PASSWORD_HASH=$(python3 << PYTHON_SCRIPT
import bcrypt
password = "${PASSWORD}"
salt = bcrypt.gensalt(rounds=12)
password_hash = bcrypt.hashpw(password.encode('utf-8'), salt)
print(password_hash.decode('utf-8'))
PYTHON_SCRIPT
)

read -r -d '' SQL <<EOF || true
INSERT INTO moderators (username, password_hash, email, role, is_active)
VALUES ('$USERNAME', '$PASSWORD_HASH', $([ -n "$EMAIL" ] && echo "'$EMAIL'" || echo "NULL"), 'admin', true);
EOF

if echo "$SQL" | docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" "$POSTGRES_DB" > /dev/null 2>&1; then
    echo ""
    echo -e "${GREEN}✓ Administrator created successfully!${NC}"
    echo ""
    echo "Login credentials:"
    echo "  Username: $USERNAME"
    echo "  Email: ${EMAIL:-<not specified>}"
    echo "  Role: admin"
    echo ""
else
    echo ""
    echo -e "${RED}✗ Error creating administrator${NC}"
    echo ""
    echo "Possible reasons:"
    echo "  - User with this username already exists"
    echo "  - Table 'moderators' not created (run migrations)"
    echo ""
    exit 1
fi