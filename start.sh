# d:\Git\binance-bot\binance-telegram-bot-1\start.sh
#!/bin/bash
set -e

# Указываем путь к данным PostgreSQL
PGDATA="/var/lib/postgresql/14/main"

# Проверяем, была ли база данных уже инициализирована
if [ ! -d "$PGDATA/base" ]; then
    echo "Initializing PostgreSQL database..."

    # Инициализируем кластер БД
    /usr/lib/postgresql/14/bin/initdb -D $PGDATA

    # Запускаем PostgreSQL для настройки
    /usr/lib/postgresql/14/bin/postgres -D $PGDATA &
    pid="$!"
    sleep 5 # Даем время на запуск

    # Создаем пользователя и базу данных из переменных окружения
    psql -v ON_ERROR_STOP=1 --username postgres <<-EOSQL
        CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
        CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
EOSQL

    # Останавливаем временный сервер PostgreSQL
    kill -SIGINT "$pid"
    wait "$pid"
    echo "Database initialization complete."
fi

# Эта строчка должна быть последней.
# Она передает управление дальше supervisord'у.
exit 0