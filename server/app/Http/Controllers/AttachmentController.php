<?php

namespace App\Http\Controllers;

use App\Models\Attachment;
use App\Services\AttachmentStore;
use App\Support\SecurityLog;
use Illuminate\Contracts\Filesystem\FileNotFoundException;
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
        } catch (FileNotFoundException) {
            // Not an attack: the file was lost, e.g. the host's storage was reset.
            SecurityLog::event('attachment_missing', [], null, 'attachment', $attachment->id);

            return response()->json([
                'message' => 'This photo is no longer stored on the server. Please upload it again.',
            ], 410);
        } catch (RuntimeException $e) {
            // Undecryptable or altered: logged with the reason for investigation.
            SecurityLog::event('attachment_integrity_failed', ['reason' => $e->getMessage()], null, 'attachment', $attachment->id);

            return response()->json(['message' => 'This file failed its integrity check.'], 409);
        }

        return response($contents, 200, [
            'Content-Type' => $attachment->mime,
            'Content-Disposition' => 'inline; filename="attachment-'.$attachment->id.'"',
        ]);
    }
}
