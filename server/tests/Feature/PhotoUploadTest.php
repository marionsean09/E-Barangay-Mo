<?php

namespace Tests\Feature;

use App\Models\Attachment;
use App\Models\Concern;
use App\Models\User;
use App\Services\ImageUpload;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use App\Models\AuditLog;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Photos from any phone are accepted (JPG, PNG, WEBP, HEIC/HEIF, AVIF, GIF,
 * BMP, up to 15 MB), but only if the bytes really are an image.
 */
class PhotoUploadTest extends TestCase
{
    use RefreshDatabase;

    private const PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

    private const GIF = 'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
    }

    /** Start of an ISO media file: size, "ftyp", major brand, version, compatible brands. */
    private static function isoFile(string $major, array $compatible = []): string
    {
        $box = $major."\0\0\0\0".implode('', $compatible);

        return pack('N', 8 + strlen($box)).'ftyp'.$box.str_repeat("\0", 64);
    }

    private function token(): string
    {
        $token = $this->signUp('res@example.com')->json('accessToken');
        $this->app['auth']->forgetGuards();

        return $token;
    }

    private function submit(string $token, UploadedFile $front)
    {
        $png = fn () => UploadedFile::fake()->createWithContent('id.png', base64_decode(self::PNG));
        $day = Concern::today()->addDay();

        return $this->withToken($token)->post('/api/concerns', [
            'type' => 'Request',
            'request_type' => 'Barangay Clearance',
            'purpose' => 'Employment',
            'requested_date' => ($day->isWeekend() ? $day->next('Monday') : $day)->toDateString(),
            'validIdFront' => $front,
            'validIdBack' => $png(),
            'proofOfAddress' => $png(),
            'cedula' => $png(),
        ], ['Accept' => 'application/json']);
    }

    public function test_iphone_and_android_heic_photos_are_accepted(): void
    {
        $token = $this->token();
        $heic = UploadedFile::fake()->createWithContent('IMG_0001.HEIC', self::isoFile('heic', ['mif1', 'heic']));

        $this->submit($token, $heic)->assertCreated();

        // Converted to JPEG where Imagick is installed (production), else kept as HEIC.
        $mime = Attachment::where('kind', 'validIdFront')->value('mime');
        $this->assertContains($mime, ['image/jpeg', 'image/heic']);
    }

    public function test_other_phone_formats_are_accepted(): void
    {
        $token = $this->token();

        foreach ([
            'photo.avif' => self::isoFile('avif', ['mif1', 'avif']),
            'photo.gif' => base64_decode(self::GIF),
            // Some phones label HEIC as mif1 with heic only in the compatible list.
            'photo.heif' => self::isoFile('mif1', ['mif1', 'heic']),
        ] as $name => $bytes) {
            $this->submit($token, UploadedFile::fake()->createWithContent($name, $bytes))
                ->assertCreated();
            $this->app['cache']->store()->flush(); // per-minute submit limit
        }

        $this->assertSame(3, Concern::count());
    }

    public function test_large_phone_photos_up_to_15_mb_are_accepted(): void
    {
        $token = $this->token();
        $big = base64_decode(self::PNG).str_repeat("\0", 12 * 1024 * 1024);

        $this->submit($token, UploadedFile::fake()->createWithContent('big.png', $big))->assertCreated();
    }

    public function test_photos_over_15_mb_are_rejected(): void
    {
        $token = $this->token();
        $huge = base64_decode(self::PNG).str_repeat("\0", 16 * 1024 * 1024);

        $this->submit($token, UploadedFile::fake()->createWithContent('huge.png', $huge))
            ->assertStatus(422)
            ->assertJsonValidationErrors('validIdFront');
        $this->assertSame(0, Concern::count());
    }

    public function test_videos_and_non_images_are_still_rejected(): void
    {
        $token = $this->token();

        foreach ([
            'clip.heic' => self::isoFile('isom', ['isom', 'iso2', 'mp41']), // an MP4 named .heic
            'clip.mov' => self::isoFile('qt  ', ['qt  ']),
            'shell.heic' => '<?php system($_GET["c"]); ?>',
            'page.jpg' => '<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"/>',
            'doc.png' => "%PDF-1.7\n%\xE2\xE3\xCF\xD3\n",
        ] as $name => $bytes) {
            $this->submit($token, UploadedFile::fake()->createWithContent($name, $bytes))
                ->assertStatus(422)
                ->assertJsonValidationErrors('validIdFront');
        }

        $this->assertSame(0, Concern::count());
    }

    /**
     * The photo picker hands the app a blob: URL, and the app fetches it to
     * read the bytes. Without blob: in connect-src the browser blocks that,
     * so no photo ever appears (only on the deployed site, which sends a CSP).
     */
    public function test_app_page_lets_the_browser_read_picked_photos(): void
    {
        $connectSrc = fn (string $csp) => collect(explode(';', $csp))
            ->map(fn ($d) => trim($d))
            ->first(fn ($d) => str_starts_with($d, 'connect-src '));

        $this->assertContains('blob:', explode(' ', $connectSrc(config('security.csp_app'))));

        // Same policy on index.html when Apache serves it directly.
        preg_match('/Content-Security-Policy "([^"]+)"/', file_get_contents(public_path('.htaccess')), $m);
        $this->assertContains('blob:', explode(' ', $connectSrc($m[1])));
    }

    public function test_a_lost_file_says_so_instead_of_failing_integrity(): void
    {
        $token = $this->token();
        $this->submit($token, UploadedFile::fake()->createWithContent('id.png', base64_decode(self::PNG)))->assertCreated();
        $photo = Attachment::where('kind', 'validIdFront')->firstOrFail();

        // What a redeploy without a persistent volume does.
        Storage::disk('local')->delete($photo->path);

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson("/api/attachments/{$photo->id}")
            ->assertStatus(410)
            ->assertJsonPath('message', 'This photo is no longer stored on the server. Please upload it again.');
        $this->assertTrue(AuditLog::where('action', 'attachment_missing')->exists());
    }

    public function test_an_altered_file_fails_its_integrity_check(): void
    {
        $token = $this->token();
        $this->submit($token, UploadedFile::fake()->createWithContent('id.png', base64_decode(self::PNG)))->assertCreated();
        $photo = Attachment::where('kind', 'validIdFront')->firstOrFail();

        // Swapped for a different, validly encrypted file.
        Storage::disk('local')->put($photo->path, \Illuminate\Support\Facades\Crypt::encryptString('not the original'));

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson("/api/attachments/{$photo->id}")->assertStatus(409);
        $this->assertTrue(AuditLog::where('action', 'attachment_integrity_failed')->exists());
    }

    public function test_detection_uses_the_bytes_not_the_name(): void
    {
        $this->assertSame('image/heic', ImageUpload::detect(self::isoFile('heic')));
        $this->assertSame('image/avif', ImageUpload::detect(self::isoFile('avif')));
        $this->assertSame('image/png', ImageUpload::detect(base64_decode(self::PNG)));
        $this->assertNull(ImageUpload::detect(self::isoFile('mp42', ['isom'])));
        $this->assertNull(ImageUpload::detect('just text'));
    }
}
