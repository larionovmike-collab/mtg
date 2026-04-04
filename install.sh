#!/bin/bash

set -euo pipefail

# Цвета для терминала
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/mtg"
SERVICE_FILE="/etc/systemd/system/mtg.service"
REPO="9seconds/mtg"

# Функция логирования
log() {
    echo -e "${2:-$CYAN}[mtg]${NC} $1"
}

# Функция получения последней версии с GitHub
get_latest_version() {
    local version
    version=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
    if [[ -z "$version" ]]; then
        echo "2.2.6" # Запасной вариант, если API недоступно
    else
        echo "$version"
    fi
}

# Функция удаления
uninstall_mtg() {
    log "--- Удаление mtg ---" "$RED"
    
    if [ -f "$SERVICE_FILE" ]; then
        log "Остановка и отключение сервиса..."
        sudo systemctl stop mtg 2>/dev/null || true
        sudo systemctl disable mtg 2>/dev/null || true
        sudo rm "$SERVICE_FILE"
        sudo systemctl daemon-reload
        log "Сервис удален." "$GREEN"
    fi

    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        log "Директория $INSTALL_DIR удалена." "$GREEN"
    fi
}

# Проверка зависимостей
check_dependencies() {
    local deps=("wget" "curl" "sudo" "systemctl" "awk" "grep" "sed")
    local missing=()
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then missing+=("$cmd"); fi
    done
    if [ ${#missing[@]} -ne 0 ]; then
        log "Отсутствуют зависимости: ${missing[*]}" "$RED"
        exit 1
    fi
}

# Скачивание и установка бинарника
download_and_install_binary() {
    local version=$1
    log "Подготовка к загрузке v$version..." "$GREEN"
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    local filename="mtg-$version-linux-amd64.tar.gz"
    local url="https://github.com/$REPO/releases/download/v$version/$filename"

    if wget -q --show-progress "$url"; then
        tar -xf "$filename"
        find . -name "mtg" -type f -exec mv {} . \;
        chmod +x mtg
        rm -rf "$filename" "mtg-$version-linux-amd64"
    else
        log "Ошибка: версия $version не найдена" "$RED"
        exit 1
    fi
}

# Создание/перезапуск сервиса
create_service() {
    local port=$1 secret=$2 version=$3
    log "Конфигурация systemd для v$version..."

    sudo bash -c "cat <<EOM > $SERVICE_FILE
[Unit]
Description=mtg v2 - MTProto proxy
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/mtg simple-run 0.0.0.0:$port $secret
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOM"

    sudo systemctl daemon-reload
    sudo systemctl enable mtg
    sudo systemctl restart mtg
}

# --- ОСНОВНАЯ ЛОГИКА ---

check_dependencies

# Флаг удаления
if [ "${1:-}" == "--uninstall" ]; then
    uninstall_mtg
    exit 0
fi

# Получаем свежую версию один раз для всех сценариев
LATEST_VER=$(get_latest_version)

# Флаг обновления
if [ "${1:-}" == "--update" ]; then
    if [ ! -f "$SERVICE_FILE" ]; then
        log "Ошибка: mtg не найден. Сначала установите его." "$RED"
        exit 1
    fi

    log "--- Режим обновления ---" "$YELLOW"
    
    # Извлечение текущих настроек
    CURRENT_EXEC=$(grep "ExecStart=" "$SERVICE_FILE")
    OLD_PORT=$(echo "$CURRENT_EXEC" | awk '{print $3}' | cut -d':' -f2)
    OLD_SECRET=$(echo "$CURRENT_EXEC" | awk '{print $4}')

    echo -e "Актуальная версия на GitHub: ${GREEN}$LATEST_VER${NC}"
    read -p "Введите версию для обновления (Enter для $LATEST_VER): " VERSION
    VERSION=${VERSION:-$LATEST_VER}

    download_and_install_binary "$VERSION"
    create_service "$OLD_PORT" "$OLD_SECRET" "$VERSION"
    log "Обновление до v$VERSION успешно завершено!" "$GREEN"
    exit 0
fi

# Обычная установка
if [ -f "$SERVICE_FILE" ]; then
    log "mtg уже установлен. Используйте --update" "$YELLOW"
    exit 1
fi

log "--- Установка mtg ---"
echo -e "Последняя доступная версия: ${GREEN}$LATEST_VER${NC}"
read -p "Какую версию ставим? (Enter для $LATEST_VER): " VERSION
VERSION=${VERSION:-$LATEST_VER}

read -p "Порт (по умолчанию 8443): " PORT
PORT=${PORT:-8443}

read -p "Hostname для секрета (по умолчанию google.com): " HOSTNAME
HOSTNAME=${HOSTNAME:-google.com}

download_and_install_binary "$VERSION"

log "Генерация секрета..."
SECRET=$($INSTALL_DIR/mtg generate-secret --hex "$HOSTNAME")

create_service "$PORT" "$SECRET" "$VERSION"

IP=$(curl -s -4 https://ifconfig.me || curl -s https://ifconfig.me)
echo -e "\n${GREEN}============================================"
echo -e "Готово! Ссылка для Telegram:"
echo -e "tg://proxy?server=$IP&port=$PORT&secret=$SECRET"
echo -e "============================================${NC}"
