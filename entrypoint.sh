#!/bin/bash
set -e # Выход при любой ошибке

# Определяем путь к данным и путь к нашему файлу-флагу
PGDATA="/var/lib/postgresql/16/main"
INIT_FLAG_FILE="$PGDATA/.db_initialized_flag"

# Экспортируем переменные для дочерних процессов
export DB_USER
export DB_PASSWORD
export DB_NAME

# Всегда устанавливаем правильного владельца
mkdir -p "$PGDATA"
chown -R postgres:postgres /var/lib/postgresql/16

# --- ГЛАВНОЕ ИЗМЕНЕНИЕ: НЕ ДОВЕРЯЕМ НИЧЕМУ, ЕСЛИ НЕТ ФЛАГА ---
if [ ! -f "$INIT_FLAG_FILE" ]; then
    echo ">>>> Initialization flag not found. Wiping data directory and starting from scratch..."

    # Полностью очищаем каталог от любых шаблонных файлов
    rm -rf "$PGDATA"/*
    
    # Инициализируем АБСОЛЮТНО НОВЫЙ кластер. Это создаст postgresql.conf и все остальное.
    su - postgres -c "/usr/lib/postgresql/16/bin/initdb -D $PGDATA"
    
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

# Запускаем supervisord
echo ">>>> Starting supervisord..."
exec "$@"