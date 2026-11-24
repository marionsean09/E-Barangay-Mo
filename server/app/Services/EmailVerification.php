<?php

namespace App\Services;

use App\Mail\VerificationCodeMail;
use App\Models\User;
use App\Support\SecurityLog;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\RateLimiter;
use Throwable;

/**
 * One-time 6-digit codes sent by email to prove the user owns the address.
 *
 *  - Only a keyed hash of the code is stored, so a database leak reveals nothing usable.
 *  - A code expires after 10 minutes and allows 5 wrong guesses, then a new one is needed.
 *  - A new code can be sent at most once per minute per account,
 *    and at most 5 times per hour per email across sign-up, login and resend.
 */
class EmailVerification
{
    public const CODE_TTL_MINUTES = 10;

    public const MAX_ATTEMPTS = 5;

    public const RESEND_COOLDOWN_SECONDS = 60;

    public const MAX_EMAILS_PER_HOUR = 5;

    /** Seconds until another code may be sent (0 = now). */
    public function cooldownRemaining(User $user): int
    {
        if (! $user->verification_sent_at) {
            return 0;
        }

        $readyAt = $user->verification_sent_at->copy()->addSeconds(self::RESEND_COOLDOWN_SECONDS);

        return max(0, (int) ceil(now()->diffInSeconds($readyAt, false)));
    }

    /** Seconds until this inbox may receive another code (0 = now). Protects people from email flooding. */
    public function hourlyWait(string $email): int
    {
        $key = $this->inboxKey($email);

        return RateLimiter::tooManyAttempts($key, self::MAX_EMAILS_PER_HOUR)
            ? max(1, RateLimiter::availableIn($key))
            : 0;
    }

    /** Generates and emails a new code, unless a limit applies. Returns true if sent. */
    public function send(User $user): bool
    {
        if ($this->cooldownRemaining($user) > 0 || $this->hourlyWait($user->email) > 0) {
            return false;
        }

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $user->forceFill([
            'verification_code_hash' => $this->hash($code),
            'verification_expires_at' => now()->addMinutes(self::CODE_TTL_MINUTES),
            'verification_sent_at' => now(),
            'verification_attempts' => 0,
        ])->save();

        try {
            Mail::to($user->email)->send(new VerificationCodeMail($code, $user->full_name, self::CODE_TTL_MINUTES));
        } catch (Throwable $e) {
            // Nothing was delivered, so don't make the user wait a minute to retry.
            $user->forceFill(['verification_sent_at' => null])->save();

            throw $e;
        }

        // Counted only after delivery, so a mail outage doesn't use up the limit.
        RateLimiter::hit($this->inboxKey($user->email), 3600);

        SecurityLog::event('verification_code_sent', ['email' => SecurityLog::maskEmail($user->email)], $user->id);

        return true;
    }

    /** Checks a code. On success the email is marked verified and the code is cleared. */
    public function verify(User $user, string $code): bool
    {
        $usable = $user->verification_code_hash
            && $user->verification_expires_at?->isFuture()
            && $user->verification_attempts < self::MAX_ATTEMPTS;

        if (! $usable) {
            return false;
        }

        // Count the attempt before comparing. The limit is checked inside the
        // UPDATE itself, so parallel guesses can't slip past it.
        $counted = User::whereKey($user->id)
            ->where('verification_attempts', '<', self::MAX_ATTEMPTS)
            ->increment('verification_attempts');
        if ($counted === 0) {
            return false;
        }
        $user->verification_attempts++;

        if (! hash_equals($user->verification_code_hash, $this->hash($code))) {
            SecurityLog::event('verification_failed', ['attempts' => $user->verification_attempts], $user->id);

            return false;
        }

        $user->forceFill([
            'email_verified_at' => now(),
            'verification_code_hash' => null,
            'verification_expires_at' => null,
            'verification_attempts' => 0,
        ])->save();

        SecurityLog::event('email_verified', [], $user->id);

        return true;
    }

    private function inboxKey(string $email): string
    {
        return 'verification-inbox:'.hash('sha256', strtolower($email));
    }

    private function hash(string $code): string
    {
        return hash_hmac('sha256', $code, (string) config('app.key'));
    }
}
