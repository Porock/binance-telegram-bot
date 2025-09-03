# For Java 21, with PostgreSQL and Supervisor
FROM --platform=linux/amd64 eclipse-temurin:21-jdk

# Install dependencies for adding new repositories and running postgres
RUN apt-get update && \
    apt-get install -y --no-install-recommends gnupg lsb-release wget sudo && \
    rm -rf /var/lib/apt/lists/*

# Add PostgreSQL official repository to install version 12
RUN wget -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# Install Supervisor and PostgreSQL
RUN apt-get update && \
    apt-get install -y --no-install-recommends supervisor postgresql-12 && \
    rm -rf /var/lib/apt/lists/* && \
    # Allow postgres user to run initdb via sudo without a password
    echo "postgres ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Create supervisor config file
RUN echo -e "\
[supervisord]\n\
nodaemon=true\n\
user=root\n\
\n\
[program:db_setup]\n\
command=/opt/bot/start.sh\n\
autostart=true\n\
autorestart=false\n\
startretries=0\n\
\n\
[program:postgresql]\n\
command=/usr/lib/postgresql/12/bin/postgres -D /var/lib/postgresql/12/main -c config_file=/etc/postgresql/12/main/postgresql.conf\n\
user=postgres\n\
autostart=true\n\
autorestart=true\n\
priority=10\n\
\n\
[program:binance-bot]\n\
command=java -jar /opt/bot/app.jar\n\
directory=/opt/bot\n\
autostart=true\n\
autorestart=true\n\
priority=20\n\
" > /etc/supervisor/supervisord.conf

# cd /opt/bot
WORKDIR /opt/bot

# Create database setup script required by supervisord
RUN echo -e '#!/bin/bash\n\
set -e\n\
PGDATA_DIR="/var/lib/postgresql/12/main"\n\
if [ -z "\$(ls -A \$PGDATA_DIR 2>/dev/null)" ]; then\n\
    echo "Initializing PostgreSQL database..."\n\
    mkdir -p /var/lib/postgresql/12/\n\
    chown -R postgres:postgres /var/lib/postgresql/12/\n\
    sudo -u postgres /usr/lib/postgresql/12/bin/initdb -D "\$PGDATA_DIR"\n\
    echo "Database initialization complete."\n\
else\n\
    echo "PostgreSQL database already initialized."\n\
fi\n\
' > /opt/bot/start.sh
RUN chmod +x /opt/bot/start.sh

# Refer to Maven build -> finalName
ARG JAR_FILE=target/*.jar

# cp target/*.jar /opt/bot/app.jar
COPY ${JAR_FILE} app.jar

# Expose PostgreSQL port
EXPOSE 5432

# /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]