<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class CreateAdminCommandTest extends TestCase
{
    use RefreshDatabase;

    private function login(string $email, string $password)
    {
        return $this->postJson('/api/auth/login', ['email' => $email, 'password' => $password]);
    }

    public function test_creates_a_verified_admin_who_can_log_in(): void
    {
        $this->artisan('user:create-admin', ['email' => 'Admin@Example.com'])
            ->expectsQuestion('Password (min 8 chars, letters and numbers)', 'Admin1234')
            ->expectsQuestion('Confirm password', 'Admin1234')
            ->assertSuccessful();

        $admin = User::where('email', 'admin@example.com')->firstOrFail();
        $this->assertTrue($admin->isAdmin());
        $this->assertNotNull($admin->email_verified_at);
        $this->assertStringStartsWith('$argon2id$', $admin->password);
        $this->assertTrue(AuditLog::where('action', 'admin_created')->exists());

        $this->login('admin@example.com', 'Admin1234')->assertOk()->assertJsonPath('user.role', 'admin');
    }

    public function test_reads_the_password_from_the_environment(): void
    {
        putenv('ADMIN_PASSWORD=FromEnv123');
        try {
            $this->artisan('user:create-admin', ['email' => 'admin@example.com', '--from-env' => true])
                ->assertSuccessful();
        } finally {
            putenv('ADMIN_PASSWORD');
        }

        $this->login('admin@example.com', 'FromEnv123')->assertOk();
    }

    public function test_weak_or_mismatched_passwords_are_refused(): void
    {
        $this->artisan('user:create-admin', ['email' => 'admin@example.com'])
            ->expectsQuestion('Password (min 8 chars, letters and numbers)', 'short')
            ->expectsQuestion('Confirm password', 'short')
            ->assertFailed();

        $this->artisan('user:create-admin', ['email' => 'admin@example.com'])
            ->expectsQuestion('Password (min 8 chars, letters and numbers)', 'Admin1234')
            ->expectsQuestion('Confirm password', 'Admin9999')
            ->assertFailed();

        $this->assertSame(0, User::count());
    }

    public function test_existing_account_is_promoted_and_keeps_its_password(): void
    {
        $this->signUp('juan@example.com', 'Secret123');

        putenv('ADMIN_PASSWORD=Other12345');
        try {
            // Running it again on every deploy must never overwrite the password.
            $this->artisan('user:create-admin', ['email' => 'juan@example.com', '--from-env' => true])->assertSuccessful();
            $this->artisan('user:create-admin', ['email' => 'juan@example.com', '--from-env' => true])->assertSuccessful();
        } finally {
            putenv('ADMIN_PASSWORD');
        }

        $user = User::where('email', 'juan@example.com')->firstOrFail();
        $this->assertTrue($user->isAdmin());
        $this->assertTrue(Hash::check('Secret123', $user->password));
        $this->assertSame(1, User::count());
    }
}
