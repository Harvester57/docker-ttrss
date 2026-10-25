# Using https://hub.docker.com/_/alpine/,
# plus Alpine's native s6-overlay package.
FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

# Initially was based on work of Christian Lück <christian@lueck.tv>.
LABEL org.opencontainers.image.authors="Andreas Löffler <andy@x86dev.com>"
LABEL org.opencontainers.image.description="A complete, self-hosted Tiny Tiny RSS (TTRSS) environment."
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

# PHP version suffix in Alpine (85 for PHP 8.5, 84 for PHP 8.4).
ARG PHP_VER=85
ENV PHP_VER=${PHP_VER}

RUN set -xe && \
    apk add --no-cache \
    busybox nginx git ca-certificates curl nano sudo tzdata postgresql-client s6-overlay \
    php${PHP_VER} php${PHP_VER}-fpm php${PHP_VER}-ctype php${PHP_VER}-curl php${PHP_VER}-dom \
    php${PHP_VER}-exif php${PHP_VER}-fileinfo php${PHP_VER}-gd php${PHP_VER}-iconv php${PHP_VER}-intl \
    php${PHP_VER}-mbstring php${PHP_VER}-openssl php${PHP_VER}-pcntl php${PHP_VER}-pdo \
    php${PHP_VER}-pdo_pgsql php${PHP_VER}-pgsql php${PHP_VER}-pecl-apcu \
    php${PHP_VER}-mysqli php${PHP_VER}-pdo_mysql \
    php${PHP_VER}-phar php${PHP_VER}-posix php${PHP_VER}-session php${PHP_VER}-simplexml \
    php${PHP_VER}-sockets php${PHP_VER}-sodium php${PHP_VER}-tokenizer php${PHP_VER}-xml \
    php${PHP_VER}-xmlreader php${PHP_VER}-xmlwriter php${PHP_VER}-zip \
    $([ "${PHP_VER}" = "84" ] && echo "php84-opcache")

# Add user www-data for php-fpm.
# 82 is the standard uid/gid for "www-data" in Alpine.
RUN adduser -u 82 -D -S -G www-data www-data || true

# Copy root file system.
COPY root /

# Add wait-for
ADD https://raw.githubusercontent.com/eficode/wait-for/v2.2.4/wait-for /srv/wait-for

# Normalize directory/file permissions and line endings on init/service scripts.
RUN set -xe && \
    if [ "${PHP_VER}" != "85" ] && [ -f /etc/php85/php-fpm.conf ]; then \
        mkdir -p /etc/php${PHP_VER} && cp /etc/php85/php-fpm.conf /etc/php${PHP_VER}/php-fpm.conf; \
    fi && \
    chmod 755 / /etc /srv && \
    find /etc/cont-init.d /etc/services.d /srv /etc/nginx /etc/php* -type d -exec chmod 755 {} + && \
    find /etc/nginx /etc/php* /srv -type f -exec chmod 644 {} + && \
    find /etc/cont-init.d /etc/services.d /srv /etc/nginx /etc/php* -type f -exec sed -i 's/\r$//' {} + && \
    chmod 755 /etc/cont-init.d/* /etc/services.d/*/run /etc/services.d/.s6-svscan/finish /srv/*.sh /srv/*.php /srv/wait-for

# Expose Nginx ports.
EXPOSE 8080 4443

# Expose default database credentials via ENV in order to ease overwriting.
ENV DB_NAME=ttrss \
    DB_USER=ttrss \
    DB_PASS=ttrss

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8080/healthz || curl -fsk https://127.0.0.1:4443/healthz || exit 1

ENTRYPOINT ["/init"]
