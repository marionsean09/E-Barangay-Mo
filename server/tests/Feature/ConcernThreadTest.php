<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\ConcernMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ConcernThreadTest extends TestCase
{
    use RefreshDatabase;

    private function tokenFor(string $email, string $role = 'resident'): string
    {
        $token = $this->signUp($email, extra: ['full_name' => 'Test User'])->json('accessToken');
        User::where('email', $email)->first()->forceFill(['role' => $role])->save();

        return $token;
    }

    private function complaint(string $token, string $type = 'Complaint'): int
    {
        return $this->withToken($token)->postJson('/api/concerns', [
            'type' => $type, 'title' => 'Flooding', 'description' => 'Drainage clogged',
        ])->assertCreated()->json('concern.id');
    }

    public function test_resident_and_admin_can_reply_in_the_same_thread(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $admin = $this->tokenFor('admin@example.com', 'admin');
        $id = $this->complaint($resident);

        $this->withToken($resident)->postJson("/api/concerns/{$id}/messages", ['body' => 'Any update?'])
            ->assertCreated()
            ->assertJsonPath('message.senderRole', 'resident')
            ->assertJsonPath('message.isMine', true);

        $this->withToken($admin)->postJson("/api/concerns/{$id}/messages", ['body' => 'Team sent today.'])
            ->assertCreated()
            ->assertJsonPath('message.senderRole', 'admin');

        $this->withToken($resident)->getJson("/api/concerns/{$id}/messages")
            ->assertOk()
            ->assertJsonCount(2, 'messages')
            ->assertJsonPath('messages.0.body', 'Any update?')
            ->assertJsonPath('messages.1.body', 'Team sent today.')
            ->assertJsonPath('messages.1.senderName', 'Barangay Office')
            ->assertJsonPath('messages.1.isMine', false);

        $this->assertSame(2, AuditLog::where('action', 'concern_message_sent')->count());
    }

    public function test_another_resident_cannot_read_or_post(): void
    {
        $alice = $this->tokenFor('alice@example.com');
        $bob = $this->tokenFor('bob@example.com');
        $id = $this->complaint($alice);

        $this->withToken($bob)->getJson("/api/concerns/{$id}/messages")->assertStatus(403);
        $this->withToken($bob)->postJson("/api/concerns/{$id}/messages", ['body' => 'Hi'])->assertStatus(403);

        $this->assertSame(0, ConcernMessage::count());
    }

    public function test_only_complaints_have_a_thread(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $id = $this->complaint($resident, 'Suggestion');

        $this->withToken($resident)->postJson("/api/concerns/{$id}/messages", ['body' => 'Hi'])->assertStatus(403);
    }

    public function test_sender_cannot_be_spoofed_and_body_is_validated(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $id = $this->complaint($resident);

        $this->withToken($resident)->postJson("/api/concerns/{$id}/messages", ['body' => '   '])->assertStatus(422);
        $this->withToken($resident)->postJson("/api/concerns/{$id}/messages", ['body' => str_repeat('a', 1001)])->assertStatus(422);

        $this->withToken($resident)->postJson("/api/concerns/{$id}/messages", [
            'body' => 'Hello', 'sender_role' => 'admin', 'user_id' => 999,
        ])->assertCreated()->assertJsonPath('message.senderRole', 'resident');

        $this->assertSame(User::where('email', 'res@example.com')->value('id'), ConcernMessage::first()->user_id);
    }

    public function test_new_reply_notifies_the_other_side_until_read(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $admin = $this->tokenFor('admin@example.com', 'admin');
        $id = $this->complaint($resident);

        $messageId = $this->withToken($admin)->postJson("/api/concerns/{$id}/messages", ['body' => 'We are on it.'])
            ->json('message.id');

        $this->withToken($admin)->getJson('/api/notifications')->assertOk()->assertJsonPath('unreadCount', 0);
        $this->withToken($resident)->getJson('/api/notifications')
            ->assertOk()
            ->assertJsonPath('unreadCount', 1)
            ->assertJsonPath('notifications.0.concern.id', $id)
            ->assertJsonPath('notifications.0.senderName', 'Barangay Office')
            ->assertJsonPath('notifications.0.preview', 'We are on it.');

        $this->withToken($resident)->postJson("/api/concerns/{$id}/messages/read", ['last_message_id' => $messageId])
            ->assertOk();
        $this->withToken($resident)->getJson('/api/notifications')->assertJsonPath('unreadCount', 0);

        $this->withToken($resident)->postJson("/api/concerns/{$id}/messages", ['body' => 'Thank you']);
        $this->withToken($admin)->getJson('/api/notifications')->assertJsonPath('unreadCount', 1);
    }

    public function test_notifications_and_read_markers_are_private(): void
    {
        $alice = $this->tokenFor('alice@example.com');
        $bob = $this->tokenFor('bob@example.com');
        $admin = $this->tokenFor('admin@example.com', 'admin');
        $id = $this->complaint($alice);
        $messageId = $this->withToken($admin)->postJson("/api/concerns/{$id}/messages", ['body' => 'Private reply'])
            ->json('message.id');

        $this->withToken($bob)->getJson('/api/notifications')->assertOk()->assertJsonPath('unreadCount', 0);
        $this->withToken($bob)->postJson("/api/concerns/{$id}/messages/read", ['last_message_id' => $messageId])
            ->assertStatus(403);

        $this->withToken($alice)->getJson('/api/notifications')->assertJsonPath('unreadCount', 1);
    }

    public function test_message_is_encrypted_at_rest(): void
    {
        $resident = $this->tokenFor('res@example.com');
        $id = $this->complaint($resident);

        $this->withToken($resident)->postJson("/api/concerns/{$id}/messages", ['body' => 'My private address'])
            ->assertCreated();

        $this->assertStringNotContainsString('private address', DB::table('concern_messages')->value('body'));
    }
}
