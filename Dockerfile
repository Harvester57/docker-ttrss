# Using https://hub.docker.com/_/alpine/,
# plus  https://github.com/just-containers/s6-overlay for a s6 Docker overlay.
FROM alpine:3.17.1

# Initially was based on work of Christian Lück <christian@lueck.tv>.
LABEL description="A complete, self-hosted Tiny Tiny RSS (TTRSS) environment." \
      maintainer="Andreas Löffler <andy@x86dev.com>"

RUN set -xe && \
    apk update && apk upgrade && \
    apk add --no-cache --virtual=run-deps \
    busybox nginx git ca-certificates curl nano \
    php81 php81-fpm php81-curl php81-dom php81-gd php81-iconv php81-fileinfo php81-json \
    php81-pgsql php81-pcntl php81-pdo php81-pdo_pgsql \
    php81-mysqli php81-pdo_mysql \
    php81-mbstring php81-posix php81-session php81-intl

# Add user www-data for php-fpm.
# 82 is the standard uid/gid for "www-data" in Alpine.
RUN adduser -u 82 -D -S -G www-data www-data

# Copy root file system.
COPY root /

# Add s6 overlay.
# Note: Tweak this line if you're running anything other than x86 AMD64 (64-bit).
RUN curl -L -s https://github.com/just-containers/s6-overlay/releases/download/v3.1.3.0/s6-overlay-x86_64.tar.xz | tar xvf - -C /

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
