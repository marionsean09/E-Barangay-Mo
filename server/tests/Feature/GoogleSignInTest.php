<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class GoogleSignInTest extends TestCase
{
    use RefreshDatabase;

    private const CLIENT_ID = 'test-client.apps.googleusercontent.com';

    private const TOKEN = 'aaa.bbb.ccc';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.google.client_id' => self::CLIENT_ID]);
    }

    /** What Google's tokeninfo endpoint returns for the token. */
    private function googleSays(array $overrides = [], int $status = 200): void
    {
        Http::fake(['oauth2.googleapis.com/*' => Http::response(array_merge([
            'iss' => 'https://accounts.google.com',
            'aud' => self::CLIENT_ID,
            'exp' => (string) now()->addHour()->timestamp,
            'email' => 'Maria@Gmail.com',
            'email_verified' => 'true',
            'name' => 'Maria Santos',
        ], $overrides), $status)]);
    }

    private function signInWithGoogle()
    {
        return $this->postJson('/api/auth/google', ['id_token' => self::TOKEN]);
    }

    public function test_new_google_user_gets_a_verified_resident_account(): void
    {
        $this->googleSays(['role' => 'admin']);

        $this->signInWithGoogle()
            ->assertOk()
            ->assertJsonStructure(['accessToken'])
            ->assertJsonPath('user.email', 'maria@gmail.com')
            ->assertJsonPath('user.name', 'Maria Santos')
            ->assertJsonPath('user.role', 'resident');

        $this->assertNotNull(User::first()->email_verified_at);
    }

    public function test_existing_account_signs_in_without_a_duplicate(): void
    {
        $this->signUp('maria@gmail.com');
        $this->googleSays();

        $this->signInWithGoogle()->assertOk();
        $this->assertSame(1, User::count());

        // The original password still works.
        $this->postJson('/api/auth/login', ['email' => 'maria@gmail.com', 'password' => 'Secret123'])->assertOk();
    }

    public function test_token_for_another_app_is_rejected(): void
    {
        $this->googleSays(['aud' => 'someone-elses-app.apps.googleusercontent.com']);
        $this->signInWithGoogle()->assertStatus(401)->assertJsonMissingPath('accessToken');
        $this->assertSame(0, User::count());
    }

    public function test_unverified_google_email_expired_token_or_bad_signature_is_rejected(): void
    {
        $this->googleSays(['email_verified' => 'false']);
        $this->signInWithGoogle()->assertStatus(401);

        $this->googleSays(['exp' => (string) now()->subMinute()->timestamp]);
        $this->signInWithGoogle()->assertStatus(401);

        $this->googleSays(['iss' => 'https://evil.example']);
        $this->signInWithGoogle()->assertStatus(401);

        // Google itself says the token is invalid (bad signature, garbage, ...).
        $this->googleSays(['error' => 'invalid_token'], 400);
        $this->signInWithGoogle()->assertStatus(401);

        $this->assertSame(0, User::count());
    }

    public function test_google_owner_takes_over_an_unfinished_sign_up(): void
    {
        // Someone started a sign-up with Maria's address and never verified it.
        $this->postJson('/api/auth/register', [
            'full_name' => 'Squatter', 'email' => 'maria@gmail.com', 'password' => 'Squatter1',
        ])->assertCreated();

        $this->googleSays();
        $this->signInWithGoogle()->assertOk();

        // The squatter's password no longer works.
        $this->postJson('/api/auth/login', ['email' => 'maria@gmail.com', 'password' => 'Squatter1'])->assertStatus(401);
    }

    public function test_disabled_when_no_client_id_is_configured(): void
    {
        config(['services.google.client_id' => null]);
        $this->googleSays();

        $this->signInWithGoogle()->assertStatus(503);
        Http::assertNothingSent();
    }
}
