<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
| "Forgot password" codes. Kept on the users row like the verification code
| (the app's DB account has no DELETE privilege, so used codes are cleared
| with an UPDATE). Separate columns from the verification code, so a reset
| code can never verify an email and a verification code can never reset a
| password.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // HMAC-SHA256 of the 6-digit code. Never the code itself.
            $table->string('reset_code_hash', 64)->nullable()->after('verification_attempts');
            $table->timestamp('reset_expires_at')->nullable()->after('reset_code_hash');
            $table->timestamp('reset_sent_at')->nullable()->after('reset_expires_at');
            $table->unsignedTinyInteger('reset_attempts')->default(0)->after('reset_sent_at');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['reset_code_hash', 'reset_expires_at', 'reset_sent_at', 'reset_attempts']);
        });
    }
};
