-- Run ONCE as the MySQL root user, e.g.:
--   mysql -u root -p < server/database/sql/01_create_database_and_users.sql
--
-- Replace both CHANGE_ME passwords first, and put the same values in
-- server/.env (never commit .env).
--
-- Two accounts = least privilege:
--   ebarangay_migrator  owns the schema (used only by `php artisan migrate`)
--   ebarangay_app       what the running app uses: no DDL, no DROP, and DELETE
--                       only where the app really needs it (expired tokens)

CREATE DATABASE IF NOT EXISTS ebarangay
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'ebarangay_migrator'@'localhost' IDENTIFIED BY 'CHANGE_ME_MIGRATOR';
GRANT CREATE, ALTER, DROP, INDEX, REFERENCES, SELECT, INSERT, UPDATE, DELETE
  ON ebarangay.* TO 'ebarangay_migrator'@'localhost';

CREATE USER IF NOT EXISTS 'ebarangay_app'@'localhost' IDENTIFIED BY 'CHANGE_ME_APP';

FLUSH PRIVILEGES;
