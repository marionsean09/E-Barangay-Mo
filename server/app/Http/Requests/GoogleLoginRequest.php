<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class GoogleLoginRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            // A JWT: three base64url parts separated by dots.
            'id_token' => ['required', 'string', 'max:4096', 'regex:/^[\w-]+\.[\w-]+\.[\w-]+$/'],
            // Required by the controller only when this creates a new account.
            'privacy_consent' => ['sometimes', 'boolean'],
        ];
    }
}
