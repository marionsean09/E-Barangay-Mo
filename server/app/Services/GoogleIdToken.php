<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Checks a "Sign in with Google" ID token. Google's tokeninfo endpoint
 * verifies the signature; this class then checks that the token was issued
 * by Google, for THIS app, is unexpired, and that Google verified the email.
 * The client's word is never trusted: only what Google confirms.
 */
class GoogleIdToken
{
    private const ISSUERS = ['accounts.google.com', 'https://accounts.google.com'];

    public function isConfigured(): bool
    {
        return (string) config('services.google.client_id') !== '';
    }

    /** @return array{email: string, name: string}|null */
    public function verify(string $idToken): ?array
    {
        try {
            $response = Http::timeout(10)->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $idToken]);
        } catch (Throwable) {
            return null;
        }

        if (! $response->ok()) {
            return null;
        }

        $claims = $response->json();
        $valid = is_array($claims)
            && hash_equals((string) config('services.google.client_id'), (string) ($claims['aud'] ?? ''))
            && in_array($claims['iss'] ?? null, self::ISSUERS, true)
            && (int) ($claims['exp'] ?? 0) > now()->timestamp
            && in_array($claims['email_verified'] ?? null, [true, 'true'], true)
            && filter_var($claims['email'] ?? null, FILTER_VALIDATE_EMAIL);

        if (! $valid) {
            return null;
        }

        return [
            'email' => strtolower($claims['email']),
            'name' => (string) ($claims['name'] ?? ''),
        ];
    }
}
