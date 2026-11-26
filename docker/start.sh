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

# First admin on a fresh database: set ADMIN_EMAIL and ADMIN_PASSWORD once,
# deploy, then delete ADMIN_PASSWORD. Existing accounts are only promoted,
# their password is never overwritten. Runs as www-data so the log files it
# writes stay writable by Apache.
if [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
    su -p -s /bin/sh www-data -c 'php artisan user:create-admin "$ADMIN_EMAIL" --from-env' \
        || echo "Admin bootstrap failed; see the message above."
fi

# Runs the daily attachment retention job.
su -p -s /bin/sh www-data -c 'php artisan schedule:work' &

exec apache2-foreground
