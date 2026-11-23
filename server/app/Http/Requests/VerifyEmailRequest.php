<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class VerifyEmailRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'email' => ['required', 'string', 'email:rfc', 'max:191'],
            // The password is required too, so knowing a code alone can't
            // take over an account someone else is registering.
            'password' => ['required', 'string', 'max:128'],
            'code' => ['required', 'string', 'regex:/^\d{6}$/'],
        ];
    }

    public function messages(): array
    {
        return ['code.regex' => 'Enter the 6-digit code from the email.'];
    }
}
