<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Helmet-equivalent headers on every response Laravel sends.
 * Static files (JS, WASM, images) get the same headers from public/.htaccess.
 */
class SecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);
        $headers = $response->headers;

        $isHtml = str_contains((string) $headers->get('Content-Type'), 'text/html');

        $headers->set('Content-Security-Policy', config($isHtml ? 'security.csp_app' : 'security.csp_api'));
        $headers->set('X-Frame-Options', 'DENY');
        $headers->set('X-Content-Type-Options', 'nosniff');
        $headers->set('Referrer-Policy', 'no-referrer');
        $headers->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()');
        $headers->set('Cross-Origin-Opener-Policy', 'same-origin');
        $headers->set('Cross-Origin-Resource-Policy', 'same-site');

        // HSTS only makes sense over HTTPS (browsers ignore it on HTTP).
        if ($request->isSecure()) {
            $headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
        }

        // API data must never be cached by shared caches or the browser.
        if ($request->is('api/*')) {
            $headers->set('Cache-Control', 'no-store, private');
        }

        $headers->remove('X-Powered-By');
        header_remove('X-Powered-By');

        return $response;
    }
}
