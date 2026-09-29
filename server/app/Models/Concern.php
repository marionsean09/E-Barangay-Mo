<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Concern extends Model
{
    public const TYPES = ['Complaint', 'Suggestion', 'Request', 'Blotter'];

    public const STATUSES = ['Pending', 'In Progress', 'Resolved', 'Rejected'];

    public const REQUEST_TYPES = [
        'Barangay Clearance',
        'Certificate of Residency',
        'Certificate of Indigency',
        'Barangay Business Permit / Clearance',
        'Certificate to File Action',
    ];

    public const REQUIREMENTS = ['validIdFront', 'validIdBack', 'proofOfAddress', 'cedula'];

    public const BLOTTER_CATEGORIES = [
        'Dispute with a neighbor',
        'Theft or loss',
        'Physical injury',
        'Threats or harassment',
        'Noise or disturbance',
        'Damage to property',
        'Other',
    ];

    // user_id, status and the admin dates are never mass-assigned from a
    // request; controllers set them explicitly.
    protected $fillable = ['type', 'title', 'description', 'purpose', 'request_type', 'requested_date'];

    protected function casts(): array
    {
        return [
            // Blotter reasons and request purposes can hold sensitive personal
            // details, so they are encrypted before they reach MySQL.
            'description' => 'encrypted',
            'purpose' => 'encrypted',
            'requested_date' => 'date:Y-m-d',
            'final_date' => 'date:Y-m-d',
            'claim_date' => 'date:Y-m-d',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function attachments(): HasMany
    {
        return $this->hasMany(Attachment::class);
    }

    // Shape matches what the Flutter screens read from `row.data[...]`.
    public function toApi(bool $withRequester = false): array
    {
        $data = [
            'id' => $this->id,
            'createdAt' => $this->created_at?->toIso8601String(),
            'userId' => $this->user_id,
            'type' => $this->type,
            'title' => $this->title,
            'description' => $this->description,
            'purpose' => $this->purpose,
            'requestType' => $this->request_type,
            'status' => $this->status,
            'requestedDate' => $this->requested_date?->format('Y-m-d'),
            'finalDate' => $this->final_date?->format('Y-m-d'),
            'claimDate' => $this->claim_date?->format('Y-m-d'),
            'evidence' => [],
        ];

        foreach ($this->attachments as $attachment) {
            if ($attachment->kind === 'evidence') {
                $data['evidence'][] = $attachment->id;
            } else {
                $data[$attachment->kind] = $attachment->id;
            }
        }

        if ($withRequester) {
            $data['requester'] = ['id' => $this->user->id, 'fullName' => $this->user->full_name];
        }

        return $data;
    }
}
