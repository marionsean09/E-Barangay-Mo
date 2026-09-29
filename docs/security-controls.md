# Security controls → code → evidence

Each control from the project brief (section 3.5) with the file that implements
it and the automated test that proves it (`cd server && php artisan test`).
Use these as the "code excerpt + test" evidence in the report. Screenshots from
the running app are still needed for the demo parts.

## A. Frontend

| Control | Implementation | Evidence |
|---|---|---|
| XSS prevention | Flutter paints text on a canvas and never parses API data as HTML. The API only returns JSON with `X-Content-Type-Options: nosniff` and `CSP: default-src 'none'`. | `ConcernSecurityTest::test_xss_payload_is_stored_as_plain_text_and_served_as_json`. Demo: submit `<img src=x onerror=alert(1)>` as a complaint title and it shows as plain text. |
| CSRF | API calls authenticate with the `Authorization` header, which cross-site pages can't set. The two cookie endpoints (`/api/auth/refresh`, `/api/auth/logout`) have a SameSite=Strict cookie, an Origin allowlist and a required `X-Requested-With` header. See `server/app/Http/Middleware/VerifyOrigin.php`. | `AuthSecurityTest::test_cookie_endpoints_reject_cross_site_requests` |
| Clickjacking | `X-Frame-Options: DENY` + `frame-ancestors 'none'` (`SecurityHeaders.php`, `public/.htaccess`) | `test_security_headers_are_present`, plus the browser DevTools Network tab |
| CSP | `config/security.php` → `csp_app` for the Flutter page, `csp_api` for JSON | DevTools Console shows no CSP violations; check with securityheaders.com |
| No client-side secrets | The bundle only knows the API URL. No DB credentials or API keys exist in `lib/`. | `grep` the built `main.dart.js` (see README section 7) |

## B. Middleware / API

| Control | Implementation | Evidence |
|---|---|---|
| Access + refresh tokens | Access token: 15-minute Sanctum token held in memory (`lib/services/api_service.dart`). Refresh token: 7 days, httpOnly + Secure + SameSite=Strict cookie, SHA-256 stored. Rotation on every use, and reuse revokes the whole login (`server/app/Services/TokenService.php`). | `test_refresh_token_is_an_httponly_strict_secure_cookie_not_in_json`, `test_access_token_expires_after_fifteen_minutes`, `test_refresh_rotates_the_token_and_detects_reuse`, `test_logout_revokes_the_refresh_token` |
| RBAC (server-side) | `role:admin` middleware (`EnsureRole.php`) on `/api/admin/*`, plus `ConcernPolicy` per object. `role` is not mass-assignable, and admins are only created with `php artisan user:role`. | `test_resident_cannot_use_admin_endpoints`, `test_resident_cannot_open_another_residents_id_photo`, `test_client_cannot_register_itself_as_admin` |
| Rate limiting | `AppServiceProvider::configureRateLimiting()`: login 5/min per email+IP and 20/min per IP; register 10/h; submit 5/min; API 120/min | `test_login_is_rate_limited_after_five_attempts` |
| Input validation | One FormRequest per endpoint (`server/app/Http/Requests/`). Uploads are checked by magic bytes (`finfo`), not extension. | `test_non_image_upload_disguised_as_jpg_is_rejected`, `test_invalid_status_is_rejected_by_validation`, `test_request_requires_all_four_documents` |
| CORS | `config/cors.php`: exact origins from `ALLOWED_ORIGINS`, never `*` | `test_cors_only_allows_the_configured_origin` |
| Security headers | `SecurityHeaders.php` (helmet equivalent): HSTS, nosniff, XFO, Referrer-Policy, Permissions-Policy, COOP, CORP; `X-Powered-By` removed | `test_security_headers_are_present` |

## C. Backend / database

| Control | Implementation | Evidence |
|---|---|---|
| Injection | Eloquent / query builder only (bound parameters), with no raw SQL built from user input | `test_sql_injection_payloads_do_not_bypass_login`, `test_invalid_status_is_rejected_by_validation` |
| Password storage | Argon2id (`HASH_DRIVER=argon2id`) via the `hashed` cast. Unknown emails still run a hash check, so response timing doesn't reveal which accounts exist. | `test_password_is_stored_as_salted_argon2id_hash` |
| Data integrity | FKs, ENUMs and `CHECK` constraints (`database/migrations`). Transactions for concern + attachments and for admin update + audit row. SHA-256 checksum verified on every file download. | `test_admin_can_view_and_update_and_change_is_audited` |
| Data in transit | `ForceHttps` middleware (301 redirect) + HSTS + TLS terminated by Railway/Cloudflare. MySQL is only on Railway's private network, and `MYSQL_ATTR_SSL_CA` is available to require TLS. | Response headers on the deployed URL |
| Data at rest | `description`/`purpose` use the `encrypted` cast. Uploaded IDs are encrypted with AES-256 before writing to a private disk. Least-privilege `ebarangay_app` DB user (`database/sql/`). | `test_sensitive_text_and_uploaded_ids_are_encrypted_at_rest`, `SHOW GRANTS FOR 'ebarangay_app'@'localhost'` |
| Secrets | `.env` gitignored, `.env.example` has no values, production secrets in Railway Variables. The old Appwrite IDs in `lib/` were public project IDs, not secrets. | `git check-ignore server/.env`, gitleaks job in `.github/workflows/security.yml` |
| Logging | `SecurityLog` writes to the `security` log channel and the append-only `audit_logs` table: login_failed/success, permission_denied, rate_limited, csrf_blocked, refresh_token_reuse_detected, credentials_changed, concern_updated. Emails are masked and passwords/tokens are never logged (`dontFlash`). | `test_login_fails_with_generic_message_and_is_logged` |

## D. Bonus hardening

| Item | Status |
|---|---|
| Automated dependency scanning in CI | `.github/workflows/security.yml` (composer audit, OSV-Scanner, gitleaks) + `.github/dependabot.yml` |
| Security headers scan | Run securityheaders.com / Mozilla Observatory on the deployed URL and screenshot the result |
| MFA, WAF rules | Not implemented. Cloudflare WAF is possible with a custom domain. |

## Accepted residual risks

- **`'unsafe-inline'` in `style-src`**: Flutter web injects inline styles. Scripts stay locked to `'self'`.
- **`fonts.gstatic.com` in `font-src`/`connect-src`**: Flutter downloads fallback glyph fonts for characters missing from the bundled fonts.
- **Mobile builds**: only browsers keep the httpOnly refresh cookie, so the web app is the supported client. Android/iOS sessions last the 15-minute access-token lifetime.
- **Refresh race**: two tabs refreshing at the same moment look like token reuse and force a re-login. This fails safe.
- **Local PHP 8.2.12 (XAMPP)** is affected by CVE-2024-4577 when PHP runs as CGI on Windows. Development uses `php artisan serve` (CLI server), and production uses the patched `php:8.3-apache` image.
