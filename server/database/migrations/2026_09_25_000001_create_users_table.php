<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('full_name', 100);
            $table->string('email', 191)->unique();
            // Argon2id hash (see config HASH_DRIVER). Never the plain password.
            $table->string('password');
            // Role lives on the server; the client never decides who is admin.
            $table->enum('role', ['resident', 'admin'])->default('resident');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
