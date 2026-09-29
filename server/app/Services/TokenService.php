<?php

namespace App\Services;

use App\Models\RefreshToken;
use App\Models\User;
use App\Support\SecurityLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Cookie;

/**
 * Access + refresh token flow.
 *
 *  - Access token: Sanctum token, 15 min, returned in JSON, kept in memory by
 *    the client and sent as "Authorization: Bearer ...".
 *  - Refresh token: 64 random bytes, 7 days, sent only as an httpOnly,
 *    Secure, SameSite=Strict cookie. Only its SHA-256 is stored.
 *  - Rotation: every refresh revokes the old refresh token and issues a new
 *    one in the same "family".
 *  - Reuse detection: presenting an already-revoked refresh token means it
 *    was stolen or replayed, so the whole family and its access tokens are
 *    revoked and the event is logged.
 */
class TokenService
{
    /** @return array{0: array, 1: Cookie} JSON payload and refresh cookie */
    public function issue(User $user, Request $request, ?string $family = null): array
    {
        $family ??= (string) Str::uuid();
        $plain = bin2hex(random_bytes(64));

        RefreshToken::create([
            'user_id' => $user->id,
            'token_hash' => hash('sha256', $plain),
            'family' => $family,
            'expires_at' => now()->addDays(config('security.refresh_token_days')),
            'ip' => $request->ip(),
            'user_agent' => Str::limit((string) $request->userAgent(), 250, ''),
        ]);

        return [$this->accessPayload($user, $family), $this->cookie($plain)];
    }

    /** @return array{0: array, 1: Cookie}|null */
    public function rotate(?string $plain, Request $request): ?array
    {
        if (! $plain) {
            return null;
        }

        $result = DB::transaction(function () use ($plain, $request) {
            $token = RefreshToken::where('token_hash', hash('sha256', $plain))
                ->lockForUpdate()
                ->first();

            if (! $token) {
                return 'invalid';
            }

            if ($token->revoked_at !== null) {
                $this->revokeFamily($token->user_id, $token->family);

                return $token;
            }

            if (! $token->isUsable()) {
                return 'expired';
            }

            // Old access tokens from this login stop working immediately.
            $token->user->tokens()->where('name', $this->tokenName($token->family))->delete();

            [$payload, $cookie] = $this->issue($token->user, $request, $token->family);

            $token->forceFill([
                'revoked_at' => now(),
                'replaced_by' => RefreshToken::where('family', $token->family)->latest('id')->value('id'),
            ])->save();

            return [$payload, $cookie];
        });

        // Logged outside the transaction so the audit row is kept either way.
        if ($result === 'invalid') {
            SecurityLog::event('refresh_invalid');
        } elseif ($result instanceof RefreshToken) {
            SecurityLog::event('refresh_token_reuse_detected', ['family' => $result->family], $result->user_id);
        }

        return is_array($result) ? $result : null;
    }

    public function revokeByCookie(?string $plain): void
    {
        if (! $plain) {
            return;
        }
        $token = RefreshToken::where('token_hash', hash('sha256', $plain))->first();
        if ($token) {
            $this->revokeFamily($token->user_id, $token->family);
        }
    }

    public function revokeFamily(int $userId, string $family): void
    {
        RefreshToken::where('user_id', $userId)
            ->where('family', $family)
            ->whereNull('revoked_at')
            ->update(['revoked_at' => now()]);

        User::find($userId)?->tokens()->where('name', $this->tokenName($family))->delete();
    }

    /** Sign the user out everywhere except the given login (used after a password change). */
    public function revokeOtherFamilies(User $user, ?string $keepFamily): void
    {
        RefreshToken::where('user_id', $user->id)
            ->when($keepFamily, fn ($q) => $q->where('family', '!=', $keepFamily))
            ->whereNull('revoked_at')
            ->update(['revoked_at' => now()]);

        $user->tokens()
            ->when($keepFamily, fn ($q) => $q->where('name', '!=', $this->tokenName($keepFamily)))
            ->delete();
    }

    public function familyOfCurrentToken(User $user): ?string
    {
        $name = $user->currentAccessToken()?->name;

        return $name && str_starts_with($name, 'access:') ? substr($name, 7) : null;
    }

    public function forgetCookie(): Cookie
    {
        $c = config('security.refresh_cookie');

        return Cookie::create($c['name'], '', 1, $c['path'], null, $c['secure'], true, false, $c['same_site']);
    }

    private function accessPayload(User $user, string $family): array
    {
        $minutes = config('security.access_token_minutes');
        $token = $user->createToken($this->tokenName($family), ['*'], now()->addMinutes($minutes));

        return [
            'accessToken' => $token->plainTextToken,
            'expiresIn' => $minutes * 60,
            'user' => $user->toApi(),
        ];
    }

    private function cookie(string $plain): Cookie
    {
        $c = config('security.refresh_cookie');
        $expires = now()->addDays(config('security.refresh_token_days'));

        // name, value, expire, path, domain, secure, httpOnly, raw, sameSite
        return Cookie::create($c['name'], $plain, $expires, $c['path'], null, $c['secure'], true, false, $c['same_site']);
    }

    private function tokenName(string $family): string
    {
        return 'access:'.$family;
    }
}
