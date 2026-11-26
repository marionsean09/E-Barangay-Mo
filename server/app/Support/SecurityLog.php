<?php

namespace App\Support;

use App\Models\AuditLog;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Security-relevant events go to two places:
 *  - storage/logs/security-*.log (for monitoring), and
 *  - the append-only audit_logs table (for the admin trail).
 *
 * Passwords and tokens are never passed in; emails are masked.
 */
class SecurityLog
{
    public static function event(string $action, array $details = [], ?int $userId = null, ?string $targetType = null, ?int $targetId = null): void
    {
        $request = request();
        $userId ??= $request?->user()?->id;
        $ip = $request?->ip();

        self::write('info', $action, array_merge($details, [
            'user_id' => $userId,
            'ip' => $ip,
            'path' => $request?->path(),
        ]));

        try {
            AuditLog::create([
                'user_id' => $userId,
                'action' => $action,
                'target_type' => $targetType,
                'target_id' => $targetId,
                'details' => $details ?: null,
                'ip' => $ip,
            ]);
        } catch (Throwable $e) {
            // Logging must never break the request it is describing.
            self::write('error', 'audit_log_write_failed', ['error' => $e->getMessage()]);
        }
    }

    /**
     * Writes to the security log file. If the file can't be written (e.g. it
     * was created by root from a console session), the entry goes to stderr,
     * which the host keeps (Railway's deploy logs), instead of failing the request.
     */
    private static function write(string $level, string $message, array $context): void
    {
        try {
            Log::channel('security')->log($level, $message, $context);
        } catch (Throwable $e) {
            try {
                Log::channel('stderr')->log($level, $message, $context + ['security_log_error' => $e->getMessage()]);
            } catch (Throwable) {
                // Nowhere left to write; the audit_logs row is still attempted.
            }
        }
    }

    public static function maskEmail(?string $email): string
    {
        if (! $email || ! str_contains($email, '@')) {
            return '***';
        }
        [$name, $domain] = explode('@', $email, 2);

        return mb_substr($name, 0, 2).'***@'.$domain;
    }
}
