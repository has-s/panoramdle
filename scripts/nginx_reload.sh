#!/usr/bin/env bash
# scripts/nginx_reload.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

NGINX_CONFIG="/etc/nginx/sites-available/panoramdle.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/panoramdle.conf"

case "${1:-reload}" in
    install)
        echo -e "${YELLOW}Installing Nginx configuration...${NC}"

        # Загружаем переменные из .env.docker
        if [ -f ".env.docker" ]; then
            set -a
            source .env.docker
            set +a
        else
            echo -e "${RED}Error: .env.docker not found!${NC}"
            exit 1
        fi

        # Устанавливаем значения по умолчанию если не заданы
        DOMAIN=${DOMAIN:-_}
        BACKEND_PORT=${BACKEND_PORT:-8000}
        PROJECT_PATH=${PROJECT_PATH:-$(pwd)}  # Текущая директория по умолчанию

        # Генерируем конфиг из template
        if [ -f "nginx/panoramdle.conf.template" ]; then
            echo "Generating config from template..."
            sed -e "s|DOMAIN_NAME|$DOMAIN|g" \
                -e "s|BACKEND_PORT|$BACKEND_PORT|g" \
                -e "s|PROJECT_PATH|$PROJECT_PATH|g" \
                nginx/panoramdle.conf.template > nginx/panoramdle.conf
            echo -e "${GREEN}✓ Config generated${NC}"
        elif [ ! -f "nginx/panoramdle.conf" ]; then
            echo -e "${RED}Error: Neither nginx/panoramdle.conf.template nor nginx/panoramdle.conf found!${NC}"
            exit 1
        fi

        # Копируем конфиг
        if [ -f "nginx/panoramdle.conf" ]; then
            sudo cp nginx/panoramdle.conf $NGINX_CONFIG
            echo -e "${GREEN}✓ Configuration copied${NC}"
        else
            echo -e "${RED}Error: nginx/panoramdle.conf not found!${NC}"
            exit 1
        fi

        # Создаем symlink
        if [ ! -L "$NGINX_ENABLED" ]; then
            sudo ln -s $NGINX_CONFIG $NGINX_ENABLED
            echo -e "${GREEN}✓ Configuration enabled${NC}"
        fi

        # Тестируем
        if sudo nginx -t; then
            echo -e "${GREEN}✓ Configuration is valid${NC}"
            sudo systemctl reload nginx
            echo -e "${GREEN}✓ Nginx reloaded${NC}"
        else
            echo -e "${RED}✗ Configuration test failed!${NC}"
            exit 1
        fi
        ;;

    test)
        echo -e "${YELLOW}Testing Nginx configuration...${NC}"
        if sudo nginx -t; then
            echo -e "${GREEN}✓ Configuration is valid${NC}"
        else
            echo -e "${RED}✗ Configuration test failed!${NC}"
            exit 1
        fi
        ;;

    reload)
        echo -e "${YELLOW}Testing Nginx configuration...${NC}"
        if sudo nginx -t 2>&1 | grep -q "successful"; then
            echo -e "${GREEN}✓ Configuration is valid${NC}"
            echo ""
            echo -e "${YELLOW}Reloading Nginx...${NC}"
            sudo systemctl reload nginx
            echo -e "${GREEN}✓ Nginx reloaded successfully!${NC}"
        else
            echo -e "${RED}✗ Configuration test failed!${NC}"
            sudo nginx -t
            exit 1
        fi
        ;;

    restart)
        echo -e "${YELLOW}Restarting Nginx...${NC}"
        sudo systemctl restart nginx
        echo -e "${GREEN}✓ Nginx restarted${NC}"
        ;;

    status)
        sudo systemctl status nginx
        ;;

    logs)
        echo -e "${GREEN}=== Access Logs ===${NC}"
        sudo tail -n 50 /var/log/nginx/panoramdle_access.log 2>/dev/null || echo "No access logs yet"
        echo ""
        echo -e "${GREEN}=== Error Logs ===${NC}"
        sudo tail -n 50 /var/log/nginx/panoramdle_error.log 2>/dev/null || echo "No error logs yet"
        ;;

    disable)
        echo -e "${YELLOW}Disabling site...${NC}"
        sudo rm -f $NGINX_ENABLED
        sudo systemctl reload nginx
        echo -e "${GREEN}✓ Site disabled${NC}"
        ;;

    *)
        echo "Usage: $0 {install|test|reload|restart|status|logs|disable}"
        echo ""
        echo "Commands:"
        echo "  install  - Install Nginx configuration"
        echo "  test     - Test Nginx configuration"
        echo "  reload   - Reload Nginx (default)"
        echo "  restart  - Restart Nginx"
        echo "  status   - Show Nginx status"
        echo "  logs     - Show recent logs"
        echo "  disable  - Disable this site"
        exit 1
        ;;
esac