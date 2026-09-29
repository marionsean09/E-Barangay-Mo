<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * HTTP -> HTTPS redirect in production (FORCE_HTTPS=true). The TLS
 * certificate itself is managed by the host (Railway) / Cloudflare.
 */
class ForceHttps
{
    public function handle(Request $request, Closure $next): Response
    {
        if (config('security.force_https') && ! $request->isSecure()) {
            return redirect()->secure($request->getRequestUri(), 301);
        }

        return $next($request);
    }
}
