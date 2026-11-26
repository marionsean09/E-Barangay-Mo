<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens;

    // 'role' is deliberately NOT fillable: a resident can't send
    // {"role":"admin"} in a request body and promote themselves.
    protected $fillable = ['full_name', 'email', 'password'];

    // Verification and reset fields are not fillable either: only
    // EmailVerification and PasswordReset set them.
    protected $hidden = ['password', 'verification_code_hash', 'reset_code_hash'];

    protected $attributes = ['role' => 'resident'];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'email_verified_at' => 'datetime',
            'privacy_consented_at' => 'datetime',
            'verification_expires_at' => 'datetime',
            'verification_sent_at' => 'datetime',
            'verification_attempts' => 'integer',
            'reset_expires_at' => 'datetime',
            'reset_sent_at' => 'datetime',
            'reset_attempts' => 'integer',
        ];
    }

    public function hasVerifiedEmail(): bool
    {
        return $this->email_verified_at !== null;
    }

    public function isAdmin(): bool
    {
        return $this->role === 'admin';
    }

    public function concerns(): HasMany
    {
        return $this->hasMany(Concern::class);
    }

    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->full_name,
            'email' => $this->email,
            'role' => $this->role,
            'createdAt' => $this->created_at?->toIso8601String(),
        ];
    }
}
