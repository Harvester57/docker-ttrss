#!/bin/sh

TTRSS_PATH=/var/www/ttrss
TTRSS_PATH_THEMES=${TTRSS_PATH}/themes.local
TTRSS_PATH_PLUGINS=${TTRSS_PATH}/plugins.local

migrate_legacy_plugin_remotes()
{
    find "${TTRSS_PATH_PLUGINS}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r PLUGIN; do
        if [ -d "${PLUGIN}/.git" ]; then
            ORIGIN_URL="$(git -C "${PLUGIN}" config --get remote.origin.url || true)"
            NEW_ORIGIN_URL=""
            case "$ORIGIN_URL" in
                https://git.tt-rss.org/fox/ttrss-*.git)
                    NEW_ORIGIN_URL="https://github.com/tt-rss/tt-rss-plugin-${ORIGIN_URL#'https://git.tt-rss.org/fox/ttrss-'}"
                    ;;
                https://gitlab.tt-rss.org/tt-rss/plugins/ttrss-*.git)
                    NEW_ORIGIN_URL="https://github.com/tt-rss/tt-rss-plugin-${ORIGIN_URL#'https://gitlab.tt-rss.org/tt-rss/plugins/ttrss-'}"
                    ;;
                https://dev.tt-rss.org/tt-rss/ttrss-*.git)
                    NEW_ORIGIN_URL="https://github.com/tt-rss/tt-rss-plugin-${ORIGIN_URL#'https://dev.tt-rss.org/tt-rss/ttrss-'}"
                    ;;
                https://dev.tt-rss.org/tt-rss/plugins/ttrss-*.git)
                    NEW_ORIGIN_URL="https://github.com/tt-rss/tt-rss-plugin-${ORIGIN_URL#'https://dev.tt-rss.org/tt-rss/plugins/ttrss-'}"
                    ;;
            esac

            if [ -n "$NEW_ORIGIN_URL" ]; then
                echo "Updating: Migrating plugin remote ${ORIGIN_URL} -> ${NEW_ORIGIN_URL}"
                git -C "${PLUGIN}" remote set-url origin "${NEW_ORIGIN_URL}"
            fi
        fi
    done
}

update_ttrss()
{
    if [ -n "$TTRSS_GIT_TAG" ] || [ -n "$TTRSS_GIT_COMMIT" ]; then
        echo "Updating Tiny Tiny RSS disabled (pinned ref configured)"
        return
    fi

    echo "Updating: Tiny Tiny RSS"
    ( cd ${TTRSS_PATH} && git pull origin HEAD )
    if [ -f "${TTRSS_PATH}/update.php" ]; then
        if [ "$(id -u)" = "0" ]; then
            s6-setuidgid www-data php "${TTRSS_PATH}/update.php" --update-schema=force-yes
        else
            php "${TTRSS_PATH}/update.php" --update-schema=force-yes
        fi
    fi
}

update_plugin_mobilize()
{
    if [ -d "${TTRSS_PATH_PLUGINS}/mobilize/.git" ]; then
        echo "Updating: Mobilize plugin"
        ( cd ${TTRSS_PATH_PLUGINS}/mobilize && git pull origin HEAD )

        # Patch ttrss-mobilize plugin for PHP short open tags.
        sed -i -e "s/<?$/<?php/g" ${TTRSS_PATH_PLUGINS}/mobilize/m.php
    fi
}

update_plugin_feediron()
{
    if [ -d "${TTRSS_PATH_PLUGINS}/feediron/.git" ]; then
        echo "Updating: FeedIron"
        ( cd ${TTRSS_PATH_PLUGINS}/feediron && git pull origin HEAD )

        # Patch PHP 8.4/8.5 deprecations in feediron if present.
        if [ -f "${TTRSS_PATH_PLUGINS}/feediron/init.php" ]; then
            sed -i -e 's/\$headers = \$http_response_header;/$headers = function_exists("http_get_last_response_headers") ? (http_get_last_response_headers() ?? []) : ($http_response_header ?? []);/g' \
                "${TTRSS_PATH_PLUGINS}/feediron/init.php"
        fi
        if [ -f "${TTRSS_PATH_PLUGINS}/feediron/filters/fi_mod_readability/php-readability/Readability.php" ]; then
            sed -i -e 's/protected function grabArticle(\\DOMElement \$page = null)/protected function grabArticle(?\\DOMElement $page = null)/g' \
                "${TTRSS_PATH_PLUGINS}/feediron/filters/fi_mod_readability/php-readability/Readability.php"
        fi
    fi
}

update_plugin_fever()
{
    if [ -d "${TTRSS_PATH_PLUGINS}/fever/.git" ]; then
        echo "Updating: Fever API plugin"
        ( cd ${TTRSS_PATH_PLUGINS}/fever && git pull origin HEAD )
    fi
}

update_plugin_nginx_xaccel()
{
    if [ -d "${TTRSS_PATH_PLUGINS}/nginx_xaccel/.git" ]; then
        echo "Updating: Nginx X-Accel plugin"
        ( cd ${TTRSS_PATH_PLUGINS}/nginx_xaccel && git pull origin HEAD )
    fi
}

update_themes()
{
    echo "Updating: Themes"

    ( cd ${TTRSS_PATH_THEMES}/levito-feedly-git && git pull origin HEAD )
    ( cd ${TTRSS_PATH_THEMES}/gravemind-feedly-git && git pull origin HEAD )

    cd ${TTRSS_PATH_THEMES}

    # Link Levito theme to TTRSS.
    ln -f -s ${TTRSS_PATH_THEMES}/levito-feedly-git/feedly
    ln -f -s ${TTRSS_PATH_THEMES}/levito-feedly-git/feedly.css

    # Link Gravemind theme to TTRSS.
    ln -f -s ${TTRSS_PATH_THEMES}/gravemind-feedly-git/feedlish.css
    ln -f -s ${TTRSS_PATH_THEMES}/gravemind-feedly-git/feedlish.css.map
    ln -f -s ${TTRSS_PATH_THEMES}/gravemind-feedly-git/feedlish-night.css
    ln -f -s ${TTRSS_PATH_THEMES}/gravemind-feedly-git/feedlish-night.css.map
}

update_common()
{
    if [ "$(id -u)" != "0" ]; then
        return
    fi

    if [ -z "$MY_ROOT_UID" ]; then
        MY_ROOT_UID=0
    fi
    if [ -z "$MY_ROOT_GID" ]; then
        MY_ROOT_GID=0
    fi

    PHP_SUFFIX="${PHP_VER:-85}"

    echo "Updating: Updating permissions"
    for CUR_DIR in /etc/nginx "/etc/php${PHP_SUFFIX}" /var/lib/nginx /etc/services.d; do
        if [ -d "${CUR_DIR}" ]; then
            chown -R ${MY_ROOT_UID}:${MY_ROOT_GID} ${CUR_DIR}
        fi
    done

    chown -R www-data:www-data ${TTRSS_PATH}

    echo "Updating: Updating permissions done"
}

migrate_legacy_plugin_remotes
update_ttrss
update_plugin_mobilize
update_plugin_feediron
update_plugin_fever
update_plugin_nginx_xaccel
update_themes
update_common

echo "Update: Done"

if [ "$1" != "--no-start" ]; then
    echo "Update: Starting all ..."
fi

if [ "$1" = "--wait-exit" ]; then
    UPDATE_WAIT_TIME=$2
    if [ -z "$UPDATE_WAIT_TIME" ]; then
        UPDATE_WAIT_TIME=24h # Default is to check every day (24 hours).
    fi
    echo "Update: Sleeping for $UPDATE_WAIT_TIME ..."
    sleep ${UPDATE_WAIT_TIME}
fi
