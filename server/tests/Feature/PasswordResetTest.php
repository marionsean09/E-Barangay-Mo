<?php

namespace Tests\Feature;

use App\Mail\PasswordResetCodeMail;
use App\Mail\VerificationCodeMail;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    private const JSON = ['Accept' => 'application/json', 'X-Requested-With' => 'XMLHttpRequest'];

    private function forgot(string $email = 'juan@example.com')
    {
        return $this->postJson('/api/auth/forgot-password', ['email' => $email]);
    }

    private function reset(string $code, string $password = 'NewSecret456', string $email = 'juan@example.com')
    {
        return $this->postJson('/api/auth/reset-password', [
            'email' => $email, 'code' => $code, 'password' => $password,
        ]);
    }

    /** The newest reset code emailed to this address. */
    private function resetCodeSentTo(string $email): ?string
    {
        $code = null;
        Mail::assertSent(PasswordResetCodeMail::class, function (PasswordResetCodeMail $mail) use ($email, &$code) {
            if ($mail->hasTo($email)) {
                $code = $mail->code;
            }

            return true;
        });

        return $code;
    }

    private function wrongCode(string $right): string
    {
        return $right === '000000' ? '111111' : '000000';
    }

    private function login(string $password)
    {
        return $this->postJson('/api/auth/login', ['email' => 'juan@example.com', 'password' => $password]);
    }

    public function test_reset_changes_the_password_and_signs_out_every_session(): void
    {
        $cookie = $this->signUp()->getCookie('ebm_refresh', false)->getValue();

        $this->forgot()->assertOk();
        $code = $this->resetCodeSentTo('juan@example.com');
        $this->assertMatchesRegularExpression('/^\d{6}$/', $code);

        // Only a keyed hash is stored, never the code.
        $this->assertStringNotContainsString($code, json_encode(User::first()->getAttributes()));

        $this->reset($code)->assertOk()->assertJsonMissingPath('accessToken');

        $this->login('Secret123')->assertStatus(401);
        $this->login('NewSecret456')->assertOk();

        // The session from before the reset is gone.
        $this->withCredentials()->withUnencryptedCookie('ebm_refresh', $cookie)
            ->withHeaders(self::JSON)
            ->postJson('/api/auth/refresh')
            ->assertStatus(401);

        $this->assertTrue(AuditLog::where('action', 'password_reset_requested')->exists());
        $this->assertTrue(AuditLog::where('action', 'credentials_changed')->exists());
    }

    public function test_reply_is_the_same_for_unknown_emails_and_no_mail_is_sent(): void
    {
        $this->signUp();
        Mail::fake(); // forget the sign-up email

        $known = $this->forgot('juan@example.com')->assertOk()->json('message');
        $unknown = $this->forgot('nobody@example.com')->assertOk()->json('message');

        $this->assertSame(
            str_replace('juan@example.com', 'X', $known),
            str_replace('nobody@example.com', 'X', $unknown),
        );
        Mail::assertSent(PasswordResetCodeMail::class, 1);
        Mail::assertNotSent(PasswordResetCodeMail::class, fn ($mail) => $mail->hasTo('nobody@example.com'));
    }

    public function test_unverified_sign_ups_get_no_reset_code(): void
    {
        $this->postJson('/api/auth/register', [
            'full_name' => 'Juan Dela Cruz', 'email' => 'juan@example.com',
            'password' => 'Secret123', 'privacy_consent' => true,
        ])->assertCreated();

        $this->forgot()->assertOk();
        Mail::assertNotSent(PasswordResetCodeMail::class);
    }

    public function test_code_works_only_once(): void
    {
        $this->signUp();
        $this->forgot();
        $code = $this->resetCodeSentTo('juan@example.com');

        $this->reset($code)->assertOk();
        $this->reset($code, 'Another789')->assertStatus(422);
        $this->login('NewSecret456')->assertOk();
    }

    public function test_code_dies_after_five_wrong_guesses(): void
    {
        $this->signUp();
        $this->forgot();
        $code = $this->resetCodeSentTo('juan@example.com');

        for ($i = 0; $i < 5; $i++) {
            $this->reset($this->wrongCode($code))->assertStatus(422);
            $this->app['cache']->store()->flush(); // isolate from the per-minute route limit
        }

        // Even the right code no longer works.
        $this->reset($code)->assertStatus(422);
        $this->login('Secret123')->assertOk();
        $this->assertSame(5, AuditLog::where('action', 'password_reset_failed')->count());
    }

    public function test_code_expires_after_ten_minutes(): void
    {
        $this->signUp();
        $this->forgot();
        $code = $this->resetCodeSentTo('juan@example.com');

        $this->travel(11)->minutes();

        $this->reset($code)->assertStatus(422);
        $this->login('Secret123')->assertOk();
    }

    public function test_a_verification_code_cannot_reset_a_password(): void
    {
        $this->signUp();
        $verificationCode = $this->codeSentTo('juan@example.com');
        $this->forgot();

        $this->reset($verificationCode)->assertStatus(422);
    }

    public function test_new_password_must_meet_the_sign_up_rules(): void
    {
        $this->signUp();
        $this->forgot();
        $code = $this->resetCodeSentTo('juan@example.com');

        $this->reset($code, 'short')->assertStatus(422)->assertJsonValidationErrors('password');
        $this->reset($code, 'onlyletters')->assertStatus(422)->assertJsonValidationErrors('password');

        // Validation failures don't use up the code.
        $this->reset($code)->assertOk();
    }

    public function test_at_most_one_code_per_minute(): void
    {
        $this->signUp();

        $this->forgot()->assertOk();
        $this->forgot()->assertOk(); // same reply, but no second email
        Mail::assertSent(PasswordResetCodeMail::class, 1);
    }

    public function test_one_inbox_gets_at_most_five_codes_per_hour(): void
    {
        $this->signUp();

        for ($i = 0; $i < 5; $i++) {
            $this->forgot()->assertOk();
            $this->travel(61)->seconds();
        }
        $this->forgot()->assertStatus(429);

        Mail::assertSent(PasswordResetCodeMail::class, 5);
    }

    public function test_reset_email_keeps_the_code_out_of_the_subject(): void
    {
        $this->signUp();
        $this->forgot();
        $code = $this->resetCodeSentTo('juan@example.com');

        Mail::assertSent(PasswordResetCodeMail::class, fn ($mail) => ! str_contains($mail->envelope()->subject, $code));
        Mail::assertNotSent(VerificationCodeMail::class, fn ($mail) => $mail->code === $code);
    }
}
