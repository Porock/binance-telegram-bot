#!/bin/bash
set -e # Выход при любой ошибке

# Определяем путь к данным и путь к нашему файлу-флагу
PGDATA="/var/lib/postgresql/16/main"
INIT_FLAG_FILE="$PGDATA/.db_initialized_flag"

# Экспортируем переменные, чтобы они были доступны во всех дочерних процессах (su)
export DB_USER
export DB_PASSWORD
export DB_NAME

# Создаем директорию, если ее нет, и всегда устанавливаем правильного владельца
# Это важно, так как владелец может сброситься при перезапуске
mkdir -p "$PGDATA"
chown -R postgres:postgres /var/lib/postgresql/16

# --- ГЛАВНОЕ ИЗМЕНЕНИЕ: Проверяем наш собственный флаг ---
if [ ! -f "$INIT_FLAG_FILE" ]; then
    echo ">>>> Initialization flag not found. Starting database setup..."

    # Проверяем, существует ли PG_VERSION. Если нет, то это действительно первый запуск.
    if [ ! -f "$PGDATA/PG_VERSION" ]; then
        echo ">>>> PG_VERSION not found. Initializing new database cluster..."
        su - postgres -c "/usr/lib/postgresql/16/bin/initdb -D $PGDATA"
    else
        echo ">>>> PG_VERSION found. Using pre-existing (template) cluster."
    fi

    # Разрешаем подключение по паролю для localhost
    echo "host all all 127.0.0.1/32 scram-sha-256" >> "$PGDATA/pg_hba.conf"
    
    # Запускаем временный сервер для настройки
    su - postgres -c "/usr/lib/postgresql/16/bin/pg_ctl start -D $PGDATA"
    
    # Создаем пользователя и базу данных
    echo ">>>> Creating user '${DB_USER}' and database '${DB_NAME}'..."
    su - postgres -c "psql -v ON_ERROR_STOP=1 <<-EOSQL
        CREATE USER \"${DB_USER}\" WITH PASSWORD '${DB_PASSWORD}';
        CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";
    EOSQL"
    
    # Останавливаем временный сервер
    su - postgres -c "/usr/lib/postgresql/16/bin/pg_ctl stop -D $PGDATA"

    # Создаем наш файл-флаг, чтобы этот блок больше не выполнялся
    echo ">>>> Creating initialization flag file..."
    touch "$INIT_FLAG_FILE"
    
    echo ">>>> Database setup complete."
else
    echo ">>>> Initialization flag found. Skipping database setup."
fi

# В самом конце, запускаем основную команду (supervisord)
echo ">>>> Starting supervisord..."
exec "$@"