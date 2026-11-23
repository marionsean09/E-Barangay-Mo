<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class RegisterRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            // Letters, spaces, dots, apostrophes and hyphens only (e.g. "Ma. Dela Cruz-O'Neil").
            'full_name' => ['required', 'string', 'min:2', 'max:100', "regex:/^[\pL\s.'-]+$/u"],
            // Only verified accounts block the email. An unverified sign-up can be
            // redone, so nobody can squat an address they don't own.
            'email' => ['required', 'string', 'email:rfc', 'max:191',
                Rule::unique('users', 'email')->whereNotNull('email_verified_at')],
            'password' => ['required', 'string', 'max:128', Password::min(8)->letters()->numbers()],
        ];
    }

    public function messages(): array
    {
        return ['full_name.regex' => 'Your name can only contain letters, spaces, dots, apostrophes and hyphens.'];
    }
}
