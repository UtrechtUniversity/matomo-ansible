#!/bin/bash

set -o pipefail
set -u

INITIALIZATION_FLAG_FILE="/var/www/html/matomo/config/.matomo-initialized"
MATOMO_DB_COLLATION="utf8mb4_uca1400_ai_ci"
MATOMO_DB_CHARSET="utf8mb4"
CONFIGFILE="/var/www/html/matomo/config/config.ini.php"

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

if ! [[ -f "$INITIALIZATION_FLAG_FILE" ]]
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
       --db-prefix="$MATOMO_DATABASE_TABLES_PREFIX" \
       --db-adapter="$MATOMO_DATABASE_ADAPTER" \
       --db-collation=$MATOMO_DB_COLLATION \
       --db-charset=$MATOMO_DB_CHARSET  \
       --first-user="$MATOMO_FIRST_USER_NAME" \
       --first-user-email="$MATOMO_FIRST_USER_EMAIL" \
       --first-user-pass="$MATOMO_FIRST_USER_PASSWORD"
     progress_update "Matomo initialized"

     # Run a core update to ensure that all plugin tables have been loaded.
     before_update "Running core update to initialize plugin tables"
     sudo -u www-data php console core:update
     progress_update "Core update finished"

     # Add the site manually, due to ExtraTools bug in https://plugins.matomo.org/ExtraTools?matomoversion=5#documentation
     before_update "Adding first site."
     sudo -u www-data php console site:add \
       --name="$MATOMO_FIRST_SITE_NAME" \
       --urls="$MATOMO_FIRST_SITE_URL"
     progress_update "First site added"

     # Dummy command to trigger creation of missing tables after site:add
     # See https://github.com/Digitalist-Open-Cloud/Matomo-Plugin-ExtraTools/issues/44 for context
     before_update "Triggering table creation by querying visits for non-existent site."
     sudo -u www-data php console visits:get -i 999 || true
     progress_update "Triggered table creation by querying visits for non-existent site."

     crudini --set "$CONFIGFILE" General browser_archiving_disabled_enforce 1
     crudini --set "$CONFIGFILE" General force_ssl 1
     crudini --set "$CONFIGFILE" General assume_secure_protocol 1
     crudini --set "$CONFIGFILE" General proxy_client_headers[] HTTP_X_FORWARDED_FOR
     crudini --set "$CONFIGFILE" General proxy_host_headers[] HTTP_X_FORWARDED_HOST
     crudini --set "$CONFIGFILE" database collation "${MATOMO_DB_COLLATION}"
     crudini --set "$CONFIGFILE" database schema MariaDB
     crudini --set "$CONFIGFILE" database charset "${MATOMO_DB_CHARSET}"

     IFS=';' read -ra DOMAIN <<< "$MATOMO_CORS_DOMAINS"
     for domain in "${DOMAIN[@]}"
     do # Use AWK rather than Crudini in order to be able to handle multiple
	# values with same key and section.
	awk -v line="cors_domains[] = \"$domain\"\n" '
        /^\[General\]/ && !done {
            print
            printf "%s", line
            done=1
            next
        }
        { print }
    ' "$CONFIGFILE" > "${CONFIGFILE}.tmp" && mv "${CONFIGFILE}.tmp" "$CONFIGFILE"
     done
 
     chmod 0644 "$CONFIGFILE"
     chown www-data:www-data "$CONFIGFILE"

     touch "$INITIALIZATION_FLAG_FILE"
fi

before_update "Initialization complete. Starting Apache"
start_service
