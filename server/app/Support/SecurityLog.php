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

        Log::channel('security')->info($action, array_merge($details, [
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
            Log::channel('security')->error('audit_log_write_failed', ['error' => $e->getMessage()]);
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
