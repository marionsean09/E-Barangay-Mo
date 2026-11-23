<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** One reply in a complaint's conversation. Messages are never edited. */
class ConcernMessage extends Model
{
    public const UPDATED_AT = null;

    // concern_id, user_id and sender_role come from the route and the token.
    protected $fillable = ['body'];

    protected function casts(): array
    {
        return ['body' => 'encrypted'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** Staff appear as the office, so residents never see an admin's identity. */
    public function toApi(User $viewer): array
    {
        return [
            'id' => $this->id,
            'body' => $this->body,
            'senderRole' => $this->sender_role,
            'senderName' => $this->sender_role === 'admin' ? 'Barangay Office' : $this->user->full_name,
            'isMine' => $this->user_id === $viewer->id,
            'createdAt' => $this->created_at?->toIso8601String(),
        ];
    }
}
