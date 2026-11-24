<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateConcernRequest;
use App\Models\AuditLog;
use App\Models\Concern;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

/** Admin endpoints. Routes are behind the "role:admin" middleware. */
class ConcernController extends Controller
{
    private const PAGE_LIMIT = 100;

    public function index(Request $request): JsonResponse
    {
        // Allowlisted values only, so a query string can't choose raw SQL columns or order.
        $filters = $request->validate([
            'sort' => ['sometimes', Rule::in(['newest', 'oldest'])],
            'type' => ['sometimes', Rule::in(Concern::TYPES)],
            'status' => ['sometimes', Rule::in(Concern::STATUSES)],
        ]);
        $direction = ($filters['sort'] ?? 'newest') === 'oldest' ? 'asc' : 'desc';

        $matching = Concern::query()
            ->when($filters['type'] ?? null, fn ($query, $type) => $query->where('type', $type))
            ->when($filters['status'] ?? null, fn ($query, $status) => $query->where('status', $status));
        $total = (clone $matching)->count();

        // Sorted in the database, so "oldest" means oldest of all records.
        // The id keeps the order stable for records saved in the same second.
        $concerns = $matching->with(['attachments', 'user'])
            ->orderBy('created_at', $direction)
            ->orderBy('id', $direction)
            ->limit(self::PAGE_LIMIT)
            ->get();

        // Dashboard totals cover every record, whatever filter is selected.
        $byStatus = Concern::query()
            ->select('status')
            ->selectRaw('COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');
        $counts = [];
        foreach (Concern::STATUSES as $status) {
            $counts[$status] = (int) ($byStatus[$status] ?? 0);
        }

        return response()->json([
            'concerns' => $concerns->map->toApi(true),
            'counts' => $counts,
            'total' => $total,
        ]);
    }

    public function update(UpdateConcernRequest $request, Concern $concern): JsonResponse
    {
        // Second check on the object itself, in addition to the route middleware.
        Gate::authorize('update', $concern);

        $changes = $request->validated();

        $saved = DB::transaction(function () use ($request, $concern, $changes) {
            // Row lock: two admins saving at once can't slip past the closed check.
            $concern = Concern::whereKey($concern->id)->lockForUpdate()->firstOrFail();
            if ($concern->isLocked()) {
                return null;
            }

            $before = $concern->only(array_keys($changes));
            $concern->forceFill($changes);
            $concern->updated_by = $request->user()->id;
            $concern->save();

            // The change and its audit record are committed together.
            AuditLog::create([
                'user_id' => $request->user()->id,
                'action' => 'concern_updated',
                'target_type' => 'concern',
                'target_id' => $concern->id,
                'details' => ['before' => $before, 'after' => $changes],
                'ip' => $request->ip(),
            ]);

            return $concern;
        });

        if (! $saved) {
            return response()->json(['message' => 'This concern is closed and can no longer be changed.'], 409);
        }

        return response()->json(['concern' => $saved->fresh(['attachments', 'user'])->toApi(true)]);
    }
}
