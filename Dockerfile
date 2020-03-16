#######################################################################################
#
# This Dockerfile sets up Ubuntu 18.04 to run Moodle using Apache2
#
#######################################################################################
FROM debian:buster-slim

LABEL maintainer="Greg Messner <greg@messners.com>"
LABEL version="1.0.0"

# Install all the neccessary packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get upgrade --assume-yes \
    && DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends install -y \
            vim curl ca-certificates sudo \
            apache2 php libapache2-mod-php \
            graphviz aspell ghostscript clamav \
            php-pspell php-curl php-gd php-intl  php-pgsql php-xml \
            php-xmlrpc php-ldap php-zip php-soap php-mbstring \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# We need to change the www-data UID:GID as it may already be in use on many Linux distros,
# once done add the /var/log/apache2 and /var/run/apache2 dirs with the correct perms
RUN echo "***** Change the uid and gid for www-data to that of the host OS *****" \
        && find / -path /proc -prune -o -user www-data -exec chown -h 202 {} \;\
    	&& find / -path /proc -prune -o -group www-data -exec chgrp -h 202 {} \;\
    	&& usermod -u 202 www-data && groupmod -g 202 www-data \
    && echo "*************** Setting up Apache for Moodle ***************" \
        && mkdir -p /var/log/apache2 && chown www-data:www-data /var/log/apache2 \
        && mkdir -p /var/run/apache2 && chown www-data:www-data /var/run/apache2 \
        && rm /etc/apache2/sites-available/* \
        && sed -i "s/Listen 80$/Listen 8080/g" /etc/apache2/ports.conf

# Copy the entrypoint script into the image and make it executable
COPY files/moodle-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/moodle-entrypoint.sh

# Copy the moodle.conf file to /etc/apache2/sites-available/
COPY files/moodle.conf /etc/apache2/sites-available/

# Download and install Moodle into the /var/www/html directory 
ARG MOODLE_DOWNLOAD_URL="https://download.moodle.org/download.php/direct/stable38/moodle-latest-38.tgz"
RUN echo "*************** Installing Moodle ***************" \
    && cd /var/www/html && rm index.html \
    && curl -s $MOODLE_DOWNLOAD_URL | tar -xz > /dev/null \
    && mkdir -p /var/www/html/moodledata \
    && chown -R www-data:www-data /var/www/html \
    && a2enmod rewrite && a2ensite moodle.conf \
    && chown www-data:www-data /etc/apache2/sites-available/moodle.conf \
    && echo "done"

# Snd SIGWINCH to gracefully stop apache2, see the following link for more info:
# https://httpd.apache.org/docs/2.4/stopping.html#gracefulstop
STOPSIGNAL SIGWINCH

USER www-data
EXPOSE 8080
ENTRYPOINT ["moodle-entrypoint.sh"]
