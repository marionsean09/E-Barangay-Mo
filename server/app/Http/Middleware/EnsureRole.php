<?php

namespace App\Http\Middleware;

use App\Support\SecurityLog;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Server-side RBAC: route middleware "role:admin". The role comes from the
 * users table via the authenticated token, never from the request.
 */
class EnsureRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user || ! in_array($user->role, $roles, true)) {
            SecurityLog::event('permission_denied', [
                'required_role' => implode('|', $roles),
                'actual_role' => $user?->role,
                'method' => $request->method(),
            ]);

            return response()->json(['message' => 'You do not have permission to do this.'], 403);
        }

        return $next($request);
    }
}
