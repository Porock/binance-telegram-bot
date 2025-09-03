#!/bin/bash
set -e # Выход при любой ошибке

# Определяем путь к данным
PGDATA="/var/lib/postgresql/16/main"

# Экспортируем переменные, чтобы они были доступны во всех дочерних процессах (su)
export DB_USER
export DB_PASSWORD
export DB_NAME

# Создаем директорию, если ее нет, и всегда устанавливаем правильного владельца
mkdir -p "$PGDATA"
chown -R postgres:postgres /var/lib/postgresql/16

# --- ГЛАВНОЕ ИЗМЕНЕНИЕ: Самая надежная проверка ---
# Проверяем, существует ли ключевой файл PG_VERSION. Если нет - база не инициализирована.
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo ">>>> 'PG_VERSION' file not found. Forcing database initialization..."
    
    # На всякий случай очищаем папку от любого возможного мусора
    rm -rf "$PGDATA"/*
    
    # Инициализируем базу от имени пользователя postgres
    su - postgres -c "/usr/lib/postgresql/16/bin/initdb -D $PGDATA"
    
    # Разрешаем подключение по паролю для localhost
    echo "host all all 127.0.0.1/32 scram-sha-256" >> "$PGDATA/pg_hba.conf"
    
    # Запускаем временный сервер для настройки
    su - postgres -c "/usr/lib/postgresql/16/bin/pg_ctl start -D $PGDATA"
    
    # Создаем пользователя и базу данных
    su - postgres -c "psql -v ON_ERROR_STOP=1 <<-EOSQL
        CREATE USER \"${DB_USER}\" WITH PASSWORD '${DB_PASSWORD}';
        CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";
    EOSQL"
    
    # Останавливаем временный сервер
    su - postgres -c "/usr/lib/postgresql/16/bin/pg_ctl stop -D $PGDATA"

    echo ">>>> Database initialization complete."
else
    echo ">>>> 'PG_VERSION' file found. Database already initialized."
fi

# В самом конце, запускаем основную команду (которая была передана в Dockerfile - supervisord)
echo ">>>> Starting supervisord..."
exec "$@"