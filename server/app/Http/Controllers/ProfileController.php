<?php

namespace App\Http\Controllers;

use App\Http\Requests\UpdateProfileRequest;
use App\Services\TokenService;
use App\Support\SecurityLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class ProfileController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        return response()->json(['user' => $request->user()->toApi()]);
    }

    public function update(UpdateProfileRequest $request, TokenService $tokens): JsonResponse
    {
        $user = $request->user();
        $data = $request->validated();
        $email = strtolower($data['email']);
        $emailChanged = $email !== $user->email;
        $passwordChanged = ! empty($data['new_password']);

        if (($emailChanged || $passwordChanged) && ! Hash::check((string) ($data['current_password'] ?? ''), $user->password)) {
            SecurityLog::event('reauth_failed', ['action' => 'profile_update']);

            return response()->json([
                'message' => 'Your current password is incorrect.',
                'errors' => ['current_password' => ['Your current password is incorrect.']],
            ], 422);
        }

        $user->full_name = $data['full_name'];
        $user->email = $email;
        if ($passwordChanged) {
            $user->password = $data['new_password'];
        }
        $user->save();

        if ($emailChanged || $passwordChanged) {
            // Other devices must log in again with the new credentials.
            $tokens->revokeOtherFamilies($user, $tokens->familyOfCurrentToken($user));
            SecurityLog::event('credentials_changed', ['email_changed' => $emailChanged, 'password_changed' => $passwordChanged]);
        }

        return response()->json(['user' => $user->toApi()]);
    }
}
