<?php

namespace App\Http\Controllers;

use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Models\User;
use App\Services\TokenService;
use App\Support\SecurityLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function __construct(private TokenService $tokens) {}

    public function register(RegisterRequest $request): JsonResponse
    {
        $data = $request->validated();

        // role is not fillable, so every new account is a resident.
        $user = User::create([
            'full_name' => $data['full_name'],
            'email' => strtolower($data['email']),
            'password' => $data['password'], // hashed by the 'hashed' cast (argon2id)
        ]);

        SecurityLog::event('register', ['email' => SecurityLog::maskEmail($user->email)], $user->id);

        [$payload, $cookie] = $this->tokens->issue($user, $request);

        return response()->json($payload, 201)->withCookie($cookie);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $email = strtolower($request->validated('email'));
        $user = User::where('email', $email)->first();

        // Always run a hash check, even for unknown emails, so response time
        // doesn't reveal which emails are registered.
        // The fallback is the hash of a random value nobody knows.
        $hash = $user?->password ?? '$argon2id$v=19$m=65536,t=4,p=1$eW43YzdRMUh6SkFYUTFPZg$V+BQvvS8JModvEWPPTvpZGFiuPT1m1DGv5K50S14Jz0';
        $valid = Hash::check($request->validated('password'), $hash) && $user !== null;

        if (! $valid) {
            SecurityLog::event('login_failed', ['email' => SecurityLog::maskEmail($email)], $user?->id);

            return response()->json(['message' => 'Invalid email or password.'], 401);
        }

        if (Hash::needsRehash($user->password)) {
            $user->forceFill(['password' => $request->validated('password')])->save();
        }

        SecurityLog::event('login_success', [], $user->id);

        [$payload, $cookie] = $this->tokens->issue($user, $request);

        return response()->json($payload)->withCookie($cookie);
    }

    public function refresh(Request $request): JsonResponse
    {
        $result = $this->tokens->rotate($request->cookie(config('security.refresh_cookie.name')), $request);

        if (! $result) {
            return response()->json(['message' => 'Session expired. Please log in again.'], 401)
                ->withCookie($this->tokens->forgetCookie());
        }

        [$payload, $cookie] = $result;

        return response()->json($payload)->withCookie($cookie);
    }

    public function logout(Request $request): JsonResponse
    {
        $this->tokens->revokeByCookie($request->cookie(config('security.refresh_cookie.name')));

        return response()->json(['message' => 'Logged out.'])
            ->withCookie($this->tokens->forgetCookie());
    }
}
