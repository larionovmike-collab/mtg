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

# Функция логирования
log() {
    echo -e "${2:-$CYAN}[mtg]${NC} $1"
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
        sudo systemctl reset-failed
        log "Сервис удален." "$GREEN"
    fi

    if [ -d "$INSTALL_DIR" ]; then
        log "Удаление файлов из $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
        log "Директория удалена." "$GREEN"
    fi

    log "Удаление успешно завершено!" "$GREEN"
}

# Проверка зависимостей
check_dependencies() {
    local deps=("wget" "curl" "sudo" "systemctl")
    local missing=()
    
    for cmd in "${deps[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log "Отсутствуют зависимости: ${missing[*]}" "$RED"
        log "Установите их и повторите запуск" "$YELLOW"
        exit 1
    fi
}

# Проверка существующей установки
check_existing_installation() {
    if [ -f "$SERVICE_FILE" ]; then
        log "mtg уже установлен. Используйте --uninstall для удаления" "$RED"
        exit 1
    fi
}

# Проверка доступности версии
check_version_availability() {
    local url="https://github.com/9seconds/mtg/releases/download/v$1/mtg-$1-linux-amd64.tar.gz"
    if ! wget --spider -q "$url" 2>/dev/null; then
        log "Версия $1 не найдена на GitHub" "$RED"
        log "Доступные версии: https://github.com/9seconds/mtg/releases" "$YELLOW"
        exit 1
    fi
}

# Проверка прав на порт
check_port_availability() {
    if sudo lsof -i :$1 &> /dev/null; then
        log "Порт $1 уже используется" "$RED"
        log "Используйте другой порт или освободите текущий" "$YELLOW"
        exit 1
    fi
}

# Аргументы командной строки
if [ "${1:-}" == "--uninstall" ]; then
    uninstall_mtg
    exit 0
fi

# Основная установка
check_dependencies
check_existing_installation

log "--- Настройка установки mtg ---"
log "https://github.com/9seconds/mtg/releases"

# Выбор версии
read -p "Введите версию mtg (по умолчанию 2.2.3): " VERSION
VERSION=${VERSION:-2.2.3}
check_version_availability "$VERSION"

# Параметры порта
read -p "Введите порт для прокси (по умолчанию 8443): " PORT
PORT=${PORT:-8443}
check_port_availability "$PORT"

log "Начинаю установку mtg v$VERSION..." "$GREEN"

# Подготовка папки
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || {
    log "Не удалось перейти в директорию $INSTALL_DIR" "$RED"
    exit 1
}

# Скачивание и распаковка
FILENAME="mtg-$VERSION-linux-amd64.tar.gz"
URL="https://github.com/9seconds/mtg/releases/download/v$VERSION/$FILENAME"

log "Скачивание $URL..."
if wget -q --show-progress "$URL"; then
    tar -xf "$FILENAME"
    find . -name "mtg" -type f -exec mv {} . \;
    chmod +x mtg
    rm -rf "$FILENAME" "mtg-$VERSION-linux-amd64"
else
    log "Не удалось скачать версию $VERSION" "$RED"
    exit 1
fi

# Генерация секрета
log "Генерация секрета..."
SECRET=$(./mtg generate-secret --hex google.com)
if [ -z "$SECRET" ]; then
    log "Не удалось сгенерировать секрет" "$RED"
    exit 1
fi

# Создание systemd сервиса
log "Создание systemd сервиса..."
sudo bash -c "cat <<EOM > $SERVICE_FILE
[Unit]
Description=mtg v2 - MTProto proxy
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/mtg simple-run 0.0.0.0:$PORT $SECRET
Restart=always
RestartSec=3
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=mtg

[Install]
WantedBy=multi-user.target
EOM"

# Запуск
sudo systemctl daemon-reload
sudo systemctl enable mtg
sudo systemctl start mtg

# Проверка статуса
sleep 2
if systemctl is-active --quiet mtg; then
    log "Сервис успешно запущен" "$GREEN"
else
    log "Ошибка: Сервис не запустился" "$RED"
    log "Проверьте журнал: sudo journalctl -u mtg -n 20" "$YELLOW"
    exit 1
fi

# Вывод данных
IP=$(curl -s -4 https://ifconfig.me)
if [ -z "$IP" ]; then
    IP=$(curl -s https://ifconfig.me)
fi

echo -e "\n${GREEN}============================================"
echo -e "Установка mtg v$VERSION завершена!"
echo -e "Ссылка: tg://proxy?server=$IP&port=$PORT&secret=$SECRET"
echo -e "============================================${NC}"
echo -e "Для проверки статуса: sudo systemctl status mtg"
echo -e "Для просмотра логов: sudo journalctl -u mtg -f"
echo -e "Для удаления: $0 --uninstall"
