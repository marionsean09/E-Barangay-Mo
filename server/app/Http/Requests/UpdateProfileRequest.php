<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class UpdateProfileRequest extends FormRequest
{
    public function rules(): array
    {
        $user = $this->user();
        $emailChanged = $this->filled('email') && $this->input('email') !== $user->email;

        return [
            'full_name' => ['required', 'string', 'min:2', 'max:100', "regex:/^[\pL\s.'-]+$/u"],
            'email' => ['required', 'string', 'email:rfc', 'max:191', Rule::unique('users', 'email')->ignore($user->id)],
            // Changing email or password requires re-entering the current password.
            'current_password' => [Rule::requiredIf($emailChanged || $this->filled('new_password')), 'nullable', 'string', 'max:128'],
            'new_password' => ['nullable', 'string', 'max:128', Password::min(8)->letters()->numbers()],
        ];
    }

    public function messages(): array
    {
        return [
            'full_name.regex' => 'Your name can only contain letters, spaces, dots, apostrophes and hyphens.',
            'current_password.required' => 'Enter your current password to change your email or password.',
        ];
    }
}
