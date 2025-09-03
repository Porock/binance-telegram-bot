# d:\Git\binance-bot\binance-telegram-bot-1\start.sh
#!/bin/bash
set -e

# Путь к данным PostgreSQL версии 12
PGDATA="/var/lib/postgresql/12/main"

# Проверяем, была ли база данных уже инициализирована
if [ ! -d "$PGDATA/base" ]; then
    echo "Initializing PostgreSQL database..."
    
    # Создаем директорию и назначаем права пользователю postgres
    mkdir -p $PGDATA
    chown -R postgres:postgres $PGDATA

    # Запускаем initdb от имени пользователя postgres
    su - postgres -c "/usr/lib/postgresql/12/bin/initdb -D $PGDATA"

    # Временно запускаем сервер PostgreSQL в фоне для настройки
    su - postgres -c "/usr/lib/postgresql/12/bin/postgres -D $PGDATA &"
    pid="$!"
    # Ждем пару секунд, чтобы сервер успел запуститься
    sleep 5

    # Создаем пользователя и базу данных, используя переменные окружения
    psql -v ON_ERROR_STOP=1 --username postgres <<-EOSQL
        CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
        CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
EOSQL

    # Останавливаем временный сервер PostgreSQL
    kill -SIGINT "$pid"
    wait "$pid"
    echo "Database initialization complete."
else
    echo "PostgreSQL database already initialized."
fi

# Выходим, чтобы supervisor мог запустить постоянный процесс postgresql
exit 0