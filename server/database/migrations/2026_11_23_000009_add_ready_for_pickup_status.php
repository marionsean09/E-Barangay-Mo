<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
| Document requests get their own "Ready for Pickup" status. Until now a
| Resolved request was displayed as "Ready for pickup", so those rows move to
| the new status and residents keep seeing the same thing.
*/
return new class extends Migration
{
    public function up(): void
    {
        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE concerns MODIFY status ENUM('Pending','Ready for Pickup','Resolved','Rejected') NOT NULL DEFAULT 'Pending'");
        } else {
            // SQLite (tests) keeps the old enum as a CHECK until the column is rebuilt.
            Schema::table('concerns', fn (Blueprint $table) => $table->string('status', 20)->default('Pending')->change());
        }

        DB::table('concerns')->where('type', 'Request')->where('status', 'Resolved')
            ->update(['status' => 'Ready for Pickup']);

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE concerns ADD CONSTRAINT chk_pickup_request
                CHECK (status <> 'Ready for Pickup' OR type = 'Request')");
        }
    }

    public function down(): void
    {
        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement('ALTER TABLE concerns DROP CONSTRAINT chk_pickup_request');
        }

        DB::table('concerns')->where('status', 'Ready for Pickup')->update(['status' => 'Resolved']);

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE concerns MODIFY status ENUM('Pending','Resolved','Rejected') NOT NULL DEFAULT 'Pending'");
        }
    }
};
