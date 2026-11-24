<?php

namespace Tests\Feature;

use App\Mail\VerificationCodeMail;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class EmailVerificationTest extends TestCase
{
    use RefreshDatabase;

    private const ACCOUNT = ['full_name' => 'Juan Dela Cruz', 'email' => 'juan@example.com', 'password' => 'Secret123', 'privacy_consent' => true];

    private function verify(string $code, string $password = 'Secret123')
    {
        return $this->postJson('/api/auth/verify-email', [
            'email' => 'juan@example.com', 'password' => $password, 'code' => $code,
        ]);
    }

    private function wrongCode(string $right): string
    {
        return $right === '000000' ? '111111' : '000000';
    }

    public function test_sign_up_emails_a_code_and_gives_no_session_until_verified(): void
    {
        $response = $this->postJson('/api/auth/register', self::ACCOUNT)
            ->assertCreated()
            ->assertJsonPath('verificationRequired', true)
            ->assertJsonMissingPath('accessToken');
        $this->assertNull($response->getCookie('ebm_refresh', false));

        Mail::assertSent(VerificationCodeMail::class, fn ($mail) => $mail->hasTo('juan@example.com'));
        $code = $this->codeSentTo('juan@example.com');
        $this->assertMatchesRegularExpression('/^\d{6}$/', $code);

        // Only a keyed hash is stored, never the code.
        $user = User::first();
        $this->assertNull($user->email_verified_at);
        $this->assertNotSame($code, $user->verification_code_hash);
        $this->assertStringNotContainsString($code, json_encode($user->getAttributes()));

        // Right password, but the email isn't confirmed yet.
        $this->postJson('/api/auth/login', ['email' => 'juan@example.com', 'password' => 'Secret123'])
            ->assertStatus(403)
            ->assertJsonPath('verificationRequired', true)
            ->assertJsonMissingPath('accessToken');

        $this->verify($code)->assertOk()->assertJsonStructure(['accessToken', 'user']);
        $this->assertNotNull(User::first()->email_verified_at);
        $this->assertTrue(AuditLog::where('action', 'email_verified')->exists());

        $this->postJson('/api/auth/login', ['email' => 'juan@example.com', 'password' => 'Secret123'])->assertOk();
    }

    public function test_code_dies_after_five_wrong_guesses(): void
    {
        $this->postJson('/api/auth/register', self::ACCOUNT)->assertCreated();
        $code = $this->codeSentTo('juan@example.com');

        for ($i = 0; $i < 5; $i++) {
            $this->verify($this->wrongCode($code))->assertStatus(422);
            $this->app['cache']->store()->flush(); // isolate from the per-minute route limit
        }

        // Even the right code no longer works.
        $this->verify($code)->assertStatus(422);
        $this->assertNull(User::first()->email_verified_at);
        $this->assertSame(5, AuditLog::where('action', 'verification_failed')->count());
    }

    public function test_code_expires_after_ten_minutes(): void
    {
        $this->postJson('/api/auth/register', self::ACCOUNT)->assertCreated();
        $code = $this->codeSentTo('juan@example.com');

        $this->travel(11)->minutes();

        $this->verify($code)->assertStatus(422);
    }

    public function test_code_alone_is_not_enough_without_the_password(): void
    {
        $this->postJson('/api/auth/register', self::ACCOUNT)->assertCreated();
        $code = $this->codeSentTo('juan@example.com');

        $this->verify($code, 'NotMine123')
            ->assertStatus(422)
            ->assertJsonPath('message', 'That code is incorrect or has expired.');
        $this->assertNull(User::first()->email_verified_at);
    }

    public function test_resend_waits_a_minute_and_replaces_the_old_code(): void
    {
        $this->postJson('/api/auth/register', self::ACCOUNT)->assertCreated();
        $first = $this->codeSentTo('juan@example.com');

        $this->postJson('/api/auth/resend-code', ['email' => 'juan@example.com', 'password' => 'Secret123'])
            ->assertStatus(429)
            ->assertHeader('Retry-After');

        // Wrong password: no email is sent, so nobody can flood an inbox.
        $this->travel(61)->seconds();
        $this->postJson('/api/auth/resend-code', ['email' => 'juan@example.com', 'password' => 'NotMine123'])
            ->assertStatus(401);
        Mail::assertSentCount(1);

        $this->postJson('/api/auth/resend-code', ['email' => 'juan@example.com', 'password' => 'Secret123'])->assertOk();
        Mail::assertSentCount(2);
        $second = $this->codeSentTo('juan@example.com');

        if ($first !== $second) {
            $this->verify($first)->assertStatus(422);
        }
        $this->verify($second)->assertOk();
    }

    public function test_code_is_not_in_the_email_subject(): void
    {
        $this->postJson('/api/auth/register', self::ACCOUNT)->assertCreated();
        $code = $this->codeSentTo('juan@example.com');

        Mail::assertSent(VerificationCodeMail::class, fn ($mail) => ! str_contains($mail->envelope()->subject, $code));
    }

    public function test_one_inbox_gets_at_most_five_codes_per_hour(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/auth/register', self::ACCOUNT)->assertCreated();
            $this->travel(61)->seconds();
        }
        Mail::assertSentCount(5);
        $hash = User::first()->password;

        // Blocked on every route, and a blocked sign-up can't replace the password.
        $this->postJson('/api/auth/register', ['password' => 'Attacker1'] + self::ACCOUNT)
            ->assertStatus(429)
            ->assertHeader('Retry-After');
        $this->postJson('/api/auth/login', ['email' => 'juan@example.com', 'password' => 'Secret123'])
            ->assertStatus(429);
        $this->postJson('/api/auth/resend-code', ['email' => 'juan@example.com', 'password' => 'Secret123'])
            ->assertStatus(429);
        Mail::assertSentCount(5);
        $this->assertSame($hash, User::first()->password);

        $this->travel(1)->hours();
        $this->postJson('/api/auth/resend-code', ['email' => 'juan@example.com', 'password' => 'Secret123'])->assertOk();
        Mail::assertSentCount(6);
    }

    public function test_unverified_sign_up_can_be_redone_but_a_verified_email_is_taken(): void
    {
        // Someone starts a sign-up with an address they don't own and never verifies it.
        $this->postJson('/api/auth/register', ['password' => 'Squatter1'] + self::ACCOUNT)->assertCreated();

        // The real owner can still register; their password replaces the squatter's.
        $this->travel(61)->seconds();
        $this->signUp('juan@example.com', 'Secret123');
        $this->assertSame(1, User::count());

        $this->postJson('/api/auth/login', ['email' => 'juan@example.com', 'password' => 'Squatter1'])->assertStatus(401);

        // Once verified, the email can't be registered again.
        $this->postJson('/api/auth/register', self::ACCOUNT)
            ->assertStatus(422)
            ->assertJsonValidationErrors('email');
    }
}
