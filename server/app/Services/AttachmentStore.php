<?php

namespace App\Services;

use App\Models\Attachment;
use finfo;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Uploaded requirement photos are government IDs, so they are encrypted
 * before touching disk (AES-256-CBC + HMAC with APP_KEY) and stored on the
 * private disk (storage/app/private), which the web server never serves.
 */
class AttachmentStore
{
    private const DISK = 'local';

    /** @return array{kind: string, path: string, mime: string, size: int, sha256: string} */
    public function put(UploadedFile $file, string $kind): array
    {
        $contents = $file->get();
        // Random name: the original filename is never used on disk.
        $path = 'attachments/'.Str::random(40).'.bin';

        Storage::disk(self::DISK)->put($path, Crypt::encryptString($contents));

        return [
            'kind' => $kind,
            'path' => $path,
            // Detected from the bytes, never the client's Content-Type.
            'mime' => (new finfo(FILEINFO_MIME_TYPE))->buffer($contents),
            'size' => strlen($contents),
            'sha256' => hash('sha256', $contents),
        ];
    }

    public function read(Attachment $attachment): string
    {
        $contents = Crypt::decryptString(Storage::disk(self::DISK)->get($attachment->path));

        if (! hash_equals($attachment->sha256, hash('sha256', $contents))) {
            throw new RuntimeException('Attachment integrity check failed.');
        }

        return $contents;
    }

    public function delete(array $paths): void
    {
        Storage::disk(self::DISK)->delete($paths);
    }
}
