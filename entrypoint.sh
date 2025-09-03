# d:\Git\binance-bot\binance-telegram-bot-1\entrypoint.sh
#!/bin/bash
set -e

PGDATA="/var/lib/postgresql/12/main"


# Проверяем, пуста ли папка с данными
if [ -z "$(ls -A $PGDATA)" ]; then
    echo "Initializing PostgreSQL database..."

    chown -R postgres:postgres /var/lib/postgresql/12
    
    su - postgres -c "/usr/lib/postgresql/12/bin/initdb -D $PGDATA"
    
    # ВАЖНО: Нам больше не нужно запускать/останавливать временный сервер.
    # Мы можем настроить его "офлайн".
    # Сначала добавим в конфиг, что доверять локальным подключениям.
    echo "host all all 127.0.0.1/32 trust" >> "$PGDATA/pg_hba.conf"
    
    # Теперь можно безопасно запустить сервер для настройки
    su - postgres -c "/usr/lib/postgresql/12/bin/pg_ctl start -D $PGDATA"
    
    su - postgres -c "psql -v ON_ERROR_STOP=1 <<-EOSQL
        CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
        CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
    EOSQL"
    
    su - postgres -c "/usr/lib/postgresql/12/bin/pg_ctl stop -D $PGDATA"

    echo "Database initialization complete."
else
    echo "PostgreSQL database already initialized."
fi

# В самом конце, когда все готово,
# запускаем команду, которая была передана в Dockerfile (это будет supervisord)
exec "$@"