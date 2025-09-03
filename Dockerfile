# d:\Git\binance-bot\binance-telegram-bot-1\Dockerfile

# --- ЭТАП 1: СБОРКА ... (остается без изменений) ---
    FROM maven:3-eclipse-temurin-21 AS builder
    WORKDIR /build
    COPY pom.xml .
    COPY src ./src
    RUN mvn package -DskipTests
    
    
    # --- ЭТАП 2: СОЗДАНИЕ ФИНАЛЬНОГО ОБРАЗА ---
    FROM --platform=linux/amd64 eclipse-temurin:21-jdk
    
    # !!! ИЗМЕНЕНИЕ ЗДЕСЬ: добавлен 'dos2unix' в список установки !!!
    RUN apt-get update && apt-get install -y --no-install-recommends gnupg lsb-release wget procps dos2unix && \
        wget -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
        echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
        apt-get update && \
        apt-get install -y --no-install-recommends supervisor postgresql-16 postgresql-client-16 && \
        rm -rf /var/lib/apt/lists/*
    
    WORKDIR /opt/bot
    
    COPY --from=builder /build/target/*.jar ./app.jar
    
    # Копируем supervisord.conf и entrypoint.sh
    COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
    COPY entrypoint.sh /entrypoint.sh
    
    # !!! ИЗМЕНЕНИЕ ЗДЕСЬ: используем установленный dos2unix !!!
    # Эта команда теперь сработает, так как пакет dos2unix установлен выше.
    RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh
    
    EXPOSE 5432
    
    # Указываем, что наш скрипт - это ГЛАВНЫЙ ВХОД
    ENTRYPOINT ["/entrypoint.sh"]
    
    # А supervisor - это КОМАНДА ПО УМОЛЧАНИЮ, которая будет передана в entrypoint
    CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]