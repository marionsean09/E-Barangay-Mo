<?php

use App\Models\Attachment;
use App\Models\User;
use App\Services\AttachmentStore;
use App\Services\TokenService;
use App\Support\SecurityLog;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schedule;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rules\Password;

/*
| Admins are created from the server console only. There is no API route
| that can change a role, and no admin password is stored in the repo.
|
|   php artisan user:role someone@example.com admin
*/
Artisan::command('user:role {email} {role}', function (string $email, string $role) {
    if (! in_array($role, ['resident', 'admin'], true)) {
        $this->error('Role must be "resident" or "admin".');

        return 1;
    }

    $user = User::where('email', strtolower($email))->first();
    if (! $user) {
        $this->error('No user with that email. Register in the app first.');

        return 1;
    }

    $user->forceFill(['role' => $role])->save();
    SecurityLog::event('role_changed', ['role' => $role, 'by' => 'console'], $user->id, 'user', $user->id);
    $this->info("{$user->email} is now {$role}.");
})->purpose('Set a user role (resident/admin)');

/*
| Creates a ready-to-use admin straight in the database, for a fresh server
| (e.g. Railway) where signing up would need a working email first.
| The password is typed at a hidden prompt, or with --from-env read from the
| ADMIN_PASSWORD variable (used once by docker/start.sh, then removed).
|
|   php artisan user:create-admin admin@example.com --name="Barangay Admin"
|
| If the email already has an account it is promoted to admin and its
| password is left alone (use user:password to change it).
*/
Artisan::command('user:create-admin {email} {--name=Barangay Admin} {--from-env : Read the password from ADMIN_PASSWORD}', function (string $email) {
    $email = strtolower(trim($email));
    $name = trim((string) $this->option('name'));

    $input = Validator::make(['email' => $email, 'full_name' => $name], [
        'email' => ['required', 'string', 'email:rfc', 'max:191'],
        'full_name' => ['required', 'string', 'min:2', 'max:100', "regex:/^[\pL\s.'-]+$/u"],
    ]);
    if ($input->fails()) {
        foreach ($input->errors()->all() as $message) {
            $this->error($message);
        }

        return 1;
    }

    $user = User::where('email', $email)->first();
    if ($user) {
        $wasAdmin = $user->isAdmin();
        $user->forceFill([
            'role' => 'admin',
            // The operator vouches for this address.
            'email_verified_at' => $user->email_verified_at ?? now(),
        ])->save();
        if (! $wasAdmin) {
            SecurityLog::event('role_changed', ['role' => 'admin', 'by' => 'console'], $user->id, 'user', $user->id);
        }
        $this->info($wasAdmin
            ? "{$email} is already an admin. Password unchanged (use user:password to change it)."
            : "{$email} already had an account and is now an admin. Password unchanged.");

        return 0;
    }

    if ($this->option('from-env')) {
        $password = (string) getenv('ADMIN_PASSWORD');
    } else {
        $password = (string) $this->secret('Password (min 8 chars, letters and numbers)');
        if ($password !== (string) $this->secret('Confirm password')) {
            $this->error('Passwords do not match.');

            return 1;
        }
    }

    // Same rules as sign-up.
    $check = Validator::make(
        ['password' => $password],
        ['password' => ['required', 'string', 'max:128', Password::min(8)->letters()->numbers()]],
    );
    if ($check->fails()) {
        foreach ($check->errors()->all() as $message) {
            $this->error($message);
        }

        return 1;
    }

    $user = new User(['full_name' => $name, 'email' => $email, 'password' => $password]); // hashed by the cast
    $user->forceFill(['role' => 'admin', 'email_verified_at' => now()])->save();
    SecurityLog::event('admin_created', ['by' => 'console'], $user->id, 'user', $user->id);

    $this->info("Admin {$email} created. You can log in now.");

    return 0;
})->purpose('Create a verified admin account (hidden password prompt)');

/*
| Reset a password from the server console, e.g. a forgotten admin password.
| The password is typed at a hidden prompt, never passed as an argument, so it
| does not end up in shell history.
|
|   php artisan user:password someone@example.com
*/
Artisan::command('user:password {email}', function (string $email, TokenService $tokens) {
    $user = User::where('email', strtolower($email))->first();
    if (! $user) {
        $this->error('No user with that email.');

        return 1;
    }

    $password = (string) $this->secret('New password (min 8 chars, letters and numbers)');
    if ($password !== (string) $this->secret('Confirm new password')) {
        $this->error('Passwords do not match.');

        return 1;
    }

    // Same rules as the Edit profile form.
    $validator = Validator::make(
        ['password' => $password],
        ['password' => ['required', 'string', 'max:128', Password::min(8)->letters()->numbers()]],
    );
    if ($validator->fails()) {
        foreach ($validator->errors()->all() as $message) {
            $this->error($message);
        }

        return 1;
    }

    $user->password = $password; // hashed by the 'hashed' cast (argon2id)
    $user->save();

    // Sign out every session, so a stolen session can't outlive the reset.
    $tokens->revokeOtherFamilies($user, null);
    SecurityLog::event('credentials_changed', ['password_changed' => true, 'by' => 'console'], $user->id, 'user', $user->id);

    $this->info("Password updated for {$user->email}. All sessions were signed out.");
})->purpose('Reset a user password (hidden prompt)');

/*
| Retention (project plan, section 2): uploaded files are deleted one year after
| a concern is closed. The concern itself and the audit log are always kept.
|
|   php artisan attachments:purge --dry-run
*/
Artisan::command('attachments:purge {--dry-run : Only count what would be deleted}', function (AttachmentStore $store) {
    $expired = fn () => Attachment::whereHas('concern', fn ($query) => $query
        ->whereIn('status', ['Resolved', 'Rejected'])
        ->where('updated_at', '<', now()->subYear()));

    if ($this->option('dry-run')) {
        $this->info($expired()->count().' attachment(s) would be deleted.');

        return 0;
    }

    $deleted = 0;
    while (($batch = $expired()->orderBy('id')->limit(200)->get(['id', 'path']))->isNotEmpty()) {
        // The row goes first: if this fails, the encrypted file is still there.
        DB::connection(config('security.retention_connection'))
            ->table('attachments')
            ->whereIn('id', $batch->pluck('id'))
            ->delete();
        $store->delete($batch->pluck('path')->all());
        $deleted += $batch->count();
    }

    if ($deleted > 0) {
        SecurityLog::event('attachments_purged', ['count' => $deleted]);
    }
    $this->info("{$deleted} attachment(s) deleted.");
})->purpose('Delete attachments one year after a concern is closed');

Schedule::command('attachments:purge')->dailyAt('02:00');
