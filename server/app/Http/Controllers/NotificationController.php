<?php

namespace App\Http\Controllers;

use App\Models\Concern;
use App\Models\ConcernMessage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Unread complaint replies from the other side, plus new submissions for
 * admins. Residents only get replies on their own complaints.
 */
class NotificationController extends Controller
{
    private const MAX_THREADS = 50;

    private const MAX_UNREAD_ROWS = 1000;

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $isAdmin = $user->isAdmin();
        // A fixed column name from the model, never from the request.
        $readColumn = Concern::readColumnFor($user);

        $threads = DB::table('concern_messages as m')
            ->join('concerns as c', 'c.id', '=', 'm.concern_id')
            ->where('c.type', 'Complaint')
            ->where('m.sender_role', $isAdmin ? 'resident' : 'admin')
            ->where(fn ($query) => $query->whereNull("c.{$readColumn}")->orWhereColumn('m.id', '>', "c.{$readColumn}"))
            ->when(! $isAdmin, fn ($query) => $query->where('c.user_id', $user->id))
            ->orderByDesc('m.id')
            ->limit(self::MAX_UNREAD_ROWS)
            ->get(['m.id', 'm.concern_id'])
            ->groupBy('concern_id')
            ->map(fn ($rows, $concernId) => (object) [
                'concern_id' => (int) $concernId,
                'unread' => $rows->count(),
                'latest_id' => (int) $rows->first()->id, // Rows are newest first.
            ])
            ->sortByDesc('latest_id')
            ->take(self::MAX_THREADS)
            ->values();

        $concerns = Concern::with(['attachments', 'user'])
            ->whereIn('id', $threads->pluck('concern_id'))
            ->get()
            ->keyBy('id');
        $messages = ConcernMessage::whereIn('id', $threads->pluck('latest_id'))->get()->keyBy('id');

        $items = $threads->map(function ($thread) use ($concerns, $messages, $isAdmin) {
            /** @var Concern $concern */
            $concern = $concerns[$thread->concern_id];
            $message = $messages[$thread->latest_id];

            return [
                'key' => "reply-{$thread->latest_id}",
                'kind' => 'reply',
                'heading' => $concern->title,
                // Residents only reach their own concerns, so this is their own name.
                'concern' => $concern->toApi(true),
                'unread' => (int) $thread->unread,
                'latestMessageId' => (int) $thread->latest_id,
                'senderName' => $isAdmin ? $concern->user->full_name : 'Barangay Office',
                'preview' => Str::limit($message->body, 80),
                'createdAt' => $message->created_at?->toIso8601String(),
            ];
        })->values();

        if ($isAdmin) {
            $items = $items->concat($this->newSubmissions($threads->pluck('concern_id')->all()))
                ->sortByDesc('createdAt')
                ->values();
        }

        return response()->json([
            'unreadCount' => $items->sum('unread'),
            'notifications' => $items,
        ]);
    }

    /**
     * Requests and reports no admin has handled yet: still Pending, never
     * updated by an admin, and with no admin reply. Shared by all admins.
     *
     * @param  array<int, int>  $withUnreadReplies  Already listed as a reply.
     */
    private function newSubmissions(array $withUnreadReplies): Collection
    {
        $labels = [
            'Request' => 'New document request',
            'Blotter' => 'New blotter report',
            'Complaint' => 'New complaint',
            'Suggestion' => 'New suggestion',
        ];

        return Concern::with(['attachments', 'user'])
            ->where('status', 'Pending')
            ->whereNull('updated_by')
            ->whereNotIn('id', $withUnreadReplies)
            ->whereNotExists(fn ($query) => $query->select('m.id')
                ->from('concern_messages as m')
                ->whereColumn('m.concern_id', 'concerns.id')
                ->where('m.sender_role', 'admin'))
            ->latest()
            ->orderByDesc('id')
            ->limit(self::MAX_THREADS)
            ->get()
            ->map(function ($concern) use ($labels) {
                /** @var Concern $concern */
                return [
                    'key' => "new-{$concern->id}",
                    'kind' => 'new',
                    'heading' => $labels[$concern->type],
                    'concern' => $concern->toApi(true),
                    'unread' => 1,
                    'latestMessageId' => null,
                    'senderName' => $concern->user->full_name,
                    'preview' => Str::limit($concern->title, 80),
                    'createdAt' => $concern->created_at?->toIso8601String(),
                ];
            })
            ->toBase();
    }
}
