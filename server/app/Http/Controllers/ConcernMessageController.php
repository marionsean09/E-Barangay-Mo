<?php

namespace App\Http\Controllers;

use App\Http\Requests\MarkMessagesReadRequest;
use App\Http\Requests\StoreConcernMessageRequest;
use App\Models\AuditLog;
use App\Models\Concern;
use App\Models\ConcernMessage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

/** A complaint's conversation. Open to the resident who filed it and to admins. */
class ConcernMessageController extends Controller
{
    private const MAX_MESSAGES = 200;

    public function index(Request $request, Concern $concern): JsonResponse
    {
        Gate::authorize('message', $concern);

        /** @var \Illuminate\Support\Collection<int, ConcernMessage> $messages */
        $messages = ConcernMessage::with('user')
            ->where('concern_id', $concern->id)
            ->orderByDesc('id')
            ->limit(self::MAX_MESSAGES)
            ->get()
            ->reverse()
            ->values();

        return response()->json([
            'messages' => $messages->map(fn (ConcernMessage $m) => $m->toApi($request->user())),
        ]);
    }

    /** Moves this side's read marker forward, only to a message in this thread. */
    public function read(MarkMessagesReadRequest $request, Concern $concern): JsonResponse
    {
        Gate::authorize('message', $concern);

        $column = Concern::readColumnFor($request->user());
        $latest = ConcernMessage::where('concern_id', $concern->id)
            ->where('id', '<=', $request->validated('last_message_id'))
            ->max('id');

        if ($latest) {
            Concern::whereKey($concern->id)
                ->where(fn ($query) => $query->whereNull($column)->orWhere($column, '<', $latest))
                ->toBase()
                ->update([$column => $latest]);
        }

        return response()->json(['message' => 'Marked as read.']);
    }

    public function store(StoreConcernMessageRequest $request, Concern $concern): JsonResponse
    {
        Gate::authorize('message', $concern);

        $user = $request->user();

        $message = DB::transaction(function () use ($request, $concern, $user) {
            // Row lock: a reply can't land while the complaint is being closed.
            if (Concern::whereKey($concern->id)->lockForUpdate()->firstOrFail()->isLocked()) {
                return null;
            }

            $message = new ConcernMessage(['body' => $request->validated('body')]);
            $message->concern_id = $concern->id;
            $message->user_id = $user->id;
            $message->sender_role = $user->isAdmin() ? 'admin' : 'resident';
            $message->save();

            // Records that a message was sent, never what it says.
            AuditLog::create([
                'user_id' => $user->id,
                'action' => 'concern_message_sent',
                'target_type' => 'concern',
                'target_id' => $concern->id,
                'details' => ['message_id' => $message->id],
                'ip' => $request->ip(),
            ]);

            return $message;
        });

        if (! $message) {
            return response()->json(['message' => 'This complaint is closed. No more replies can be sent.'], 409);
        }

        return response()->json(['message' => $message->setRelation('user', $user)->toApi($user)], 201);
    }
}
