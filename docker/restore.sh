#!/bin/bash
#
# This script restores backup data to the containerized Matomo web statistics environment

STAGINGDIR="$1"

source ./.env

if [ -z "$STAGINGDIR" ]
then echo "No staging dir provided. Setting it to current working directory."
     STAGINGDIR="."
fi

read -r -d '' RESET_MATOMO_DB << EOF
DROP DATABASE matomo;
CREATE DATABASE matomo;
DROP USER IF EXISTS matomo;
CREATE USER 'matomo'@'%' IDENTIFIED BY '$MARIADB_PASSWORD';
GRANT ALL PRIVILEGES ON matomo.* TO 'matomo'@'%';
FLUSH PRIVILEGES;
SHOW GRANTS FOR 'matomo';
EOF

read -r -d '' SET_MATOMO_PRIVILEGES << EOF
GRANT ALL PRIVILEGES ON matomo.* TO 'matomo'@'%';
FLUSH PRIVILEGES;
SHOW GRANTS FOR 'matomo';
EOF

set -e
set -x

echo "Setting up Matomo database ..."
echo "$RESET_MATOMO_DB" | docker exec -i matomo /bin/bash -c "mysql -h database -u root \"-p${MARIADB_ROOT_PASSWORD}\""

echo "Restoring contents of Matomo database ..."
gunzip -c "${STAGINGDIR}/matomo-db.sql.gz" | docker exec -i matomo /bin/bash -c "mysql -h database -u root \"-p${MARIADB_ROOT_PASSWORD}\" matomo"

echo "Setting up Matomo database privileges ..."
echo "$SET_MATOMO_PRIVILEGES" | docker exec -i matomo /bin/bash -c "mysql -h database -u root \"-p${MARIADB_ROOT_PASSWORD}\""

echo "Restoring Matomo local configuration and temporary data ..."
gunzip -c "${STAGINGDIR}/matomo.tar.gz" | docker exec -i matomo /bin/bash -c "tar xv -C /var/www/html matomo/tmp matomo/config"

echo "Restarting Matomo ..."
docker restart matomo
