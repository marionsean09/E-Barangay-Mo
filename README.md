# eBarangay Mo

A web app for barangay services. Residents file complaints, suggestions,
blotter reports and document requests (with ID uploads). Barangay staff
(admins) review them, set schedules and update their status.

| Layer | Technology |
|---|---|
| Frontend | Flutter 3 (web build), `http` package |
| Backend / API | PHP 8.2+ · Laravel 12 · Laravel Sanctum |
| Database | MySQL 8 (InnoDB) |
| Hosting | Railway (Singapore): one container for app + API, private MySQL |

```
flutter app (lib/)  ──HTTPS/JSON──►  Laravel API (server/)  ──private network──►  MySQL
```

Security controls and where each one lives in the code: [docs/security-controls.md](docs/security-controls.md).

---

## 1. Requirements

- PHP 8.2+ with `pdo_mysql`, `fileinfo`, `openssl`, `mbstring` (XAMPP's PHP works)
- Composer 2
- MySQL 8.0.16+ or MariaDB 10.2+ (needed for `CHECK` constraints). XAMPP's
  MariaDB works for local development; production uses MySQL 8 on Railway.
- Flutter 3.38+ (stable)

## 2. Database setup (once)

Start MySQL, then create the database and the two accounts. Edit the two
`CHANGE_ME` passwords in the file first.

```bash
mysql -u root -p < server/database/sql/01_create_database_and_users.sql
```

| Account | Used by | Privileges |
|---|---|---|
| `ebarangay_migrator` | `php artisan migrate` only | create/alter tables |
| `ebarangay_app` | the running app | SELECT/INSERT/UPDATE on its tables, INSERT-only on `audit_logs`, no DDL |

## 3. Backend setup

```bash
cd server
composer install
cp .env.example .env
php artisan key:generate          # APP_KEY also encrypts PII fields and uploads
```

Edit `server/.env` and fill in `DB_PASSWORD` (app user) and
`DB_MIGRATOR_PASSWORD` (migrator). `.env` is gitignored, so never commit it.

```bash
php artisan migrate --database=migrator                                  # creates tables
mysql -u root -p < database/sql/02_grant_app_privileges.sql             # grants for the app user
php artisan serve                                                         # http://localhost:8000
```

## 4. Frontend (development)

In another terminal, from the project root:

```bash
flutter pub get
flutter run -d chrome --web-port 5000 --dart-define=API_URL=http://localhost:8000/api/
```

Port 5000 matters: it is the origin allowed by CORS (`ALLOWED_ORIGINS` in `.env`).
Always use `localhost`, not `127.0.0.1`. Browsers treat them as different
sites, and the refresh cookie would be dropped.

## 5. Create an admin

Register in the app, then promote the account from the server console.
There is no API endpoint that can change a role.

```bash
cd server
php artisan user:role you@example.com admin
```

## 6. Run the security test suite

```bash
cd server
php artisan test
```

23 tests attack the API and check each one is blocked: SQL injection, stored
XSS, wrong-role access, reading another user's ID photo, refresh-token
replay, CSRF from another origin, login brute force, disguised file upload,
and more. The tests use an in-memory SQLite database, so MySQL isn't needed.

Dependency scans:

```bash
cd server && composer audit       # PHP packages
osv-scanner --lockfile=pubspec.lock   # Flutter packages (https://google.github.io/osv-scanner/)
```

## 7. Production build (same origin)

```bash
flutter build web --release --no-web-resources-cdn
cp -r build/web/* server/public/
```

Laravel then serves the app at `/` and the API at `/api` on one domain, so
the app needs no `API_URL`.

## 8. Deploy to Railway

1. Create a Railway project in the **Singapore** region with a **MySQL** service.
2. Add a service from this GitHub repo. Railway builds the root `Dockerfile`
   (Flutter build, then Composer, then PHP 8.3 + Apache).
3. Add a **volume** mounted at `/var/www/html/storage/app/private` (encrypted uploads).
4. Connect to the MySQL service and run both SQL files, replacing `'localhost'`
   with `'%'` (containers connect over Railway's private network).
5. Set the service **Variables** (these are the secrets; they never go in git):

   ```
   APP_ENV=production
   APP_DEBUG=false
   APP_KEY=base64:...            # php artisan key:generate --show
   APP_URL=https://<your-domain>
   DB_CONNECTION=mysql
   DB_HOST=${{MySQL.MYSQLHOST}}  # *.railway.internal, not reachable from the internet
   DB_PORT=${{MySQL.MYSQLPORT}}
   DB_DATABASE=ebarangay
   DB_USERNAME=ebarangay_app
   DB_PASSWORD=...
   DB_MIGRATOR_USERNAME=ebarangay_migrator
   DB_MIGRATOR_PASSWORD=...
   HASH_DRIVER=argon2id
   SESSION_DRIVER=array
   CACHE_STORE=file
   LOG_CHANNEL=stderr
   ALLOWED_ORIGINS=https://<your-domain>
   FORCE_HTTPS=true
   RUN_MIGRATIONS=true
   ```

6. Leave the MySQL service's public TCP proxy **disabled**, so only the app can reach it.
7. Optional: put Cloudflare in front of a custom domain for WAF and DDoS protection.

## Project layout

```
lib/                     Flutter app
  services/api_service.dart   all HTTP calls, token handling
  models/                     AppUser, Concern
server/                  Laravel API
  routes/api.php              every endpoint + its middleware
  app/Http/Middleware/        RBAC, security headers, CSRF origin check, HTTPS
  app/Http/Requests/          input validation per endpoint
  app/Policies/               object-level access (owner or admin)
  app/Services/               token rotation, encrypted file storage
  database/migrations/        schema (ERD source of truth)
  database/sql/               least-privilege MySQL accounts
  tests/Feature/              security tests
Dockerfile               production image
.github/workflows/       CI: dependency + secret scanning, tests
```
