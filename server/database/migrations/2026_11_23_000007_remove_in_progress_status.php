<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/*
| "In Progress" is retired: those concerns go back to Pending. A blotter with a
| final date still shows as "Scheduled" in the app.
*/
return new class extends Migration
{
    public function up(): void
    {
        DB::table('concerns')->where('status', 'In Progress')->update(['status' => 'Pending']);

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE concerns MODIFY status ENUM('Pending','Resolved','Rejected') NOT NULL DEFAULT 'Pending'");
        }
    }

    public function down(): void
    {
        // Allows the old value again. Which rows used it can't be recovered.
        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE concerns MODIFY status ENUM('Pending','In Progress','Resolved','Rejected') NOT NULL DEFAULT 'Pending'");
        }
    }
};
