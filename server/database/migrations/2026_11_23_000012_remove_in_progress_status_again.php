<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/*
| "In Progress" is not used: those concerns go back to Pending.
*/
return new class extends Migration
{
    public function up(): void
    {
        DB::table('concerns')->where('status', 'In Progress')->update(['status' => 'Pending']);

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE concerns MODIFY status ENUM('Pending','Ready for Pickup','Resolved','Rejected') NOT NULL DEFAULT 'Pending'");
        }
    }

    public function down(): void
    {
        // Allows the old value again. Which rows used it can't be recovered.
        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE concerns MODIFY status ENUM('Pending','In Progress','Ready for Pickup','Resolved','Rejected') NOT NULL DEFAULT 'Pending'");
        }
    }
};
