<?php

namespace App\Http\Middleware;

use App\Support\SecurityLog;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * CSRF protection for the only endpoints that rely on a cookie
 * (/api/auth/refresh and /api/auth/logout). Every other endpoint needs the
 * Authorization header, which a cross-site form or <img> can't send.
 *
 * Three layers:
 *  1. The refresh cookie is SameSite=Strict, so other sites can't make the
 *     browser send it at all.
 *  2. The Origin header, if present, must be our own origin or allowlisted.
 *  3. A custom X-Requested-With header is required. HTML forms can't set
 *     custom headers, and cross-origin JS can't either without passing the
 *     CORS preflight, which only allowlisted origins pass.
 */
class VerifyOrigin
{
    public function handle(Request $request, Closure $next): Response
    {
        $origin = $request->headers->get('Origin');
        $allowed = array_merge(config('security.allowed_origins'), [$request->getSchemeAndHttpHost()]);

        $originOk = $origin === null || in_array($origin, $allowed, true);
        $headerOk = $request->headers->get('X-Requested-With') === 'XMLHttpRequest';

        if (! $originOk || ! $headerOk) {
            SecurityLog::event('csrf_blocked', ['origin' => $origin, 'has_header' => $headerOk]);

            return response()->json(['message' => 'Cross-site request blocked.'], 403);
        }

        return $next($request);
    }
}
