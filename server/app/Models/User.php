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

    protected $hidden = ['password'];

    protected $attributes = ['role' => 'resident'];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
        ];
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
