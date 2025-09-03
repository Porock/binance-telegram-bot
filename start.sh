# d:\Git\binance-bot\binance-telegram-bot-1\start.sh
#!/bin/bash
set -e

# Путь к данным PostgreSQL версии 12
PGDATA="/var/lib/postgresql/12/main"

# Проверяем, была ли база данных уже инициализирована
# Если папка PGDATA пуста, то запускаем инициализацию
if [ -z "$(ls -A $PGDATA)" ]; then
    echo "Initializing PostgreSQL database..."

    # Меняем владельца папки, чтобы postgres мог в нее писать
    chown -R postgres:postgres /var/lib/postgresql/12
    
    # Запускаем initdb от имени пользователя postgres
    su - postgres -c "/usr/lib/postgresql/12/bin/initdb -D $PGDATA"
    
    # Временно запускаем сервер PostgreSQL в фоне для настройки
    su - postgres -c "/usr/lib/postgresql/12/bin/postgres -D $PGDATA &"
    # Даем немного времени на запуск
    sleep 5

    # Создаем пользователя и базу данных, используя переменные окружения
    su - postgres -c "psql -v ON_ERROR_STOP=1 <<-EOSQL
        CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
        CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
    EOSQL"
    
    # Останавливаем временный сервер PostgreSQL
    su - postgres -c "/usr/lib/postgresql/12/bin/pg_ctl stop -D $PGDATA"

    echo "Database initialization complete."
else
    echo "PostgreSQL database already initialized."
fi

# Выходим, чтобы supervisor мог запустить постоянный процесс postgresql
exit 0