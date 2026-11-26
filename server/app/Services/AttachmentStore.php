<?php

namespace App\Services;

use App\Models\Attachment;
use finfo;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Contracts\Filesystem\FileNotFoundException;
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

    public function __construct(private ImageUpload $images) {}

    /** @return array{kind: string, path: string, mime: string, size: int, sha256: string} */
    public function put(UploadedFile $file, string $kind): array
    {
        // Re-encoded as a clean JPEG (no EXIF/GPS) when possible; see ImageUpload.
        ['bytes' => $contents, 'mime' => $mime] = $this->images->normalize($file->get());
        // Random name: the original filename is never used on disk.
        $path = 'attachments/'.Str::random(40).'.bin';

        Storage::disk(self::DISK)->put($path, Crypt::encryptString($contents));

        return [
            'kind' => $kind,
            'path' => $path,
            // Detected from the bytes, never the client's Content-Type.
            'mime' => $mime !== '' ? $mime : (new finfo(FILEINFO_MIME_TYPE))->buffer($contents),
            'size' => strlen($contents),
            'sha256' => hash('sha256', $contents),
        ];
    }

    /**
     * @throws FileNotFoundException the file is gone (e.g. no persistent volume, so a redeploy wiped it)
     * @throws RuntimeException      it can't be decrypted (APP_KEY changed) or its hash doesn't match (tampered)
     */
    public function read(Attachment $attachment): string
    {
        $disk = Storage::disk(self::DISK);
        if (! $disk->exists($attachment->path)) {
            throw new FileNotFoundException('Attachment file is missing from storage.');
        }

        try {
            $contents = Crypt::decryptString((string) $disk->get($attachment->path));
        } catch (DecryptException $e) {
            throw new RuntimeException('Attachment could not be decrypted (was APP_KEY changed?).', 0, $e);
        }

        if (! hash_equals($attachment->sha256, hash('sha256', $contents))) {
            throw new RuntimeException('Attachment hash does not match (file was altered).');
        }

        return $contents;
    }

    public function delete(array $paths): void
    {
        Storage::disk(self::DISK)->delete($paths);
    }
}
