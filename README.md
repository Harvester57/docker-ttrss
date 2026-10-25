# docker-ttrss

This Dockerfile installs Tiny Tiny RSS (TT-RSS) with the following features:

- Integrated [Feedly-ish theme](https://github.com/Gravemind/tt-rss-feedlish-theme) for supporting latest TT-RSS versions
- Based on [Alpine Linux](https://hub.docker.com/_/alpine/) (`3.24.3`) and native [s6-overlay](https://github.com/just-containers/s6-overlay) (`v3`) as the supervisor
- Using PHP 8.5 and Nginx 1.30
- Small and lightweight image size
- Rolling release support: Updates TT-RSS and database schema automatically every day
- Works nicely behind a reverse proxy (e.g. Nginx or `nginx-proxy`), e.g. to use for Let's Encrypt TLS certificates
- Integrated [Feedly theme](https://github.com/levito/tt-rss-feedly-theme)
- Integrated [FeedIron plugin](https://github.com/feediron/ttrss_plugin-feediron) to modify feeds
- Integrated [Mobilize plugin](https://github.com/sepich/tt-rss-mobilize) for using Readability, Instapaper + Google Mobilizer
- Integrated [Fever API plugin](https://github.com/DigitalDJ/tinytinyrss-fever-plugin) and [Nginx X-Accel plugin](https://github.com/tt-rss/tt-rss-plugin-nginx-xaccel)
- Optional: Self-signed 4096-bit RSA TLS certificate for accessing TT-RSS via https
- Originally was based on [clue/docker-ttrss](https://github.com/clue/docker-ttrss) and [x86dev/docker-ttrss](https://github.com/x86dev/docker-ttrss)

This docker image allows you to run the [Tiny Tiny RSS](https://tt-rss.org/) feed reader.
Keep your feed history to yourself and access your RSS and Atom feeds from everywhere.
You can access it through an easy to use web interface on your desktop, your mobile browser,
or using one of the available apps.

## Quickstart with Docker Compose (Recommended)

A ready-to-use `docker-compose.yml` is included in the repository with persistent volumes for PostgreSQL 18 (`postgres:18-alpine`) and the TT-RSS installation (`/var/www/ttrss`):

```bash
docker compose up -d
```

By default, this exposes TT-RSS on `127.0.0.1:8888` (configurable via `TTRSS_LISTEN_ADDR` and `TTRSS_LISTEN_PORT`).

## Quickstart with `docker run`

Start up a PostgreSQL database container with a persistent volume:

```bash
docker run -d --name tinydatabase \
  -e POSTGRES_USER=ttrss \
  -e POSTGRES_PASSWORD=ttrss \
  -e POSTGRES_DB=ttrss \
  -v ttrss-pgdata:/var/lib/postgresql \
  postgres:18-alpine
```

Next, run the TT-RSS instance:

```bash
docker run -d --link tinydatabase:db \
  -e DB_HOST=db \
  -e TTRSS_PORT=8080 \
  -p 127.0.0.1:8888:8080 \
  --name ttrss-new \
  ghcr.io/harvester57/docker-ttrss:main
```

## Accessing your Tiny Tiny RSS (TT-RSS)

The default login credentials (when `TTRSS_SINGLEUSER` is not enabled) are:

```text
Username: admin
Password: password
```

You are strongly recommended to change those immediately.

## Use self-signed certificates (SSL/TLS)

For enabling SSL/TLS support with a self-signed certificate you have to add `-e TTRSS_WITH_SELFSIGNED_CERT=1 -p 443:4443`
when running your TT-RSS container. Then you can access TT-RSS via: `https://<yourhost>`.

**Warning: Running services unencrypted on the Internet is not recommended!**

## Database configuration

Whenever you run TT-RSS, it will check your database setup. It assumes the following
default configuration, which can be changed by passing the following additional environment variables:

```bash
-e DB_HOST=tinydatabase
-e DB_PORT=5432
-e DB_NAME=ttrss
-e DB_USER=ttrss
-e DB_PASS=ttrss
```

By default, a PostgreSQL database is used.

## Useful stuff to know

### Single User mode

In case you are running behind a proxy that has basic auth and you do not wish to use
TT-RSS auth, you can set the environment variable `TTRSS_SINGLEUSER=true` and it
will change the setup to single user mode.

### Automatic updates

This container checks for updates of TT-RSS and the accompanied plugins/themes every day via its update script (`root/srv/update-ttrss.sh`), including applying any new database schema migrations via `update.php --update-schema=force-yes`.

By default the update script checks every 24 hours if there are updates for TT-RSS,
the plugins, or the theme(s) available.
