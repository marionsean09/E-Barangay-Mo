<?php

namespace App\Http\Requests;

use App\Models\Concern;
use Carbon\CarbonImmutable;
use Closure;
use ErrorException;
use finfo;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreConcernRequest extends FormRequest
{
    public const ALLOWED_MIMES = ['image/jpeg', 'image/png', 'image/webp'];

    public function rules(): array
    {
        $photo = [
            'bail', 'file', 'max:5120',
            // Check the real bytes (magic numbers), not the filename or the
            // Content-Type the client claims. Stops "shell.php" renamed to ".jpg".
            // Runs before 'mimes', which also opens the file. A file that can't
            // be read (e.g. blocked by antivirus) is rejected, not a server error.
            function (string $attribute, mixed $value, Closure $fail) {
                try {
                    $mime = (new finfo(FILEINFO_MIME_TYPE))->file($value->getRealPath());
                } catch (ErrorException) {
                    $mime = false;
                }
                if (! in_array($mime, self::ALLOWED_MIMES, true)) {
                    $fail('The :attribute must be a JPG, PNG or WEBP image.');
                }
            },
            'mimes:jpg,jpeg,png,webp',
        ];

        $rules = [
            'type' => ['required', Rule::in(Concern::TYPES)],
            'title' => ['exclude_unless:type,Complaint,Suggestion', 'required', 'string', 'max:150'],
            'description' => ['exclude_if:type,Request', 'required', 'string', 'max:2000'],
            'request_type' => ['exclude_unless:type,Request', 'required', Rule::in(Concern::REQUEST_TYPES)],
            'purpose' => ['exclude_unless:type,Request', 'required', 'string', 'max:500'],
            'blotter_category' => ['exclude_unless:type,Blotter', 'required', Rule::in(Concern::BLOTTER_CATEGORIES)],
            'requested_date' => [
                // Blotter: preferred schedule. Request: preferred claiming date.
                'exclude_unless:type,Blotter,Request', 'bail', 'required', 'date_format:Y-m-d',
                'after:'.Concern::today()->toDateString(),
                'before_or_equal:'.Concern::today()->addDays(90)->toDateString(),
                function (string $attribute, mixed $value, Closure $fail) {
                    if (CarbonImmutable::createFromFormat('Y-m-d', $value)?->isWeekend()) {
                        $fail('The requested date must be a weekday.');
                    }
                },
            ],
            'evidence' => ['exclude_unless:type,Blotter', 'nullable', 'array', 'max:3'],
            'evidence.*' => ['exclude_unless:type,Blotter', ...$photo],
        ];

        foreach (Concern::REQUIREMENTS as $key) {
            $rules[$key] = ['exclude_unless:type,Request', 'required', ...$photo];
        }

        return $rules;
    }
}
