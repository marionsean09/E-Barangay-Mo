<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class MarkMessagesReadRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'last_message_id' => ['required', 'integer', 'min:1'],
        ];
    }
}
