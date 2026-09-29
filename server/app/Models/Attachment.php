<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Attachment extends Model
{
    protected $fillable = ['kind', 'path', 'mime', 'size', 'sha256'];

    protected $hidden = ['path'];

    public function concern(): BelongsTo
    {
        return $this->belongsTo(Concern::class);
    }
}
