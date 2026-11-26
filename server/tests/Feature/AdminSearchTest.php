<?php

namespace Tests\Feature;

use App\Models\Concern;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminSearchTest extends TestCase
{
    use RefreshDatabase;

    private string $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->complaint('juan@example.com', 'Juan Dela Cruz', 'Broken streetlight');
        $this->complaint('maria@example.com', 'Maria Santos', 'Loud karaoke at night');

        $this->admin = $this->signUp('admin@example.com', extra: ['full_name' => 'Barangay Admin'])->json('accessToken');
        User::where('email', 'admin@example.com')->first()->forceFill(['role' => 'admin'])->save();
        $this->app['auth']->forgetGuards();
    }

    private function complaint(string $email, string $name, string $title): void
    {
        $token = $this->signUp($email, extra: ['full_name' => $name])->json('accessToken');
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->postJson('/api/concerns', [
            'type' => 'Complaint', 'title' => $title, 'description' => 'Details here.',
        ])->assertCreated();
        $this->app['cache']->store()->flush();
    }

    private function search(string $q): array
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($this->admin)
            ->getJson('/api/admin/concerns?'.http_build_query(['q' => $q]))
            ->assertOk()
            ->json();
    }

    private function titles(array $body): array
    {
        return array_column($body['concerns'], 'title');
    }

    public function test_finds_by_resident_name_email_and_title(): void
    {
        $this->assertSame(['Broken streetlight'], $this->titles($this->search('juan dela')));
        $this->assertSame(['Loud karaoke at night'], $this->titles($this->search('maria@')));
        $this->assertSame(['Loud karaoke at night'], $this->titles($this->search('KARAOKE')));
    }

    public function test_finds_by_reference_number(): void
    {
        $id = Concern::where('title', 'Loud karaoke at night')->value('id');
        $ref = 'CP-'.now()->year.'-'.str_pad((string) $id, 4, '0', STR_PAD_LEFT);

        $this->assertSame(['Loud karaoke at night'], $this->titles($this->search($ref)));
        $this->assertSame(['Loud karaoke at night'], $this->titles($this->search((string) $id)));
    }

    public function test_total_counts_only_matching_records(): void
    {
        $this->assertSame(1, $this->search('streetlight')['total']);
        $this->assertSame(0, $this->search('no such thing')['total']);
    }

    public function test_search_text_is_data_not_sql(): void
    {
        $this->assertSame([], $this->titles($this->search("' OR '1'='1")));
        $this->assertSame([], $this->titles($this->search('%')));
        $this->assertSame(2, Concern::count()); // nothing was changed or dropped
    }

    public function test_filters_by_the_philippine_day_it_was_filed(): void
    {
        // 23:30 in Manila on Nov 20 is 15:30 UTC: it belongs to Nov 20, not Nov 21.
        Concern::where('title', 'Broken streetlight')->update(['created_at' => '2026-11-20 15:30:00']);
        // 00:30 in Manila on Nov 21 is 16:30 UTC on Nov 20.
        Concern::where('title', 'Loud karaoke at night')->update(['created_at' => '2026-11-20 16:30:00']);

        $on = function (string $date) {
            $this->app['auth']->forgetGuards();

            return array_column($this->withToken($this->admin)
                ->getJson("/api/admin/concerns?date={$date}")->assertOk()->json('concerns'), 'title');
        };

        $this->assertSame(['Broken streetlight'], $on('2026-11-20'));
        $this->assertSame(['Loud karaoke at night'], $on('2026-11-21'));
        $this->assertSame([], $on('2026-11-22'));

        $this->withToken($this->admin)->getJson('/api/admin/concerns?date=yesterday')->assertStatus(422);
    }

    public function test_residents_cannot_search_everyone(): void
    {
        $resident = $this->signUp('pedro@example.com')->json('accessToken');
        $this->app['auth']->forgetGuards();

        $this->withToken($resident)->getJson('/api/admin/concerns?q=juan')->assertForbidden();
    }
}
