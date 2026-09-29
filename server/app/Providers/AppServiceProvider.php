<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        if (config('security.force_https')) {
            URL::forceScheme('https');
        }

        $this->configureRateLimiting();
    }

    /**
     * Throttling on the endpoints attackers target. Exceeding a limit returns
     * HTTP 429 with a Retry-After header and is written to the security log.
     */
    private function configureRateLimiting(): void
    {
        // Brute force / credential stuffing: 5 tries per minute per email+IP,
        // and 20 per minute per IP across all emails.
        RateLimiter::for('login', fn (Request $request) => [
            Limit::perMinute(5)->by(strtolower((string) $request->input('email')).'|'.$request->ip()),
            Limit::perMinute(20)->by('ip:'.$request->ip()),
        ]);

        // Mass account creation.
        RateLimiter::for('register', fn (Request $request) => Limit::perHour(10)->by($request->ip()));

        RateLimiter::for('refresh', fn (Request $request) => Limit::perMinute(30)->by($request->ip()));

        // Spam submissions (each can carry 4 photos).
        RateLimiter::for('submit', fn (Request $request) => Limit::perMinute(5)->by('user:'.$request->user()?->id));

        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(120)->by('user:'.($request->user()?->id ?? $request->ip())));
    }
}
