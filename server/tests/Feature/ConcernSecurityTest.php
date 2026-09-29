<?php

namespace Tests\Feature;

use App\Models\Attachment;
use App\Models\AuditLog;
use App\Models\Concern;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ConcernSecurityTest extends TestCase
{
    use RefreshDatabase;

    private function tokenFor(string $email, string $role = 'resident'): string
    {
        $token = $this->postJson('/api/auth/register', [
            'full_name' => 'Test User',
            'email' => $email,
            'password' => 'Secret123',
        ])->json('accessToken');

        User::where('email', $email)->first()->forceFill(['role' => $role])->save();
        $this->app['auth']->forgetGuards();

        return $token;
    }

    /** A real 1x1 PNG, so fileinfo detects image/png from the bytes. */
    private function png(string $name = 'id.png'): UploadedFile
    {
        $bytes = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

        return UploadedFile::fake()->createWithContent($name, $bytes);
    }

    private function fileRequest(): array
    {
        return [
            'type' => 'Request',
            'request_type' => 'Barangay Clearance',
            'purpose' => 'Employment',
            'validIdFront' => $this->png(),
            'validIdBack' => $this->png(),
            'proofOfAddress' => $this->png(),
            'cedula' => $this->png(),
        ];
    }

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
    }

    public function test_unauthenticated_requests_are_rejected(): void
    {
        $this->getJson('/api/concerns')->assertStatus(401);
        $this->getJson('/api/admin/concerns')->assertStatus(401);
    }

    public function test_resident_cannot_use_admin_endpoints(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $concernId = $this->withToken($resident)->postJson('/api/concerns', [
            'type' => 'Complaint', 'title' => 'Streetlight', 'description' => 'Broken',
        ])->json('concern.id');

        $this->withToken($resident)->getJson('/api/admin/concerns')->assertStatus(403);
        $this->withToken($resident)->patchJson("/api/admin/concerns/{$concernId}", ['status' => 'Resolved'])
            ->assertStatus(403);

        $this->assertSame('Pending', Concern::find($concernId)->status);
        $this->assertSame(2, AuditLog::where('action', 'permission_denied')->count());
    }

    public function test_resident_only_sees_their_own_concerns(): void
    {
        $alice = $this->tokenFor('alice@example.com');
        $bob = $this->tokenFor('bob@example.com');

        $this->withToken($alice)->postJson('/api/concerns', ['type' => 'Complaint', 'title' => 'Alice secret', 'description' => 'x']);
        $this->withToken($bob)->postJson('/api/concerns', ['type' => 'Complaint', 'title' => 'Bob issue', 'description' => 'y']);

        $titles = collect($this->withToken($bob)->getJson('/api/concerns')->json('concerns'))->pluck('title');
        $this->assertEquals(['Bob issue'], $titles->all());
    }

    public function test_resident_cannot_open_another_residents_id_photo(): void
    {
        $alice = $this->tokenFor('alice@example.com');
        $bob = $this->tokenFor('bob@example.com');

        $this->withToken($alice)->post('/api/concerns', $this->fileRequest(), ['Accept' => 'application/json'])
            ->assertCreated();
        $attachmentId = Attachment::first()->id;

        $this->withToken($alice)->get("/api/attachments/{$attachmentId}")->assertOk();
        $this->withToken($bob)->getJson("/api/attachments/{$attachmentId}")->assertStatus(403);
        $this->assertTrue(AuditLog::where('action', 'permission_denied')->exists());
    }

    public function test_admin_can_view_and_update_and_change_is_audited(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $admin = $this->tokenFor('admin@example.com', 'admin');

        $id = $this->withToken($resident)->postJson('/api/concerns', [
            'type' => 'Complaint', 'title' => 'Flooding', 'description' => 'Drainage clogged',
        ])->json('concern.id');

        $this->withToken($admin)->getJson('/api/admin/concerns')
            ->assertOk()
            ->assertJsonPath('concerns.0.requester.fullName', 'Test User');

        $this->withToken($admin)->patchJson("/api/admin/concerns/{$id}", ['status' => 'In Progress'])
            ->assertOk()
            ->assertJsonPath('concern.status', 'In Progress');

        $log = AuditLog::where('action', 'concern_updated')->first();
        $this->assertSame('Pending', $log->details['before']['status']);
        $this->assertSame('In Progress', $log->details['after']['status']);
    }

    public function test_invalid_status_is_rejected_by_validation(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $admin = $this->tokenFor('admin@example.com', 'admin');
        $id = $this->withToken($resident)->postJson('/api/concerns', ['type' => 'Suggestion', 'title' => 'Park', 'description' => 'More trees'])->json('concern.id');

        $this->withToken($admin)->patchJson("/api/admin/concerns/{$id}", ['status' => "Resolved'; DROP TABLE users; --"])
            ->assertStatus(422);
        $this->assertSame(2, User::count());
    }

    public function test_xss_payload_is_stored_as_plain_text_and_served_as_json(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $payload = '<img src=x onerror=alert(document.cookie)><script>alert(1)</script>';

        $this->withToken($resident)->postJson('/api/concerns', [
            'type' => 'Complaint', 'title' => $payload, 'description' => $payload,
        ])->assertCreated();

        $response = $this->withToken($resident)->getJson('/api/concerns');
        $response->assertHeader('Content-Type', 'application/json')
            ->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");
        // Returned exactly as typed (JSON-escaped); Flutter renders it as text, never HTML.
        $this->assertSame($payload, $response->json('concerns.0.title'));
    }

    public function test_sensitive_text_and_uploaded_ids_are_encrypted_at_rest(): void
    {
        $resident = $this->tokenFor('res@example.com');

        $this->withToken($resident)->postJson('/api/concerns', [
            'type' => 'Complaint', 'title' => 'Noise', 'description' => 'My neighbor at 12 Rizal St.',
        ]);
        $raw = DB::table('concerns')->value('description');
        $this->assertStringNotContainsString('Rizal', $raw);

        $this->withToken($resident)->post('/api/concerns', $this->fileRequest(), ['Accept' => 'application/json'])
            ->assertCreated();
        $attachment = Attachment::first();
        $onDisk = Storage::disk('local')->get(DB::table('attachments')->where('id', $attachment->id)->value('path'));
        $this->assertStringNotContainsString("\x89PNG", $onDisk);
    }

    public function test_non_image_upload_disguised_as_jpg_is_rejected(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $data = $this->fileRequest();
        $data['validIdFront'] = UploadedFile::fake()->createWithContent('shell.jpg', '<?php system($_GET["c"]); ?>');

        $this->withToken($resident)->post('/api/concerns', $data, ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJsonValidationErrors('validIdFront');
        $this->assertSame(0, Concern::count());
    }

    public function test_request_requires_all_four_documents(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $data = $this->fileRequest();
        unset($data['cedula']);

        $this->withToken($resident)->post('/api/concerns', $data, ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJsonValidationErrors('cedula');
    }

    public function test_security_headers_are_present(): void
    {
        $this->getJson('/api/concerns')
            ->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertHeader('Referrer-Policy', 'no-referrer')
            ->assertHeaderMissing('X-Powered-By');
    }
}
