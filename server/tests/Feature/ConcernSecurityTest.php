<?php

namespace Tests\Feature;

use App\Models\Attachment;
use App\Models\AuditLog;
use App\Models\Concern;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;
use PDOException;
use Tests\TestCase;

class ConcernSecurityTest extends TestCase
{
    use RefreshDatabase;

    private function tokenFor(string $email, string $role = 'resident'): string
    {
        $token = $this->signUp($email, extra: ['full_name' => 'Test User'])->json('accessToken');

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

    private function nextWeekday(): CarbonImmutable
    {
        $day = Concern::today()->addDay();

        return $day->isWeekend() ? $day->next('Monday') : $day;
    }

    private function fileRequest(): array
    {
        return [
            'type' => 'Request',
            'request_type' => 'Barangay Clearance',
            'purpose' => 'Employment',
            'requested_date' => $this->nextWeekday()->toDateString(),
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

        $this->withToken($admin)->patchJson("/api/admin/concerns/{$id}", ['status' => 'Resolved'])
            ->assertOk()
            ->assertJsonPath('concern.status', 'Resolved');

        $log = AuditLog::where('action', 'concern_updated')->first();
        $this->assertSame('Pending', $log->details['before']['status']);
        $this->assertSame('Resolved', $log->details['after']['status']);
    }

    public function test_ready_for_pickup_is_only_for_document_requests(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $admin = $this->tokenFor('admin@example.com', 'admin');

        $requestId = $this->withToken($resident)->post('/api/concerns', $this->fileRequest(), ['Accept' => 'application/json'])
            ->assertCreated()->json('concern.id');
        $complaintId = $this->withToken($resident)->postJson('/api/concerns', [
            'type' => 'Complaint', 'title' => 'Flooding', 'description' => 'Drainage clogged',
        ])->json('concern.id');

        $this->withToken($admin)->patchJson("/api/admin/concerns/{$requestId}", ['status' => 'Ready for Pickup'])
            ->assertOk()
            ->assertJsonPath('concern.status', 'Ready for Pickup');
        $this->withToken($admin)->patchJson("/api/admin/concerns/{$requestId}", ['status' => 'Resolved'])
            ->assertOk()
            ->assertJsonPath('concern.status', 'Resolved');

        $this->withToken($admin)->patchJson("/api/admin/concerns/{$complaintId}", ['status' => 'Ready for Pickup'])
            ->assertStatus(422);
        $this->assertSame('Pending', Concern::find($complaintId)->status);
    }

    public function test_resolved_concern_cannot_be_changed_or_replied_to(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $admin = $this->tokenFor('admin@example.com', 'admin');
        $id = $this->withToken($resident)->postJson('/api/concerns', [
            'type' => 'Complaint', 'title' => 'Flooding', 'description' => 'Drainage clogged',
        ])->json('concern.id');
        $this->withToken($resident)->postJson("/api/concerns/{$id}/messages", ['body' => 'Before closing'])
            ->assertCreated();

        $this->withToken($admin)->patchJson("/api/admin/concerns/{$id}", ['status' => 'Resolved'])->assertOk();
        $audits = AuditLog::where('action', 'concern_updated')->count();

        $this->withToken($admin)->patchJson("/api/admin/concerns/{$id}", ['status' => 'Pending'])->assertStatus(409);
        $this->withToken($admin)->patchJson("/api/admin/concerns/{$id}", ['final_date' => $this->nextWeekday()->toDateString()])
            ->assertStatus(409);
        $this->withToken($admin)->postJson("/api/concerns/{$id}/messages", ['body' => 'Admin late'])->assertStatus(409);
        $this->withToken($resident)->postJson("/api/concerns/{$id}/messages", ['body' => 'Resident late'])->assertStatus(409);

        $this->assertSame('Resolved', Concern::find($id)->status);
        $this->assertNull(Concern::find($id)->final_date);
        $this->assertSame($audits, AuditLog::where('action', 'concern_updated')->count());

        // The history stays readable.
        $this->withToken($resident)->getJson("/api/concerns/{$id}/messages")
            ->assertOk()
            ->assertJsonCount(1, 'messages');
    }

    public function test_rejected_concern_cannot_be_changed_or_replied_to(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $admin = $this->tokenFor('admin@example.com', 'admin');
        $id = $this->withToken($resident)->postJson('/api/concerns', [
            'type' => 'Complaint', 'title' => 'Flooding', 'description' => 'Drainage clogged',
        ])->json('concern.id');

        $this->withToken($admin)->patchJson("/api/admin/concerns/{$id}", ['status' => 'Rejected'])->assertOk();

        $this->withToken($admin)->patchJson("/api/admin/concerns/{$id}", ['status' => 'Pending'])->assertStatus(409);
        $this->withToken($admin)->patchJson("/api/admin/concerns/{$id}", ['status' => 'Resolved'])->assertStatus(409);
        $this->withToken($admin)->postJson("/api/concerns/{$id}/messages", ['body' => 'Admin late'])->assertStatus(409);
        $this->withToken($resident)->postJson("/api/concerns/{$id}/messages", ['body' => 'Resident late'])->assertStatus(409);

        $this->assertSame('Rejected', Concern::find($id)->status);
        $this->withToken($resident)->getJson("/api/concerns/{$id}/messages")
            ->assertOk()
            ->assertJsonCount(0, 'messages');
    }

    public function test_admin_can_sort_and_filter_all_records(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $admin = $this->tokenFor('admin@example.com', 'admin');
        $ownerId = User::where('email', 'res@example.com')->value('id');

        // More records than one page, so sorting must happen in the database.
        for ($i = 1; $i <= 101; $i++) {
            $concern = new Concern([
                'type' => $i === 1 ? 'Suggestion' : 'Complaint',
                'title' => "Record {$i}",
                'description' => 'Details',
            ]);
            $concern->user_id = $ownerId;
            $concern->status = $i === 101 ? 'Rejected' : 'Pending';
            $concern->created_at = now()->subDays(200 - $i);
            $concern->save();
        }

        $this->withToken($admin)->getJson('/api/admin/concerns')
            ->assertOk()
            ->assertJsonCount(100, 'concerns')
            ->assertJsonPath('concerns.0.title', 'Record 101')
            ->assertJsonPath('total', 101)
            ->assertJsonPath('counts.Pending', 100)
            ->assertJsonPath('counts.Rejected', 1);

        $this->withToken($admin)->getJson('/api/admin/concerns?sort=oldest')
            ->assertOk()
            ->assertJsonPath('concerns.0.title', 'Record 1');

        $this->withToken($admin)->getJson('/api/admin/concerns?type=Suggestion')
            ->assertJsonCount(1, 'concerns')
            ->assertJsonPath('total', 1)
            ->assertJsonPath('counts.Pending', 100);

        $this->withToken($admin)->getJson('/api/admin/concerns?type=Complaint&status=Rejected')
            ->assertJsonCount(1, 'concerns')
            ->assertJsonPath('concerns.0.title', 'Record 101');

        foreach (['sort=created_at', 'type=Unknown', 'status=Closed'] as $query) {
            $this->withToken($admin)->getJson("/api/admin/concerns?{$query}")->assertStatus(422);
        }
        $this->withToken($resident)->getJson('/api/admin/concerns?sort=oldest')->assertStatus(403);
    }

    public function test_admin_is_notified_of_every_new_request_and_report(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $admin = $this->tokenFor('admin@example.com', 'admin');

        $requestId = $this->withToken($resident)->post('/api/concerns', $this->fileRequest(), ['Accept' => 'application/json'])
            ->assertCreated()->json('concern.id');
        $blotterId = $this->withToken($resident)->postJson('/api/concerns', [
            'type' => 'Blotter',
            'blotter_category' => 'Other',
            'description' => 'Details',
            'requested_date' => $this->nextWeekday()->toDateString(),
        ])->assertCreated()->json('concern.id');
        $complaintId = $this->withToken($resident)->postJson('/api/concerns', [
            'type' => 'Complaint', 'title' => 'Flooding', 'description' => 'Drainage clogged',
        ])->json('concern.id');
        $suggestionId = $this->withToken($resident)->postJson('/api/concerns', [
            'type' => 'Suggestion', 'title' => 'Park', 'description' => 'More trees',
        ])->json('concern.id');

        $response = $this->withToken($admin)->getJson('/api/notifications')
            ->assertOk()
            ->assertJsonPath('unreadCount', 4);
        $this->assertEqualsCanonicalizing(
            ['New document request', 'New blotter report', 'New complaint', 'New suggestion'],
            collect($response->json('notifications'))->pluck('heading')->all(),
        );

        // Residents are not alerted about submissions.
        $this->withToken($resident)->getJson('/api/notifications')->assertJsonPath('unreadCount', 0);

        // Handling a record clears its alert.
        $this->withToken($admin)->patchJson("/api/admin/concerns/{$requestId}", ['status' => 'Ready for Pickup'])->assertOk();
        $this->withToken($admin)->patchJson("/api/admin/concerns/{$blotterId}", ['final_date' => $this->nextWeekday()->toDateString(), 'status' => 'Pending'])->assertOk();
        $this->withToken($admin)->postJson("/api/concerns/{$complaintId}/messages", ['body' => 'On it.'])->assertCreated();

        $this->withToken($admin)->getJson('/api/notifications')
            ->assertJsonPath('unreadCount', 1)
            ->assertJsonPath('notifications.0.concern.id', $suggestionId);
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

    public function test_request_saves_preferred_claim_date_without_confirming_it(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $preferred = $this->nextWeekday()->toDateString();

        // A resident can suggest a date but can't set the official one.
        $this->withToken($resident)->post('/api/concerns', [
            ...$this->fileRequest(),
            'requested_date' => $preferred,
            'claim_date' => $preferred,
            'status' => 'Ready for Pickup',
        ], ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('concern.requestedDate', $preferred)
            ->assertJsonPath('concern.claimDate', null)
            ->assertJsonPath('concern.status', 'Pending');
    }

    public function test_request_rejects_missing_past_weekend_and_far_claim_dates(): void
    {
        // Several bad submissions in a row would otherwise hit the rate limit.
        $this->withoutMiddleware(ThrottleRequests::class);
        $resident = $this->tokenFor('res@example.com');
        $today = Concern::today();
        $saturday = $today->next('Saturday');

        foreach ([
            null,
            'not-a-date',
            $today->toDateString(),
            $today->subDay()->toDateString(),
            $saturday->toDateString(),
            $today->addDays(91)->toDateString(),
        ] as $date) {
            $data = $this->fileRequest();
            if ($date === null) {
                unset($data['requested_date']);
            } else {
                $data['requested_date'] = $date;
            }

            $this->withToken($resident)->post('/api/concerns', $data, ['Accept' => 'application/json'])
                ->assertStatus(422)
                ->assertJsonValidationErrors('requested_date');
        }
        $this->assertSame(0, Concern::count());
    }

    public function test_dates_follow_philippine_time_not_utc(): void
    {
        // 07:00 on Wednesday in Manila is still Tuesday in UTC.
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-11-25 07:00', Concern::TIMEZONE));
        Carbon::setTestNow(CarbonImmutable::parse('2026-11-25 07:00', Concern::TIMEZONE));

        try {
            $resident = $this->tokenFor('res@example.com');

            $this->withToken($resident)->post('/api/concerns', [...$this->fileRequest(), 'requested_date' => '2026-11-25'], ['Accept' => 'application/json'])
                ->assertStatus(422)
                ->assertJsonValidationErrors('requested_date');

            // Exactly 90 days ahead in Manila, a weekday.
            $this->withToken($resident)->post('/api/concerns', [...$this->fileRequest(), 'requested_date' => '2027-02-23'], ['Accept' => 'application/json'])
                ->assertCreated();
        } finally {
            CarbonImmutable::setTestNow();
            Carbon::setTestNow();
        }
    }

    public function test_database_outage_returns_a_safe_message(): void
    {
        Route::get('/api/test-db-down', fn () => throw new QueryException(
            'mysql', 'select secret_column from users', [], new PDOException('SQLSTATE[HY000] [2002] Connection refused'),
        ));

        $response = $this->getJson('/api/test-db-down')->assertStatus(503);

        $this->assertStringContainsString('temporarily unavailable', $response->json('message'));
        $this->assertStringNotContainsString('secret_column', $response->getContent());
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
