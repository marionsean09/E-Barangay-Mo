-- Run as root AFTER `php artisan migrate --database=migrator` has created
-- the tables (table-level GRANTs need the tables to exist).
--
--   mysql -u root -p < server/database/sql/02_grant_app_privileges.sql

-- Normal application data: read, create, update. No DELETE.
GRANT SELECT, INSERT, UPDATE ON ebarangay.users         TO 'ebarangay_app'@'localhost';
GRANT SELECT, INSERT, UPDATE ON ebarangay.concerns      TO 'ebarangay_app'@'localhost';
GRANT SELECT, INSERT, UPDATE ON ebarangay.refresh_tokens TO 'ebarangay_app'@'localhost';
GRANT SELECT, INSERT         ON ebarangay.attachments   TO 'ebarangay_app'@'localhost';

-- Audit trail is append-only: the app can add entries but never edit or erase them.
GRANT INSERT ON ebarangay.audit_logs TO 'ebarangay_app'@'localhost';

-- Sanctum deletes access tokens on logout / rotation.
GRANT SELECT, INSERT, UPDATE, DELETE ON ebarangay.personal_access_tokens TO 'ebarangay_app'@'localhost';

FLUSH PRIVILEGES;

-- Evidence for the report:
SHOW GRANTS FOR 'ebarangay_app'@'localhost';
