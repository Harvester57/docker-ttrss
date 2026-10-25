#!/bin/sh

load_secret_files()
{
    SUFFIX="__FILE"
    for VAR in $(printenv | awk -F= '{print $1}'); do
        case "$VAR" in
            *"$SUFFIX")
                ENV_FILE_NAME="$(printenv "${VAR}")"
                ENV_VAR="${VAR%"$SUFFIX"}"
                if [ -r "$ENV_FILE_NAME" ]; then
                    export "$ENV_VAR"="$(cat "$ENV_FILE_NAME")"
                    echo "Setup: $ENV_VAR populated from secret file $ENV_FILE_NAME"
                else
                    echo "Setup: Warning: secret file $ENV_FILE_NAME for $VAR is not readable"
                fi
                ;;
        esac
    done
}

setup_nginx()
{
    if [ -z "$TTRSS_HOST" ]; then
        TTRSS_HOST=ttrss
    fi

    NGINX_CONF=/etc/nginx/nginx.conf

    if [ "$TTRSS_WITH_SELFSIGNED_CERT" = "1" ]; then
        # Install OpenSSL if not present.
        if ! command -v openssl >/dev/null 2>&1; then
            apk add --no-cache openssl
        fi

        if [ ! -f "/etc/ssl/private/ttrss.key" ]; then
            echo "Setup: Generating self-signed certificate ..."
            mkdir -p /etc/ssl/private /etc/ssl/certs
            # Generate the TLS certificate for our Tiny Tiny RSS server instance.
            openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
                -subj "/C=US/ST=World/L=World/O=$TTRSS_HOST/CN=$TTRSS_HOST" \
                -keyout "/etc/ssl/private/ttrss.key" \
                -out "/etc/ssl/certs/ttrss.crt"
        fi

        # Turn on SSL using modern Nginx syntax.
        sed -i -e "s/listen[[:space:]]*8080[[:space:]]*;/listen 4443 ssl;/g" ${NGINX_CONF}
        sed -i -e "s/#ssl_/ssl_/g" ${NGINX_CONF}

        # Set permissions.
        chmod 600 "/etc/ssl/private/ttrss.key"
        chmod 600 "/etc/ssl/certs/ttrss.crt"
    else
        echo "Setup: !!! WARNING - No encryption (TLS) used - WARNING    !!!"
        echo "Setup: !!! This is not recommended for a production server !!!"
        echo "Setup:                You have been warned."

        # Turn off SSL using modern Nginx syntax.
        sed -i -e "s/listen[[:space:]]*4443\([[:space:]]*ssl\)\?[[:space:]]*;/listen 8080;/g" ${NGINX_CONF}
        sed -i -e "s/^[[:space:]]*ssl_/        #ssl_/g" ${NGINX_CONF}
    fi
}

setup_ttrss()
{
    if [ -z "$TTRSS_REPO_URL" ]; then
        TTRSS_REPO_URL=https://github.com/tt-rss/tt-rss.git
    fi

    if [ -z "$TTRSS_PATH" ]; then
        TTRSS_PATH=/var/www/ttrss
    fi

    TTRSS_PATH_THEMES=${TTRSS_PATH}/themes.local
    TTRSS_PATH_PLUGINS=${TTRSS_PATH}/plugins.local

    git config --system --add safe.directory '*'

    if [ ! -d "${TTRSS_PATH}/.git" ]; then
        mkdir -p "${TTRSS_PATH}"
        if [ -n "${TTRSS_GIT_TAG}" ]; then
            echo "Setup: Setting up Tiny Tiny RSS tag '${TTRSS_GIT_TAG}' from ${TTRSS_REPO_URL} ..."
            (
                cd "${TTRSS_PATH}"
                git init .
                git remote add origin "${TTRSS_REPO_URL}"
                git fetch --depth=1 origin "refs/tags/${TTRSS_GIT_TAG}:refs/tags/${TTRSS_GIT_TAG}"
                git checkout "tags/${TTRSS_GIT_TAG}"
            )
        elif [ -n "${TTRSS_GIT_COMMIT}" ]; then
            echo "Setup: Setting up Tiny Tiny RSS commit '${TTRSS_GIT_COMMIT}' from ${TTRSS_REPO_URL} ..."
            git clone "${TTRSS_REPO_URL}" "${TTRSS_PATH}"
            ( cd "${TTRSS_PATH}" && git checkout "${TTRSS_GIT_COMMIT}" )
        else
            echo "Setup: Setting up Tiny Tiny RSS (latest revision) from ${TTRSS_REPO_URL} ..."
            git clone --depth=1 "${TTRSS_REPO_URL}" "${TTRSS_PATH}"
        fi
    else
        (
            cd "${TTRSS_PATH}"
            CURRENT_ORIGIN="$(git config --get remote.origin.url || true)"
            if [ "${CURRENT_ORIGIN}" = "https://git.tt-rss.org/fox/tt-rss.git/" ] || [ "${CURRENT_ORIGIN}" = "https://git.tt-rss.org/fox/tt-rss.git" ]; then
                echo "Setup: Migrating TT-RSS git remote to ${TTRSS_REPO_URL}"
                git remote set-url origin "${TTRSS_REPO_URL}"
                git fetch --depth=1 origin main
                git checkout -B main origin/main
            fi
        )
    fi

    mkdir -p "${TTRSS_PATH_PLUGINS}"
    if [ ! -d "${TTRSS_PATH_PLUGINS}/mobilize/.git" ]; then
        git clone --depth=1 https://github.com/sepich/tt-rss-mobilize.git "${TTRSS_PATH_PLUGINS}/mobilize"
    fi
    if [ ! -d "${TTRSS_PATH_PLUGINS}/feediron/.git" ]; then
        git clone --depth=1 https://github.com/feediron/ttrss_plugin-feediron.git "${TTRSS_PATH_PLUGINS}/feediron"
    fi
    if [ ! -d "${TTRSS_PATH_PLUGINS}/fever/.git" ]; then
        git clone --depth=1 https://github.com/DigitalDJ/tinytinyrss-fever-plugin.git "${TTRSS_PATH_PLUGINS}/fever"
    fi
    if [ ! -d "${TTRSS_PATH_PLUGINS}/nginx_xaccel/.git" ]; then
        git clone --depth=1 https://github.com/tt-rss/tt-rss-plugin-nginx-xaccel.git "${TTRSS_PATH_PLUGINS}/nginx_xaccel"
    fi

    mkdir -p "${TTRSS_PATH_THEMES}"
    if [ ! -d "${TTRSS_PATH_THEMES}/levito-feedly-git/.git" ]; then
        git clone --depth=1 https://github.com/levito/tt-rss-feedly-theme.git "${TTRSS_PATH_THEMES}/levito-feedly-git"
    fi
    if [ ! -d "${TTRSS_PATH_THEMES}/gravemind-feedly-git/.git" ]; then
        git clone --depth=1 https://github.com/Gravemind/tt-rss-feedlish-theme.git "${TTRSS_PATH_THEMES}/gravemind-feedly-git"
    fi

    for d in cache lock templates.local cache/export cache/feeds cache/images cache/upload cache/feed-icons feed-icons; do
        mkdir -p "${TTRSS_PATH}/${d}"
    done

    # Add initial config.
    cp "${TTRSS_PATH}/config.php-dist" "${TTRSS_PATH}/config.php"

    # Check if TTRSS_URL is undefined, and if so, use localhost as default.
    if [ -z "${TTRSS_URL}" ]; then
        TTRSS_URL=localhost
    fi

    if [ "$TTRSS_WITH_SELFSIGNED_CERT" = "1" ]; then
        # Make sure the TTRSS protocol is https now.
        TTRSS_PROTO=https
    fi

    # If no protocol is specified, use http as default.
    if [ -z "${TTRSS_PROTO}" ]; then
        TTRSS_PROTO=http
    fi

    # Add a leading colon (for the final URL) to the port.
    TTRSS_URL_PORT=""
    if [ -n "$TTRSS_PORT" ]; then
        case "$TTRSS_PORT" in
            :*) TTRSS_URL_PORT="$TTRSS_PORT" ;;
            *)  TTRSS_URL_PORT=":${TTRSS_PORT}" ;;
        esac
    fi

    # If we've been passed $TTRSS_SELF_URL as an env variable, then use that,
    # otherwise use the URL we constructed above.
    if [ -z "$TTRSS_SELF_URL" ]; then
        # Construct the final URL TTRSS will use.
        TTRSS_SELF_URL="${TTRSS_PROTO}://${TTRSS_URL}${TTRSS_URL_PORT}/"
    fi

    echo "Setup: URL is: $TTRSS_SELF_URL"

    # By default preserve user theme settings unless explicitly asked to reset.
    if [ -z "${TTRSS_THEME_RESET}" ]; then
        TTRSS_THEME_RESET=0
    fi

    # Patch URL path, PHP executable, and Nginx X-Accel prefix.
    echo "putenv('TTRSS_SELF_URL_PATH=$TTRSS_SELF_URL');" >> "${TTRSS_PATH}/config.php"
    echo "putenv('TTRSS_PHP_EXECUTABLE=/usr/bin/php');" >> "${TTRSS_PATH}/config.php"
    echo "putenv('TTRSS_NGINX_XACCEL_PREFIX=/');" >> "${TTRSS_PATH}/config.php"

    # Support forcing SELF_URL_PATH usage behind reverse proxies.
    if [ -n "${TTRSS_FORCE_SELF_URL_PATH_USAGE}" ] || [ -n "${TTRSS_SKIP_SELF_URL_PATH_CHECKS}" ]; then
        echo "Setup: Forcing SELF_URL_PATH usage"
        echo "putenv('TTRSS_FORCE_SELF_URL_PATH_USAGE=true');" >> "${TTRSS_PATH}/config.php"
    fi

    # Check if single user mode is selected
    if [ "$TTRSS_SINGLEUSER" = "true" ] || [ "$TTRSS_SINGLEUSER" = "1" ]; then
        echo "Single User mode Selected"
        echo "putenv('TTRSS_SINGLE_USER_MODE=1');" >> "${TTRSS_PATH}/config.php"
    fi

    # Enable system plugins (including nginx_xaccel for X-Accel-Redirect cache serving).
    if [ -n "${TTRSS_PLUGINS}" ]; then
        echo "Setup: Additional plugins: $TTRSS_PLUGINS"
        echo "putenv('TTRSS_PLUGINS=${TTRSS_PLUGINS}, auth_internal, note, nginx_xaccel');" >> "${TTRSS_PATH}/config.php"
    else
        echo "putenv('TTRSS_PLUGINS=auth_internal, note, nginx_xaccel');" >> "${TTRSS_PATH}/config.php"
    fi

    # Export variables for sub shells.
    export TTRSS_PATH
    export TTRSS_PATH_PLUGINS
    export TTRSS_THEME_RESET
}

setup_db()
{
    echo "Setup: Database"
    php -f /srv/ttrss-configure-db.php
    chown -R www-data:www-data "${TTRSS_PATH}"
    echo "Setup: Applying TT-RSS database schema migrations ..."
    s6-setuidgid www-data php "${TTRSS_PATH}/update.php" --update-schema=force-yes
    php -f /srv/ttrss-configure-plugin-mobilize.php
}

load_secret_files
setup_nginx
setup_ttrss
setup_db

echo "Setup: Applying updates ..."
/srv/update-ttrss.sh --no-start

echo "Setup: Done"
