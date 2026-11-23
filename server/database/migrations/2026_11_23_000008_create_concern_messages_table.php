<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
| Replies on a complaint. Append-only: the app's DB account gets SELECT and
| INSERT here, so a message can't be edited or erased after it is sent.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('concern_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('concern_id')->constrained()->restrictOnDelete();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            // The sender's role when the message was sent.
            $table->enum('sender_role', ['resident', 'admin']);
            // Encrypted at application level, so this holds ciphertext.
            $table->text('body');
            $table->timestamp('created_at')->nullable();

            $table->index(['concern_id', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('concern_messages');
    }
};
