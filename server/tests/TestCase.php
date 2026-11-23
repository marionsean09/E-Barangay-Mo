<?php

namespace Tests;

use App\Mail\VerificationCodeMail;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\Mail;
use Illuminate\Testing\TestResponse;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Mail::fake();
    }

    /** The newest verification code emailed to this address. */
    protected function codeSentTo(string $email): ?string
    {
        $code = null;
        Mail::assertSent(VerificationCodeMail::class, function (VerificationCodeMail $mail) use ($email, &$code) {
            if ($mail->hasTo($email)) {
                $code = $mail->code;
            }

            return true;
        });

        return $code;
    }

    /** Registers, then verifies with the emailed code. Returns the response that holds the session. */
    protected function signUp(string $email = 'juan@example.com', string $password = 'Secret123', array $extra = []): TestResponse
    {
        $this->postJson('/api/auth/register', array_merge([
            'full_name' => 'Juan Dela Cruz',
            'email' => $email,
            'password' => $password,
        ], $extra))->assertCreated();

        return $this->postJson('/api/auth/verify-email', [
            'email' => $email,
            'password' => $password,
            'code' => $this->codeSentTo($email),
        ])->assertOk();
    }

    /**
     * In production every HTTP request is a fresh PHP process. Tests reuse one
     * app instance, so forget the resolved user before each request; otherwise
     * user A's identity would leak into user B's request.
     */
    public function call($method, $uri, $parameters = [], $cookies = [], $files = [], $server = [], $content = null)
    {
        $this->app['auth']->forgetGuards();

        return parent::call($method, $uri, $parameters, $cookies, $files, $server, $content);
    }
}
