<?php

return [

    // Short-lived access token (Sanctum personal access token), sent in the
    // Authorization header and kept only in the Flutter app's memory.
    'access_token_minutes' => (int) env('ACCESS_TOKEN_MINUTES', 15),

    // Longer-lived refresh token, stored only as an httpOnly cookie.
    'refresh_token_days' => (int) env('REFRESH_TOKEN_DAYS', 7),

    'refresh_cookie' => [
        'name' => 'ebm_refresh',
        // Only sent to the auth endpoints, not to every API call.
        'path' => '/api/auth',
        // Browsers accept Secure cookies on http://localhost, so this stays on locally too.
        'secure' => (bool) env('REFRESH_COOKIE_SECURE', true),
        'same_site' => 'strict',
    ],

    // Exact origins allowed to call the API from a browser (CORS) and to use
    // the cookie-based auth endpoints (CSRF origin check). Never "*".
    'allowed_origins' => array_values(array_filter(array_map(
        'trim',
        explode(',', (string) env('ALLOWED_ORIGINS', 'http://localhost:5000'))
    ))),

    'force_https' => (bool) env('FORCE_HTTPS', false),

    // CSP for the Flutter web page. Flutter's CanvasKit renderer is
    // WebAssembly ('wasm-unsafe-eval') and injects inline styles; fallback
    // glyph fonts come from fonts.gstatic.com.
    'csp_app' => implode('; ', [
        "default-src 'self'",
        "script-src 'self' 'wasm-unsafe-eval'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: blob:",
        "font-src 'self' data: https://fonts.gstatic.com",
        "connect-src 'self' https://fonts.gstatic.com",
        "worker-src 'self' blob:",
        "object-src 'none'",
        "base-uri 'self'",
        "form-action 'self'",
        "frame-ancestors 'none'",
    ]),

    // CSP for JSON/file responses: nothing may load or frame them.
    'csp_api' => "default-src 'none'; frame-ancestors 'none'",
];
