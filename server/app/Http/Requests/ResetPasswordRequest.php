<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class ResetPasswordRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'email' => ['required', 'string', 'email:rfc', 'max:191'],
            'code' => ['required', 'string', 'regex:/^\d{6}$/'],
            // Same rules as sign-up and Edit profile.
            'password' => ['required', 'string', 'max:128', Password::min(8)->letters()->numbers()],
        ];
    }

    public function messages(): array
    {
        return ['code.regex' => 'Enter the 6-digit code from the email.'];
    }
}
