<?php

namespace App\Http\Requests;

use App\Models\Concern;
use App\Services\ImageUpload;
use Carbon\CarbonImmutable;
use Closure;
use ErrorException;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreConcernRequest extends FormRequest
{
    public function rules(): array
    {
        $photo = [
            'bail', 'file', 'max:'.ImageUpload::MAX_KB,
            // Check the real bytes (magic numbers), not the filename or the
            // Content-Type the client claims. Any photo format a phone makes
            // passes (JPG, PNG, WEBP, HEIC/HEIF, AVIF, GIF, BMP); "shell.php"
            // renamed to ".jpg" does not. A file that can't be read (e.g.
            // blocked by antivirus) is rejected, not a server error.
            function (string $attribute, mixed $value, Closure $fail) {
                try {
                    $bytes = file_get_contents($value->getRealPath());
                } catch (ErrorException) {
                    $bytes = false;
                }
                if ($bytes === false || ImageUpload::detect($bytes) === null) {
                    $fail('The :attribute must be a photo (JPG, PNG, HEIC, WEBP, AVIF, GIF or BMP).');
                }
            },
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
