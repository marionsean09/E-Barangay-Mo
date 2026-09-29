<?php

namespace App\Http\Requests;

use App\Models\Concern;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** Admin-only update: the only fields an admin can change on a concern. */
class UpdateConcernRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'status' => ['required_without_all:final_date,claim_date', Rule::in(Concern::STATUSES)],
            'final_date' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'after_or_equal:today'],
            'claim_date' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'after_or_equal:today'],
        ];
    }
}
