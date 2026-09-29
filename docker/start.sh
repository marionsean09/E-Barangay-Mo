#!/bin/sh
set -e

# Railway tells the container which port to listen on.
PORT="${PORT:-8080}"
sed -ri "s/Listen [0-9]+/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf

# The uploads volume is mounted at runtime, so fix ownership here.
mkdir -p storage/app/private storage/logs storage/framework/cache storage/framework/views
chown -R www-data:www-data storage

# Secrets come from Railway variables, never from a committed .env file.
if [ "$RUN_MIGRATIONS" = "true" ]; then
    php artisan migrate --force --database=migrator
fi

php artisan config:cache

exec apache2-foreground
