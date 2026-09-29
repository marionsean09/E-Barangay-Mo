<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AuditLog extends Model
{
    // Append-only: the app's DB user has INSERT but no UPDATE/DELETE here.
    public const UPDATED_AT = null;

    protected $fillable = ['user_id', 'action', 'target_type', 'target_id', 'details', 'ip'];

    protected function casts(): array
    {
        return ['details' => 'array'];
    }
}
