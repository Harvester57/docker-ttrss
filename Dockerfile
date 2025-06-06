# Using https://hub.docker.com/_/alpine/,
# plus  https://github.com/just-containers/s6-overlay for a s6 Docker overlay.
FROM alpine:3.15.7

# Initially was based on work of Christian Lück <christian@lueck.tv>.
LABEL description="A complete, self-hosted Tiny Tiny RSS (TTRSS) environment." \
      maintainer="Andreas Löffler <andy@x86dev.com>"

RUN set -xe && \
    apk update && apk upgrade && \
    apk add --no-cache --virtual=run-deps \
    busybox nginx git ca-certificates curl nano \
    php7 php7-fpm php7-curl php7-dom php7-gd php7-iconv php7-fileinfo php7-json \
    php7-pgsql php7-pcntl php7-pdo php7-pdo_pgsql \
    php7-mysqli php7-pdo_mysql \
    php7-mbstring php7-posix php7-session php7-intl sudo

# Add user www-data for php-fpm.
# 82 is the standard uid/gid for "www-data" in Alpine.
RUN adduser -u 82 -D -S -G www-data www-data

# Copy root file system.
COPY root /

# Add s6 overlay.
# Note: Tweak this line if you're running anything other than x86 AMD64 (64-bit).
RUN curl -L -s https://github.com/just-containers/s6-overlay/releases/download/v1.19.1.1/s6-overlay-amd64.tar.gz | tar xvzf - -C /

# Add wait-for-it.sh
ADD https://raw.githubusercontent.com/eficode/wait-for/v2.2.4/wait-for /srv
RUN chmod 755 /srv/wait-for

# Expose Nginx ports.
EXPOSE 8080
EXPOSE 4443

# Expose default database credentials via ENV in order to ease overwriting.
ENV DB_NAME ttrss
ENV DB_USER ttrss
ENV DB_PASS ttrss

# Clean up.
RUN set -xe && apk del --progress --purge && rm -rf /var/cache/apk/* && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/init"]
