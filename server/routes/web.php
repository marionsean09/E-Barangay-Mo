<?php

use Illuminate\Support\Facades\Route;

/*
| In production, the Flutter web build is copied into public/ and Laravel
| serves its index.html for every non-API path. Serving app and API from one
| origin keeps the refresh cookie SameSite=Strict and CORS to a single site.
*/
Route::get('/{path?}', function () {
    $index = public_path('index.html');

    abort_unless(is_file($index), 404, 'Frontend not built. See README: "Build the Flutter web app".');

    return response()->file($index, [
        'Content-Type' => 'text/html; charset=UTF-8',
        'Cache-Control' => 'no-cache',
    ]);
})->where('path', '^(?!api(/|$)).*$');
