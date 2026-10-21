FROM ubuntu:24.04
LABEL maintainer="Yoda team <yoda@uu.nl>"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Application settings
ENV MATOMO_VERSION="5.8.0"
ENV MATOMO_EXTRATOOLS_PLUGIN_VERSION="5.1.5"
ENV MATOMO_PAGEVIEWCOUNTER_PLUGIN_VERSION="v0.0.1"

# Network settings
EXPOSE 80

# Update packages
RUN apt-get update

# Install common tools
# hadolint ignore=DL3033
RUN apt-get install -y wget git vim sudo nmap crudini mariadb-client

## Install Apache
# hadolint ignore=DL3033
RUN apt-get install -y apache2 apache2-dev libapache2-mod-php && \
    a2enmod headers && \
    a2enmod rewrite
COPY 001-matomo.conf /etc/apache2/sites-available/001-matomo.conf
RUN a2dissite 000-default.conf && \
    a2ensite 001-matomo.conf

## Install PHP dependencies
RUN apt-get satisfy -y --no-install-recommends \
      "php8.3 (>= 8.3.6-0ubuntu0.24.04.13)" \
      "php8.3-cli (>= 8.3.6-0ubuntu0.24.04.13)" \
      "php8.3-curl (>= 8.3.6-0ubuntu0.24.04.13)" \
      "php8.3-gd (>= 8.3.6-0ubuntu0.24.04.13)" \
      "php8.3-mbstring (>= 8.3.6-0ubuntu0.24.04.13)" \
      "php8.3-mysql (>= 8.3.6-0ubuntu0.24.04.13)" \
      "php8.3-xml (>= 8.3.6-0ubuntu0.24.04.13)"

## Install Matomo
RUN cd /tmp && \
    wget "https://builds.matomo.org/matomo-${MATOMO_VERSION}.tar.gz" && \
    cd /var/www/html && \
    tar xvfz "/tmp/matomo-${MATOMO_VERSION}.tar.gz" && \
    rm "/tmp/matomo-${MATOMO_VERSION}.tar.gz"

## Install Matomo plugins
RUN cd /var/www/html/matomo/plugins && \
    git clone --branch "$MATOMO_EXTRATOOLS_PLUGIN_VERSION" https://github.com/Digitalist-Open-Cloud/Matomo-Plugin-ExtraTools.git ExtraTools && \
    git clone --branch "$MATOMO_PAGEVIEWCOUNTER_PLUGIN_VERSION" https://github.com/UtrechtUniversity/matomo-plugin-pageviewcounter.git PageViewCounter && \
    echo "[General]" > /var/www/html/matomo/config/common.config.ini.php && \
    echo "always_load_commands_from_plugin=ExtraTools" >> /var/www/html/matomo/config/common.config.ini.php && \
    chown -R www-data:www-data /var/www/html/matomo &&\
    find /var/www/html/matomo/tmp -type f -exec chmod 644 {} \; &&\
    find /var/www/html/matomo/tmp -type d -exec chmod 755 {} \;

# Install init script
# hadolint ignore=DL3033
COPY matomo-init.sh /matomo-init.sh
RUN chmod 0755 /matomo-init.sh

VOLUME [ "/sys/fs/cgroup" ]
CMD exec /matomo-init.sh
