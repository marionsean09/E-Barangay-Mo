<?php

use App\Http\Controllers\Admin\ConcernController as AdminConcernController;
use App\Http\Controllers\AttachmentController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ConcernController;
use App\Http\Controllers\ProfileController;
use App\Http\Middleware\VerifyOrigin;
use Illuminate\Support\Facades\Route;

/*
| Public auth endpoints. Throttled per IP and per email (see AppServiceProvider).
*/
Route::prefix('auth')->group(function () {
    Route::post('register', [AuthController::class, 'register'])->middleware('throttle:register');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:login');

    // These two read the httpOnly refresh cookie, so they get the CSRF check.
    Route::middleware([VerifyOrigin::class, 'throttle:refresh'])->group(function () {
        Route::post('refresh', [AuthController::class, 'refresh']);
        Route::post('logout', [AuthController::class, 'logout']);
    });
});

/*
| Everything below needs a valid, unexpired access token.
*/
Route::middleware(['auth:sanctum', 'throttle:api'])->group(function () {
    Route::get('me', [ProfileController::class, 'show']);
    Route::patch('me', [ProfileController::class, 'update']);

    // Resident: own concerns only.
    Route::get('concerns', [ConcernController::class, 'index']);
    Route::post('concerns', [ConcernController::class, 'store'])->middleware('throttle:submit');

    // Owner or admin (checked by ConcernPolicy).
    Route::get('attachments/{attachment}', [AttachmentController::class, 'show']);

    // Admin only: enforced on the server, not just by hiding buttons.
    Route::middleware('role:admin')->prefix('admin')->group(function () {
        Route::get('concerns', [AdminConcernController::class, 'index']);
        Route::patch('concerns/{concern}', [AdminConcernController::class, 'update']);
    });
});
