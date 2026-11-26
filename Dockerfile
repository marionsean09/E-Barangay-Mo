# One production image: the Flutter web build is served by Laravel from the
# same origin as the API (/api). Used by Railway (see README "Deploy").

# ---- 1. Build the Flutter web app --------------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS web
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY lib lib
COPY assets assets
COPY web web
# Self-host CanvasKit instead of loading it from a third-party CDN.
# Public OAuth client ID. Railway passes its service variable as a build arg.
ARG GOOGLE_CLIENT_ID=""
RUN flutter build web --release --no-web-resources-cdn \
    --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID"

# ---- 2. Install PHP dependencies (no dev packages) ----------------------
FROM composer:2 AS vendor
WORKDIR /app
COPY server/composer.json server/composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction
COPY server/ ./
RUN composer dump-autoload --optimize --no-dev

# ---- 3. Runtime: PHP 8.3 + Apache ---------------------------------------
FROM php:8.3-apache

# Imagick converts any phone photo (HEIC, AVIF, PNG...) to a clean JPEG and
# strips EXIF/GPS (app/Services/ImageUpload.php). The installer pulls in
# ImageMagick with its HEIF/AVIF decoders.
COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions imagick \
    && php -r 'exit(extension_loaded("imagick") ? 0 : 1);'

RUN docker-php-ext-install pdo_mysql \
    && a2enmod rewrite headers \
    && sed -ri 's!/var/www/html!/var/www/html/public!g' \
        /etc/apache2/sites-available/*.conf /etc/apache2/apache2.conf \
    # Hide Apache/PHP versions from response headers and error pages.
    && printf 'ServerTokens Prod\nServerSignature Off\nTraceEnable Off\n' \
        > /etc/apache2/conf-enabled/zz-hardening.conf \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    # 15 MB per photo (ImageUpload::MAX_KB), up to 4 photos per submission.
    && printf 'expose_php=Off\nupload_max_filesize=16M\npost_max_size=64M\nmemory_limit=256M\n' \
        > "$PHP_INI_DIR/conf.d/app.ini"

WORKDIR /var/www/html
COPY --from=vendor /app ./
COPY --from=web /app/build/web ./public/
COPY docker/start.sh /usr/local/bin/start
RUN chmod +x /usr/local/bin/start \
    && chown -R www-data:www-data storage bootstrap/cache

CMD ["start"]
