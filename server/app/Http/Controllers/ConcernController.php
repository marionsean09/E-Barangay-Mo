<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreConcernRequest;
use App\Models\Concern;
use App\Services\AttachmentStore;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Throwable;

/** Resident endpoints. Every query is scoped to the logged-in user. */
class ConcernController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        // user_id comes from the verified token, never from the request, so
        // a resident can't list someone else's concerns.
        $concerns = Concern::with('attachments')
            ->where('user_id', $request->user()->id)
            ->latest()
            ->limit(50)
            ->get();

        return response()->json(['concerns' => $concerns->map->toApi()]);
    }

    public function store(StoreConcernRequest $request, AttachmentStore $store): JsonResponse
    {
        $data = $request->validated();
        $type = $data['type'];

        // For requests and blotters the server builds the title itself
        // instead of trusting a client-supplied one.
        $fields = match ($type) {
            'Request' => [
                'title' => $data['request_type'],
                'description' => $data['purpose'],
                'purpose' => $data['purpose'],
                'request_type' => $data['request_type'],
            ],
            'Blotter' => [
                'title' => 'Blotter: '.$data['blotter_category'],
                'description' => $data['description'],
                'requested_date' => $data['requested_date'],
            ],
            default => [
                'title' => $data['title'],
                'description' => $data['description'],
            ],
        };

        $files = [];
        try {
            if ($type === 'Request') {
                foreach (Concern::REQUIREMENTS as $key) {
                    $files[] = $store->put($request->file($key), $key);
                }
            }
            foreach ($type === 'Blotter' ? ($request->file('evidence') ?? []) : [] as $photo) {
                $files[] = $store->put($photo, 'evidence');
            }

            // Concern and its attachments are saved together or not at all.
            $concern = DB::transaction(function () use ($request, $type, $fields, $files) {
                $concern = new Concern(['type' => $type, ...$fields]);
                $concern->user_id = $request->user()->id;
                $concern->status = 'Pending';
                $concern->save();
                $concern->attachments()->createMany($files);

                return $concern;
            });
        } catch (Throwable $e) {
            $store->delete(array_column($files, 'path'));
            throw $e;
        }

        return response()->json(['concern' => $concern->load('attachments')->toApi()], 201);
    }
}
