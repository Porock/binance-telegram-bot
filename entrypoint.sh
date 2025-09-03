#!/bin/bash
set -e

PGDATA="/var/lib/postgresql/16/main"

# Экспортируем переменные, чтобы они были доступны в дочерних процессах 'su'
export DB_USER
export DB_PASSWORD
export DB_NAME

# Всегда устанавливаем владельца при старте
chown -R postgres:postgres /var/lib/postgresql/16

# Проверяем, пуста ли папка с данными
if [ -z "$(ls -A $PGDATA)" ]; then
    echo "Initializing PostgreSQL database..."

    su - postgres -c "/usr/lib/postgresql/16/bin/initdb -D $PGDATA"
    
    echo "host all all 127.0.0.1/32 trust" >> "$PGDATA/pg_hba.conf"
    
    su - postgres -c "/usr/lib/postgresql/16/bin/pg_ctl start -D $PGDATA"
    
    # Переменные теперь точно будут доступны здесь. Добавлены кавычки для надежности.
    su - postgres -c "psql -v ON_ERROR_STOP=1 <<-EOSQL
        CREATE USER \"${DB_USER}\" WITH PASSWORD '${DB_PASSWORD}';
        CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";
    EOSQL"
    
    su - postgres -c "/usr/lib/postgresql/16/bin/pg_ctl stop -D $PGDATA"

    echo "Database initialization complete."
else
    echo "PostgreSQL database already initialized."
fi

# Запускаем supervisord
exec "$@"