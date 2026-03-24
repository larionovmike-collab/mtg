#!/bin/bash

# Цвета для терминала
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/mtg"
SERVICE_FILE="/etc/systemd/system/mtg.service"

# Функция удаления
uninstall_mtg() {
    echo -e "${RED}--- Удаление mtg ---${NC}"
    
    if [ -f "$SERVICE_FILE" ]; then
        echo "Остановка и отключение сервиса..."
        sudo systemctl stop mtg
        sudo systemctl disable mtg
        sudo rm "$SERVICE_FILE"
        sudo systemctl daemon-reload
        sudo systemctl reset-failed
        echo "Сервис удален."
    else
        echo "Файл сервиса не найден, пропускаю..."
    fi

    if [ -d "$INSTALL_DIR" ]; then
        echo "Удаление файлов из $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
        echo "Директория удалена."
    else
        echo "Папка с программой не найдена."
    fi

    echo -e "${GREEN}Удаление успешно завершено!${NC}"
}

# Проверка аргумента на удаление
if [ "$1" == "--uninstall" ]; then
    uninstall_mtg
    exit 0
fi

# --- ДАЛЕЕ ИДЕТ БЛОК УСТАНОВКИ (выполняется, если нет флага --uninstall) ---

echo -e "${CYAN}--- Настройка установки mtg ---${NC}"
echo -e "${GREEN}https://github.com/9seconds/mtg/releases${NC}"

# 1. Выбор версии
read -p "Введите версию mtg (по умолчанию 2.2.3): " VERSION
VERSION=${VERSION:-2.2.3}

# 2. Параметры порта
read -p "Введите порт для прокси (по умолчанию 8443): " PORT
PORT=${PORT:-8443}

echo -e "\n${GREEN}Начинаю установку mtg v$VERSION...${NC}"

# 3. Подготовка папки
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit

# 4. Скачивание и распаковка
FILENAME="mtg-$VERSION-linux-amd64.tar.gz"
URL="https://github.com/9seconds/mtg/releases/download/v$VERSION/$FILENAME"

if wget -q --show-progress "$URL"; then
    tar -xf "$FILENAME"
    find . -name "mtg" -type f -exec mv {} . \;
    chmod +x mtg
    rm -rf "$FILENAME" mtg-"$VERSION"-linux-amd64
else
    echo -e "${RED}Ошибка: Не удалось скачать версию $VERSION.${NC}"
    exit 1
fi

# 5. Генерация секрета
SECRET=$(./mtg generate-secret --hex google.com)

# 6. Создание systemd сервиса
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

# 7. Запуск
sudo systemctl daemon-reload
sudo systemctl enable mtg
sudo systemctl start mtg

# 8. Вывод данных
IP=$(curl -s https://ifconfig.me)
echo -e "\n${GREEN}============================================"
echo -e "Установка mtg v$VERSION завершена!"
echo -e "Ссылка: tg://proxy?server=$IP&port=$PORT&secret=$SECRET"
echo -e "============================================${NC}"
echo -e "Для удаления выполните этот же скрипт с флагом: --uninstall"
