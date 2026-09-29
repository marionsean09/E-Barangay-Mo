<?php

return [

    'paths' => ['api/*'],

    'allowed_methods' => ['GET', 'POST', 'PATCH'],

    // Explicit allowlist from ALLOWED_ORIGINS (same list as config/security.php,
    // which loads after this file). A wildcard is never used, because the
    // refresh cookie requires credentials.
    'allowed_origins' => array_values(array_filter(array_map(
        'trim',
        explode(',', (string) env('ALLOWED_ORIGINS', 'http://localhost:5000'))
    ))),

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['Accept', 'Authorization', 'Content-Type', 'X-Requested-With'],

    'exposed_headers' => ['Retry-After'],

    'max_age' => 600,

    'supports_credentials' => true,
];
