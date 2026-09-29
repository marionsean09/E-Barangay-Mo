<?php

use App\Http\Middleware\EnsureRole;
use App\Http\Middleware\ForceHttps;
use App\Http\Middleware\SecurityHeaders;
use App\Support\SecurityLog;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
        // The SPA fallback route needs no session or CSRF cookie middleware.
        then: fn () => Route::group([], __DIR__.'/../routes/web.php'),
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Railway/Cloudflare terminate TLS and forward the original scheme.
        $middleware->trustProxies(at: '*');

        $middleware->prepend(ForceHttps::class);
        $middleware->append(SecurityHeaders::class);

        $middleware->alias(['role' => EnsureRole::class]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // These are never written to logs or flashed back to the client.
        $exceptions->dontFlash(['password', 'current_password', 'new_password']);

        // API errors are always JSON (and never include stack traces when APP_DEBUG=false).
        $exceptions->shouldRenderJsonWhen(fn (Request $request) => $request->is('api/*') || $request->expectsJson());

        // Laravel doesn't "report" 403/429s, so they are logged while rendering.
        // Returning null keeps Laravel's normal JSON response.
        $exceptions->render(function (AccessDeniedHttpException $e, Request $request) {
            // Policy denials, e.g. a resident opening another resident's photo.
            SecurityLog::event('permission_denied', ['method' => $request->method()]);

            return null;
        });

        $exceptions->render(function (ThrottleRequestsException $e, Request $request) {
            SecurityLog::event('rate_limited', ['method' => $request->method()]);

            return null;
        });
    })->create();
