<?php

namespace App\Http\Controllers;

use App\Models\Attachment;
use App\Services\AttachmentStore;
use App\Support\SecurityLog;
use Illuminate\Support\Facades\Gate;
use RuntimeException;
use Symfony\Component\HttpFoundation\Response;

class AttachmentController extends Controller
{
    public function show(Attachment $attachment, AttachmentStore $store): Response
    {
        // Only the owner of the concern or an admin may view its photos.
        Gate::authorize('view', $attachment->concern);

        try {
            $contents = $store->read($attachment);
        } catch (RuntimeException $e) {
            SecurityLog::event('attachment_integrity_failed', [], null, 'attachment', $attachment->id);

            return response()->json(['message' => 'This file failed its integrity check.'], 409);
        }

        return response($contents, 200, [
            'Content-Type' => $attachment->mime,
            'Content-Disposition' => 'inline; filename="attachment-'.$attachment->id.'"',
        ]);
    }
}
