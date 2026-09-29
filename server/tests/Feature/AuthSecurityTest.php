<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthSecurityTest extends TestCase
{
    use RefreshDatabase;

    private const JSON = ['Accept' => 'application/json', 'X-Requested-With' => 'XMLHttpRequest'];

    private function register(array $overrides = []): \Illuminate\Testing\TestResponse
    {
        return $this->postJson('/api/auth/register', array_merge([
            'full_name' => 'Juan Dela Cruz',
            'email' => 'juan@example.com',
            'password' => 'Secret123',
        ], $overrides));
    }

    public function test_password_is_stored_as_salted_argon2id_hash(): void
    {
        $this->register()->assertCreated();
        $this->register(['email' => 'maria@example.com'])->assertCreated();

        $hashes = User::pluck('password');
        $this->assertStringStartsWith('$argon2id$', $hashes[0]);
        // Same password, different salt => different hash.
        $this->assertNotEquals($hashes[0], $hashes[1]);
    }

    public function test_client_cannot_register_itself_as_admin(): void
    {
        $this->register(['role' => 'admin'])->assertCreated()->assertJsonPath('user.role', 'resident');
    }

    public function test_refresh_token_is_an_httponly_strict_secure_cookie_not_in_json(): void
    {
        $response = $this->register()->assertCreated();

        $cookie = $response->getCookie('ebm_refresh', false);
        $this->assertNotNull($cookie);
        $this->assertTrue($cookie->isHttpOnly());
        $this->assertTrue($cookie->isSecure());
        $this->assertSame('strict', $cookie->getSameSite());
        $this->assertSame('/api/auth', $cookie->getPath());
        $this->assertStringNotContainsString($cookie->getValue(), $response->getContent());
    }

    public function test_login_fails_with_generic_message_and_is_logged(): void
    {
        $this->register();

        $this->postJson('/api/auth/login', ['email' => 'juan@example.com', 'password' => 'wrong-pass1'])
            ->assertStatus(401)
            ->assertExactJson(['message' => 'Invalid email or password.']);

        $this->postJson('/api/auth/login', ['email' => 'nobody@example.com', 'password' => 'wrong-pass1'])
            ->assertStatus(401)
            ->assertExactJson(['message' => 'Invalid email or password.']);

        $this->assertSame(2, AuditLog::where('action', 'login_failed')->count());
        // The password never appears in the audit trail.
        $this->assertStringNotContainsString('wrong-pass1', AuditLog::pluck('details')->toJson());
    }

    public function test_sql_injection_payloads_do_not_bypass_login(): void
    {
        $this->register();

        // Rejected by validation before reaching the database.
        $this->postJson('/api/auth/login', ['email' => "' OR 1=1 --", 'password' => 'x'])
            ->assertStatus(422);

        // Passed as a bound parameter, so it's just a wrong password.
        $this->postJson('/api/auth/login', ['email' => 'juan@example.com', 'password' => "' OR '1'='1"])
            ->assertStatus(401);

        $this->assertSame(1, User::count());
    }

    public function test_login_is_rate_limited_after_five_attempts(): void
    {
        $this->register();

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/auth/login', ['email' => 'juan@example.com', 'password' => 'guess'.$i])
                ->assertStatus(401);
        }

        $this->postJson('/api/auth/login', ['email' => 'juan@example.com', 'password' => 'Secret123'])
            ->assertStatus(429)
            ->assertHeader('Retry-After');

        $this->assertTrue(AuditLog::where('action', 'rate_limited')->exists());
    }

    public function test_access_token_expires_after_fifteen_minutes(): void
    {
        $token = $this->register()->json('accessToken');

        $this->withToken($token)->getJson('/api/me')->assertOk();

        $this->travel(16)->minutes();
        $this->app['auth']->forgetGuards();

        $this->withToken($token)->getJson('/api/me')->assertStatus(401);
    }

    public function test_refresh_rotates_the_token_and_detects_reuse(): void
    {
        $first = $this->register()->getCookie('ebm_refresh', false)->getValue();

        // Normal refresh: new access token + new refresh cookie.
        $response = $this->withCredentials()->withUnencryptedCookie('ebm_refresh', $first)
            ->withHeaders(self::JSON)
            ->postJson('/api/auth/refresh')
            ->assertOk();
        $second = $response->getCookie('ebm_refresh', false)->getValue();
        $this->assertNotSame($first, $second);

        // Attacker replays the OLD token: rejected, and the whole login is revoked.
        $this->withCredentials()->withUnencryptedCookie('ebm_refresh', $first)
            ->withHeaders(self::JSON)
            ->postJson('/api/auth/refresh')
            ->assertStatus(401);
        $this->assertTrue(AuditLog::where('action', 'refresh_token_reuse_detected')->exists());

        // Even the legitimate newer token no longer works.
        $this->withCredentials()->withUnencryptedCookie('ebm_refresh', $second)
            ->withHeaders(self::JSON)
            ->postJson('/api/auth/refresh')
            ->assertStatus(401);
    }

    public function test_cookie_endpoints_reject_cross_site_requests(): void
    {
        $cookie = $this->register()->getCookie('ebm_refresh', false)->getValue();

        // A plain cross-site form post has no custom header.
        $this->withCredentials()->withUnencryptedCookie('ebm_refresh', $cookie)
            ->postJson('/api/auth/logout', [], ['Accept' => 'application/json'])
            ->assertStatus(403);

        // A script on another origin.
        $this->withCredentials()->withUnencryptedCookie('ebm_refresh', $cookie)
            ->postJson('/api/auth/refresh', [], self::JSON + ['Origin' => 'https://evil.example'])
            ->assertStatus(403);

        $this->assertSame(2, AuditLog::where('action', 'csrf_blocked')->count());
    }

    public function test_logout_revokes_the_refresh_token(): void
    {
        $cookie = $this->register()->getCookie('ebm_refresh', false)->getValue();

        $this->withCredentials()->withUnencryptedCookie('ebm_refresh', $cookie)
            ->withHeaders(self::JSON)
            ->postJson('/api/auth/logout')
            ->assertOk();

        $this->withCredentials()->withUnencryptedCookie('ebm_refresh', $cookie)
            ->withHeaders(self::JSON)
            ->postJson('/api/auth/refresh')
            ->assertStatus(401);
    }

    public function test_changing_password_requires_current_password(): void
    {
        $token = $this->register()->json('accessToken');

        $this->withToken($token)->patchJson('/api/me', [
            'full_name' => 'Juan Dela Cruz',
            'email' => 'juan@example.com',
            'current_password' => 'not-it-123',
            'new_password' => 'NewSecret456',
        ])->assertStatus(422)->assertJsonValidationErrors('current_password');
    }

    public function test_cors_only_allows_the_configured_origin(): void
    {
        $this->call('OPTIONS', '/api/auth/login', [], [], [], [
            'HTTP_ORIGIN' => 'http://localhost:5000',
            'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'POST',
        ])->assertHeader('Access-Control-Allow-Origin', 'http://localhost:5000');

        $response = $this->call('OPTIONS', '/api/auth/login', [], [], [], [
            'HTTP_ORIGIN' => 'https://evil.example',
            'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'POST',
        ]);
        $this->assertNotSame('https://evil.example', $response->headers->get('Access-Control-Allow-Origin'));
        $this->assertNotSame('*', $response->headers->get('Access-Control-Allow-Origin'));
    }
}
