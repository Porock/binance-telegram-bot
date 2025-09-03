# --- ЭТАП 1: СБОРКА ПРИЛОЖЕНИЯ С ПОМОЩЬЮ MAVEN ---
# Используем образ Maven с той же версией JDK (Temurin 21) для сборки
FROM maven:3-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
# Собираем jar-файл, пропуская тесты для скорости
RUN mvn package -DskipTests


# --- ЭТАП 2: СОЗДАНИЕ ФИНАЛЬНОГО ОБРАЗА ---
# Используем ваш базовый образ с Java 21 JDK
FROM --platform=linux/amd64 eclipse-temurin:21-jdk

# Устанавливаем PostgreSQL 12 и Supervisor, как в вашем файле
RUN apt-get update && apt-get install -y --no-install-recommends gnupg lsb-release wget && \
    wget -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends supervisor postgresql-12 && \
    rm -rf /var/lib/apt/lists/*

# Создаем директорию для бота
WORKDIR /opt/bot

# Копируем скомпилированный .jar файл из первого этапа сборки ("builder")
COPY --from=builder /build/target/*.jar ./app.jar

# Копируем наши файлы конфигурации (вместо генерации через echo)
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh ./start.sh
RUN chmod +x ./start.sh

# Открываем порт для PostgreSQL
EXPOSE 5432

# Запускаем supervisor, который будет управлять нашими процессами
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]