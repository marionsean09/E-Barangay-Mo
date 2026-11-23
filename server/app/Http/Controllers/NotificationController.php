<?php

namespace App\Http\Controllers;

use App\Models\Concern;
use App\Models\ConcernMessage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/** Unread complaint replies from the other side. Residents only get their own. */
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
            $concern = $concerns[$thread->concern_id];
            $message = $messages[$thread->latest_id];

            return [
                'concern' => $concern->toApi($isAdmin),
                'unread' => (int) $thread->unread,
                'latestMessageId' => (int) $thread->latest_id,
                'senderName' => $isAdmin ? $concern->user->full_name : 'Barangay Office',
                'preview' => Str::limit($message->body, 80),
                'createdAt' => $message->created_at?->toIso8601String(),
            ];
        })->values();

        return response()->json([
            'unreadCount' => $items->sum('unread'),
            'notifications' => $items,
        ]);
    }
}
