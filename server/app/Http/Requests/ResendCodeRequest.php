<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class ResendCodeRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'email' => ['required', 'string', 'email:rfc', 'max:191'],
            // Required so nobody can flood someone else's inbox with codes.
            'password' => ['required', 'string', 'max:128'],
        ];
    }
}
