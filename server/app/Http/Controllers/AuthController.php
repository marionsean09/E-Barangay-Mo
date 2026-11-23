<?php

namespace App\Http\Controllers;

use App\Http\Requests\GoogleLoginRequest;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Requests\ResendCodeRequest;
use App\Http\Requests\VerifyEmailRequest;
use App\Models\User;
use App\Services\EmailVerification;
use App\Services\GoogleIdToken;
use App\Services\TokenService;
use App\Support\SecurityLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Throwable;

class AuthController extends Controller
{
    // Hash of a random value nobody knows, checked when the email is unknown.
    private const DUMMY_HASH = '$argon2id$v=19$m=65536,t=4,p=1$eW43YzdRMUh6SkFYUTFPZg$V+BQvvS8JModvEWPPTvpZGFiuPT1m1DGv5K50S14Jz0';

    public function __construct(
        private TokenService $tokens,
        private EmailVerification $verification,
    ) {}

    /**
     * Creates the account and emails a code. No session is issued until the
     * code is entered, so nobody can use an email address they don't own.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $data = $request->validated();
        $email = strtolower($data['email']);

        // The validator already rejected verified emails, so any match here is
        // an unfinished sign-up. It is replaced: the old code stops working
        // with the old password, so whoever proves the inbox sets the password.
        $user = User::where('email', $email)->first() ?? new User(['email' => $email]);
        $user->full_name = $data['full_name'];
        $user->password = $data['password']; // hashed by the 'hashed' cast (argon2id)
        $user->save(); // role is not fillable, so every new account is a resident.

        SecurityLog::event('register', ['email' => SecurityLog::maskEmail($email)], $user->id);

        if ($failed = $this->sendCode($user)) {
            return $failed;
        }

        return response()->json([
            'message' => "We sent a 6-digit code to {$email}.",
            'verificationRequired' => true,
            'email' => $email,
        ], 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $email = strtolower($request->validated('email'));
        $user = $this->checkCredentials($email, $request->validated('password'));

        if (! $user) {
            SecurityLog::event('login_failed', ['email' => SecurityLog::maskEmail($email)]);

            return response()->json(['message' => 'Invalid email or password.'], 401);
        }

        if (Hash::needsRehash($user->password)) {
            $user->forceFill(['password' => $request->validated('password')])->save();
        }

        // Right password but the email was never confirmed: send a code
        // (at most once a minute) and ask the app to show the code screen.
        if (! $user->hasVerifiedEmail()) {
            if ($failed = $this->sendCode($user)) {
                return $failed;
            }
            SecurityLog::event('login_unverified', [], $user->id);

            return response()->json([
                'message' => "Verify your email first. We sent a code to {$email}.",
                'verificationRequired' => true,
                'email' => $email,
            ], 403);
        }

        SecurityLog::event('login_success', [], $user->id);

        [$payload, $cookie] = $this->tokens->issue($user, $request);

        return response()->json($payload)->withCookie($cookie);
    }

    /** Correct password + code: the email is verified and the user is logged in. */
    public function verifyEmail(VerifyEmailRequest $request): JsonResponse
    {
        $email = strtolower($request->validated('email'));
        $user = $this->checkCredentials($email, $request->validated('password'));

        if ($user?->hasVerifiedEmail()) {
            return response()->json(['message' => 'This email is already verified. Please log in.'], 409);
        }

        // One generic message for a wrong password, wrong code or expired code.
        if (! $user || ! $this->verification->verify($user, $request->validated('code'))) {
            return response()->json([
                'message' => 'That code is incorrect or has expired.',
                'errors' => ['code' => ['That code is incorrect or has expired.']],
            ], 422);
        }

        [$payload, $cookie] = $this->tokens->issue($user, $request);

        return response()->json($payload)->withCookie($cookie);
    }

    public function resendCode(ResendCodeRequest $request): JsonResponse
    {
        $email = strtolower($request->validated('email'));
        $user = $this->checkCredentials($email, $request->validated('password'));

        if (! $user || $user->hasVerifiedEmail()) {
            return response()->json(['message' => 'Invalid email or password.'], 401);
        }

        $wait = $this->verification->cooldownRemaining($user);
        if ($wait > 0) {
            return response()->json(['message' => "Please wait {$wait} seconds before asking for a new code."], 429)
                ->header('Retry-After', (string) $wait);
        }

        if ($failed = $this->sendCode($user)) {
            return $failed;
        }

        return response()->json(['message' => "We sent a new code to {$email}."]);
    }

    /**
     * "Sign in with Google". Google has already verified the email, so the
     * account is verified straight away; a new account is always a resident.
     */
    public function google(GoogleLoginRequest $request, GoogleIdToken $google): JsonResponse
    {
        if (! $google->isConfigured()) {
            return response()->json(['message' => 'Google sign-in is not set up on this server.'], 503);
        }

        $claims = $google->verify($request->validated('id_token'));
        if (! $claims) {
            SecurityLog::event('google_login_failed');

            return response()->json(['message' => "Google sign-in failed. Please try again."], 401);
        }

        $user = User::where('email', $claims['email'])->first();

        if (! $user) {
            // Random password nobody knows: this account signs in with Google
            // (or sets a password later from Edit profile).
            $user = User::create([
                'full_name' => $this->cleanName($claims['name'], $claims['email']),
                'email' => $claims['email'],
                'password' => bin2hex(random_bytes(32)),
            ]);
            SecurityLog::event('register', ['email' => SecurityLog::maskEmail($user->email), 'via' => 'google'], $user->id);
        } elseif (! $user->hasVerifiedEmail()) {
            // An unfinished sign-up for this address. Google just proved who owns
            // it, so any password set by whoever started that sign-up is replaced.
            $user->password = bin2hex(random_bytes(32));
        }

        if (! $user->hasVerifiedEmail()) {
            $user->forceFill([
                'email_verified_at' => now(),
                'verification_code_hash' => null,
                'verification_expires_at' => null,
                'verification_attempts' => 0,
            ])->save();
        }

        SecurityLog::event('login_success', ['via' => 'google'], $user->id);

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

    /**
     * Returns the user only if the password is right. A hash check always
     * runs, even for unknown emails, so response time doesn't reveal which
     * emails are registered.
     */
    private function checkCredentials(string $email, string $password): ?User
    {
        $user = User::where('email', $email)->first();
        $valid = Hash::check($password, $user?->password ?? self::DUMMY_HASH);

        return $valid ? $user : null;
    }

    /** Keeps only the characters sign-up allows for names; falls back to the email's first part. */
    private function cleanName(string $name, string $email): string
    {
        $clean = trim(preg_replace("/[^\pL\s.'-]+/u", '', $name) ?? '');
        if (mb_strlen($clean) < 2) {
            $clean = trim(preg_replace("/[^\pL]+/u", ' ', strstr($email, '@', true)) ?? '');
        }

        return mb_substr($clean !== '' ? $clean : 'Resident', 0, 100);
    }

    /** Sends a code. Returns an error response only if the email couldn't be sent. */
    private function sendCode(User $user): ?JsonResponse
    {
        try {
            $this->verification->send($user);
        } catch (Throwable $e) {
            report($e);
            SecurityLog::event('verification_email_failed', ['error' => class_basename($e)], $user->id);

            return response()->json([
                'message' => "We couldn't send the verification email right now. Please try again in a few minutes.",
            ], 503);
        }

        return null;
    }
}
