#!/bin/bash

## Only include mailpit rev proxy configuration is mailpit is enabled.
if [ "$MTA_ROLE" == "mailpit" ]
then cat /etc/nginx/nginx.site.part1 /etc/nginx/nginx.site.part-mailpit /etc/nginx/nginx.site.part2 > /etc/nginx/conf.d/nginx.conf
else cat /etc/nginx/nginx.site.part1 /etc/nginx/nginx.site.part2 > /etc/nginx/conf.d/nginx.conf
fi

# Import certificates if available in import bind mount. Otherwise generate
# a self-signed certificate

CERTIFICATE_IMPORTDIR=/etc/import-certificates
CERTIFICATE_DIR=/etc/certificates
cd "$CERTIFICATE_DIR"

if [ -f "${CERTIFICATE_IMPORTDIR}/matomo.pem" ] && [ -f "${CERTIFICATE_IMPORTDIR}/matomo.key" ]
then echo "Importing TLS certificate ..."
     cp "${CERTIFICATE_IMPORTDIR}/matomo.pem" "${CERTIFICATE_DIR}/matomo.pem"
     cp "${CERTIFICATE_IMPORTDIR}/matomo.key" "${CERTIFICATE_DIR}/matomo.key"
else if [ -f "matomo.pem" ]
     then echo "Skipping certificate generation, because certificate files are already present."
     else echo "Generating certificates for reverse proxy  at https://$MATOMO_HOST ..."
	  export MATOMO_HOST="$MATOMO_HOST"
          perl -pi.bak -e '$matomo_host=$ENV{MATOMO_HOST}; s/MATOMO_HOST/$matomo_host/ge' /etc/certificates/matomo.cnf
          openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout matomo.key -out matomo.pem -config matomo.cnf
     echo "Certificate generation complete."
     fi
fi

if [ -f "dhparams.pem" ]
then echo "Skipping DHParam generation, because DHParam file is already present."
else echo "Generating DHParam configuration..."
     openssl dhparam -dsaparam -out "${CERTIFICATE_DIR}/dhparams.pem" 4096
     echo "DHParam generation complete."
fi

# Configure host header for reverse proxy
if [ "$MATOMO_HOST_PORT" -eq "443" ]
then export HOST_HEADER="${MATOMO_HOST}"
else export HOST_HEADER="${MATOMO_HOST}:${MATOMO_HOST_PORT}"
fi
perl -pi.bak -e '$host_header=$ENV{HOST_HEADER}; s/PUT_HOST_HEADER_HERE/"$host_header"/ge' "/etc/nginx/conf.d/nginx.conf"

## Run Nginx
nginx -g "daemon off;"
