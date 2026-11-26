<?php

namespace App\Services;

use App\Mail\PasswordResetCodeMail;
use App\Models\User;
use App\Support\SecurityLog;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\RateLimiter;

/**
 * "Forgot password": a one-time 6-digit code emailed to the account's address.
 *
 *  - Only a keyed hash of the code is stored, so a database leak reveals nothing usable.
 *  - A code expires after 10 minutes and allows 5 wrong guesses, then a new one is needed.
 *  - A new code can be sent at most once per minute per account,
 *    and at most 5 times per hour per email.
 *  - The code is checked and cleared in one step, so it works only once.
 */
class PasswordReset
{
    public const CODE_TTL_MINUTES = 10;

    public const MAX_ATTEMPTS = 5;

    public const RESEND_COOLDOWN_SECONDS = 60;

    public const MAX_EMAILS_PER_HOUR = 5;

    /** Emails a new code, unless a limit applies. Returns true if sent. Mail errors are thrown. */
    public function send(User $user): bool
    {
        $key = $this->inboxKey($user->email);
        $coolingDown = $user->reset_sent_at
            && $user->reset_sent_at->copy()->addSeconds(self::RESEND_COOLDOWN_SECONDS)->isFuture();

        if ($coolingDown || RateLimiter::tooManyAttempts($key, self::MAX_EMAILS_PER_HOUR)) {
            SecurityLog::event('password_reset_limited', ['email' => SecurityLog::maskEmail($user->email)], $user->id);

            return false;
        }

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $user->forceFill([
            'reset_code_hash' => $this->hash($code),
            'reset_expires_at' => now()->addMinutes(self::CODE_TTL_MINUTES),
            'reset_sent_at' => now(),
            'reset_attempts' => 0,
        ])->save();

        try {
            Mail::to($user->email)->send(new PasswordResetCodeMail($code, $user->full_name, self::CODE_TTL_MINUTES));
        } catch (\Throwable $e) {
            // Nothing was delivered, so don't make the user wait a minute to retry.
            $user->forceFill(['reset_sent_at' => null])->save();

            throw $e;
        }

        // Counted only after delivery, so a mail outage doesn't use up the limit.
        RateLimiter::hit($key, 3600);

        SecurityLog::event('password_reset_requested', ['email' => SecurityLog::maskEmail($user->email)], $user->id);

        return true;
    }

    /** Checks a code. On success the code is cleared, so it can't be used again. */
    public function consume(User $user, string $code): bool
    {
        $usable = $user->reset_code_hash
            && $user->reset_expires_at?->isFuture()
            && $user->reset_attempts < self::MAX_ATTEMPTS;

        if (! $usable) {
            return false;
        }

        // Count the attempt before comparing. The limit is checked inside the
        // UPDATE itself, so parallel guesses can't slip past it.
        $counted = User::whereKey($user->id)
            ->where('reset_attempts', '<', self::MAX_ATTEMPTS)
            ->increment('reset_attempts');
        if ($counted === 0) {
            return false;
        }
        $user->reset_attempts++;

        if (! hash_equals($user->reset_code_hash, $this->hash($code))) {
            SecurityLog::event('password_reset_failed', ['attempts' => $user->reset_attempts], $user->id);

            return false;
        }

        // Cleared only if the stored hash is still this one, so two parallel
        // requests with the same code can't both succeed.
        $cleared = User::whereKey($user->id)
            ->where('reset_code_hash', $user->reset_code_hash)
            ->update(['reset_code_hash' => null, 'reset_expires_at' => null, 'reset_attempts' => 0]);

        if ($cleared !== 1) {
            return false;
        }

        $user->refresh();

        return true;
    }

    private function inboxKey(string $email): string
    {
        return 'reset-inbox:'.hash('sha256', strtolower($email));
    }

    private function hash(string $code): string
    {
        // Prefixed so the same digits never hash the same as a verification code.
        return hash_hmac('sha256', 'password-reset|'.$code, (string) config('app.key'));
    }
}
