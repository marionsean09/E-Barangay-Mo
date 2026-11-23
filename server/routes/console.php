<?php

use App\Models\User;
use App\Services\TokenService;
use App\Support\SecurityLog;
use Illuminate\Support\Facades\Artisan;
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
