#!/bin/bash

# Цвета для терминала
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}--- Настройка установки mtg ---${NC}"

# 1. Выбор версии
read -p "Введите версию mtg (по умолчанию 2.2.1): " VERSION
VERSION=${VERSION:-2.2.1}

# 2. Параметры порта
read -p "Введите порт для прокси (по умолчанию 8443): " PORT
PORT=${PORT:-8443}

echo -e "\n${GREEN}Начинаю установку mtg v$VERSION на порт $PORT...${NC}"

# 3. Подготовка папки
INSTALL_DIR="$HOME/mtg"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit

# 4. Скачивание и распаковка
FILENAME="mtg-$VERSION-linux-amd64.tar.gz"
URL="https://github.com/9seconds/mtg/releases/download/v$VERSION/$FILENAME"

echo "Загрузка: $URL"
if wget -q --show-progress "$URL"; then
    tar -xf "$FILENAME"
    # Пытаемся найти бинарник (в разных версиях структура папок может чуть меняться)
    find . -name "mtg" -type f -exec mv {} . \;
    chmod +x mtg
    rm -rf "$FILENAME" mtg-"$VERSION"-linux-amd64
else
    echo "Ошибка: Не удалось скачать версию $VERSION. Проверьте номер версии на GitHub."
    exit 1
fi

# 5. Генерация секрета
SECRET=$(./mtg generate-secret --hex google.com)

# 6. Создание systemd сервиса
echo "Настройка системного сервиса..."
sudo bash -c "cat <<EOM > /etc/systemd/system/mtg.service
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

# 8. Получение внешнего IP и вывод данных
IP=$(curl -s https://ifconfig.me)

echo -e "\n${GREEN}============================================"
echo -e "Установка mtg v$VERSION успешно завершена!"
echo -e "============================================${NC}"
echo -e "Порт: ${CYAN}$PORT${NC}"
echo -e "Секрет: ${CYAN}$SECRET${NC}"
echo -e "Ссылка для Telegram:"
echo -e "${GREEN}tg://proxy?server=$IP&port=$PORT&secret=$SECRET${NC}"
echo -e "============================================"
echo "Команда для проверки логов: journalctl -u mtg -f"
