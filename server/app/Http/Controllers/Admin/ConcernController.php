<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateConcernRequest;
use App\Models\AuditLog;
use App\Models\Concern;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
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
            'q' => ['sometimes', 'nullable', 'string', 'max:100'],
            // Day the record was filed, as a Philippine calendar date.
            'date' => ['sometimes', 'date_format:Y-m-d'],
        ]);
        $direction = ($filters['sort'] ?? 'newest') === 'oldest' ? 'asc' : 'desc';
        $search = trim((string) ($filters['q'] ?? ''));

        $matching = Concern::query()
            ->when($filters['date'] ?? null, function ($query, $date) {
                // created_at is stored in UTC; a Manila day starts at 16:00 UTC the day before.
                $start = CarbonImmutable::createFromFormat('!Y-m-d', $date, Concern::TIMEZONE)->utc();
                $query->where('created_at', '>=', $start)->where('created_at', '<', $start->addDay());
            })
            ->when($filters['type'] ?? null, fn ($query, $type) => $query->where('type', $type))
            ->when($filters['status'] ?? null, fn ($query, $status) => $query->where('status', $status))
            ->when($search !== '', fn ($query) => $this->search($query, $search));
        $total = (clone $matching)->count();

        // Sorted in the database, so "oldest" means oldest of all records.
        // The id keeps the order stable for records saved in the same second.
        $concerns = $matching->with(['attachments', 'user'])
            ->orderBy('created_at', $direction)
            ->orderBy('id', $direction)
            ->limit(self::PAGE_LIMIT)
            ->get();

        // Dashboard totals cover every record, whatever filter is selected.
        $counts = [];
        foreach (Concern::STATUSES as $status) {
            $counts[$status] = Concern::where('status', $status)->count();
        }

        return response()->json([
            'concerns' => $concerns->map->toApi(true),
            'counts' => $counts,
            'total' => $total,
        ]);
    }

    /**
     * Searches every record, not just the page shown: resident name or email,
     * title, document type, concern type, or reference number ("BC-2026-0012",
     * "0012" and "12" all find record 12). Values are bound parameters, never
     * SQL. Descriptions and purposes are encrypted at rest, so they can't be
     * searched.
     */
    private function search(Builder $query, string $search): void
    {
        $like = '%'.addcslashes($search, '\\%_').'%';

        $query->where(function (Builder $where) use ($search, $like) {
            $where->where('title', 'like', $like)
                ->orWhere('request_type', 'like', $like)
                ->orWhere('type', 'like', $like)
                ->orWhereHas('user', fn (Builder $user) => $user
                    ->where('full_name', 'like', $like)
                    ->orWhere('email', 'like', $like));

            // A reference is PREFIX-YEAR-ID; its last number is the record id.
            // Only a whole reference (or bare number) counts, not any text ending in a digit.
            if (preg_match('/^(?:[A-Za-z]{2}-)?(?:\d{4}-)?0*(\d{1,9})$/', $search, $match)) {
                $where->orWhere('id', (int) $match[1]);
            }
        });
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
