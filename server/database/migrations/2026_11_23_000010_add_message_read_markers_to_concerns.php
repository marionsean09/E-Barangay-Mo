<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
| Newest complaint reply each side has read, used for unread notifications.
| Kept on concerns because the app's DB account can already UPDATE that table.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('concerns', function (Blueprint $table) {
            $table->unsignedBigInteger('resident_read_message_id')->nullable();
            $table->unsignedBigInteger('admin_read_message_id')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('concerns', function (Blueprint $table) {
            $table->dropColumn(['resident_read_message_id', 'admin_read_message_id']);
        });
    }
};
