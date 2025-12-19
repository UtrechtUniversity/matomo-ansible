#!/bin/bash
#
# This script backs up data from a containerized Matomo environment

source ./.env

STAGINGDIR="$1"

if [ -z "$STAGINGDIR" ]
then echo "No staging dir provided. Setting it to current working directory."
     STAGINGDIR="."
fi

docker exec matomo /bin/bash -c "cd /var/www/html && tar cv matomo" | gzip -9 > "${STAGINGDIR}/matomo.tar.gz"
docker exec matomo /bin/bash -c "mariadb-dump -h database -u root "-p$MARIADB_ROOT_PASSWORD" matomo" | gzip -9 > "${STAGINGDIR}/matomo-db.sql.gz"
