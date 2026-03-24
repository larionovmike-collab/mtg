# mtg installer

Простой скрипт для быстрой установки и управления MTProto прокси (**mtg v2**) на вашем сервере Ubuntu/Debian.

## 🚀 Быстрая установка

Запустите команду ниже, чтобы установить прокси. Скрипт предложит выбрать версию, порт и автоматически сгенерирует секрет и системный сервис.

```sh
bash <(curl -sSL https://raw.githubusercontent.com/larionovmike-collab/mtg/refs/heads/main/install.sh)
```
🗑️ Удаление

Если вы хотите полностью удалить mtg и его конфигурацию с сервера, выполните:
```sh
bash <(curl -sSL https://raw.githubusercontent.com/larionovmike-collab/mtg/refs/heads/main/install.sh) --uninstall
```
