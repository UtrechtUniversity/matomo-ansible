#!/bin/bash

set -o pipefail
set -u

function start_service {
  apache2ctl -D FOREGROUND || true
  echo "Error: Apache either terminated or would not start. Keeping container running for troubleshooting purposes."
  sleep infinity
}

function before_update {
  echo -e "[...] ${1}"
}

function progress_update {
  GREEN='\033[0;32m'
  RESET='\033[0m'
  echo -e "[ ${GREEN}\xE2\x9C\x94${RESET} ] ${1}"
}

check_port() {
    local host="$1"
    local port="$2"

    echo "Checking service availability at ${host}:${port}..."

    while true; do
        # Use nmap to scan the specified port on the given host
        nmap -p "${port}" "${host}" | grep -q "open"

        # If the port is open, exit the loop
        if [ $? -eq 0 ]; then
            echo "Server is available at ${host}:${port}"
            break
        else
            echo "Server at ${host}:${port} is not available. Retrying in 1 seconds..."
            sleep 1
        fi
    done
}

## Check DB up
check_port database 3306

set -e

if ! [[ -f /container_initialized ]]
then before_update "Setting up Apache vhost"
     perl -pi -e '$servername=$ENV{MATOMO_HOST}; s/SERVERNAME/$servername/' /etc/apache2/sites-available/001-matomo.conf
     before_update "Initializing Matomo."
     cd /var/www/html/matomo
     sudo -u www-data php console matomo:install --no-interaction --force -vvv \
       --db-username="$MATOMO_DATABASE_USERNAME" \
       --db-pass="$MATOMO_DATABASE_PASSWORD" \
       --db-host="$MATOMO_DATABASE_HOST" \
       --db-port=3306 \
       --db-name="$MATOMO_DATABASE_DBNAME" \
       --db-prefix="${MATOMO_DATABASE_TABLES_PREFIX:-matomo_}" \
       --db-adapter="${MATOMO_DATABASE_ADAPTER:-mysqli}" \
       --db-collation=utf8mb4_general_ci \
       --db-charset=utf8mb4 \
       --first-site-name="$MATOMO_FIRST_SITE_NAME" \
       --first-site-url="$MATOMO_FIRST_SITE_URL" \
       --first-user="$MATOMO_FIRST_USER_NAME" \
       --first-user-email="$MATOMO_FIRST_USER_EMAIL" \
       --first-user-pass="$MATOMO_FIRST_USER_PASSWORD"
     crudini --set /var/www/html/matomo/config/config.ini.php General force_ssl 1
     crudini --set /var/www/html/matomo/config/config.ini.php General assume_secure_protocol 1
     crudini --set /var/www/html/matomo/config/config.ini.php General proxy_client_headers[] HTTP_X_FORWARDED_FOR
     crudini --set /var/www/html/matomo/config/config.ini.php General proxy_host_headers[] HTTP_X_FORWARDED_HOST
     chmod 0644 /var/www/html/matomo/config/config.ini.php
     chown www-data:www-data /var/www/html/matomo/config/config.ini.php
     touch /container_initialized
fi

before_update "Initialization complete. Starting Apache"
start_service
