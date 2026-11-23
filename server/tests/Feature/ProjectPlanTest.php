<?php

namespace Tests\Feature;

use App\Models\Attachment;
use App\Models\AuditLog;
use App\Models\Concern;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/** Requirements taken directly from the project plan. */
class ProjectPlanTest extends TestCase
{
    use RefreshDatabase;

    private function closedConcern(User $user, string $status, CarbonInterface $updatedAt, string $file): Attachment
    {
        $concern = new Concern(['type' => 'Blotter', 'title' => 'Blotter: Other', 'description' => 'x', 'requested_date' => now()->addDay()]);
        $concern->user_id = $user->id;
        $concern->status = $status;
        $concern->save();

        Storage::disk('local')->put($file, 'ciphertext');
        $attachment = $concern->attachments()->create([
            'kind' => 'evidence', 'path' => $file, 'mime' => 'image/png', 'size' => 10, 'sha256' => str_repeat('a', 64),
        ]);
        DB::table('concerns')->where('id', $concern->id)->update(['updated_at' => $updatedAt]);

        return $attachment;
    }

    public function test_sign_up_requires_privacy_consent_and_records_it(): void
    {
        $account = ['full_name' => 'Juan Dela Cruz', 'email' => 'juan@example.com', 'password' => 'Secret123'];

        $this->postJson('/api/auth/register', $account)
            ->assertStatus(422)
            ->assertJsonValidationErrors('privacy_consent');
        $this->assertSame(0, User::count());

        $this->postJson('/api/auth/register', $account + ['privacy_consent' => true])->assertCreated();
        $this->assertNotNull(User::first()->privacy_consented_at);
    }

    public function test_in_progress_is_not_a_valid_status(): void
    {
        $resident = $this->signUp('res@example.com')->json('accessToken');
        $admin = $this->signUp('admin@example.com')->json('accessToken');
        User::where('email', 'admin@example.com')->first()->forceFill(['role' => 'admin'])->save();

        $id = $this->withToken($resident)->postJson('/api/concerns', [
            'type' => 'Complaint', 'title' => 'Flooding', 'description' => 'Drainage clogged',
        ])->json('concern.id');

        $this->withToken($admin)->patchJson("/api/admin/concerns/{$id}", ['status' => 'In Progress'])
            ->assertStatus(422);
        $this->withToken($resident)->getJson('/api/concerns')->assertJsonPath('concerns.0.status', 'Pending');
    }

    public function test_attachments_are_purged_one_year_after_a_concern_is_closed(): void
    {
        // Tests must never reach the real database through the migrator account.
        config(['security.retention_connection' => config('database.default')]);
        Storage::fake('local');
        $user = User::create(['full_name' => 'Juan', 'email' => 'juan@example.com', 'password' => 'Secret123']);

        $expired = $this->closedConcern($user, 'Resolved', now()->subYear()->subDay(), 'attachments/expired.bin');
        $recent = $this->closedConcern($user, 'Rejected', now()->subMonths(11), 'attachments/recent.bin');
        $open = $this->closedConcern($user, 'Pending', now()->subYears(2), 'attachments/open.bin');

        $this->artisan('attachments:purge --dry-run')->assertSuccessful();
        $this->assertSame(3, Attachment::count());

        $this->artisan('attachments:purge')->assertSuccessful();

        $this->assertNull(Attachment::find($expired->id));
        Storage::disk('local')->assertMissing('attachments/expired.bin');
        $this->assertNotNull(Attachment::find($recent->id));
        $this->assertNotNull(Attachment::find($open->id));
        Storage::disk('local')->assertExists('attachments/recent.bin');
        Storage::disk('local')->assertExists('attachments/open.bin');

        // The concern record itself is never deleted.
        $this->assertSame(3, Concern::count());
        $this->assertTrue(AuditLog::where('action', 'attachments_purged')->exists());
    }
}
