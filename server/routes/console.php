<?php

use App\Models\User;
use App\Support\SecurityLog;
use Illuminate\Support\Facades\Artisan;

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
