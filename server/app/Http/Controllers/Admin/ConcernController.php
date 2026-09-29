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

/** Admin endpoints. Routes are behind the "role:admin" middleware. */
class ConcernController extends Controller
{
    public function index(): JsonResponse
    {
        $concerns = Concern::with(['attachments', 'user'])->latest()->limit(100)->get();

        return response()->json(['concerns' => $concerns->map->toApi(true)]);
    }

    public function update(UpdateConcernRequest $request, Concern $concern): JsonResponse
    {
        // Second check on the object itself, in addition to the route middleware.
        Gate::authorize('update', $concern);

        $changes = $request->validated();

        DB::transaction(function () use ($request, $concern, $changes) {
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
        });

        return response()->json(['concern' => $concern->fresh(['attachments', 'user'])->toApi(true)]);
    }
}
