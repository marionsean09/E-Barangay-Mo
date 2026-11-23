<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
| Email verification. The code is kept on the users row (not a separate table)
| because the app's DB account has no DELETE privilege: used codes are cleared
| with an UPDATE instead.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('email_verified_at')->nullable()->after('email');
            // HMAC-SHA256 of the 6-digit code. Never the code itself.
            $table->string('verification_code_hash', 64)->nullable()->after('role');
            $table->timestamp('verification_expires_at')->nullable()->after('verification_code_hash');
            $table->timestamp('verification_sent_at')->nullable()->after('verification_expires_at');
            $table->unsignedTinyInteger('verification_attempts')->default(0)->after('verification_sent_at');
        });

        // Accounts that existed before this change (e.g. the admin) keep working.
        DB::table('users')->update(['email_verified_at' => DB::raw('created_at')]);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'email_verified_at',
                'verification_code_hash',
                'verification_expires_at',
                'verification_sent_at',
                'verification_attempts',
            ]);
        });
    }
};
