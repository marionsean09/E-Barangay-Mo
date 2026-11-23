<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
| Project plan: residents see Pending, In Progress, Resolved or Rejected, and
| give consent to the privacy notice at sign-up (RA 10173, sections 12 and 13).
*/
return new class extends Migration
{
    public function up(): void
    {
        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE concerns MODIFY status ENUM('Pending','In Progress','Ready for Pickup','Resolved','Rejected') NOT NULL DEFAULT 'Pending'");
        }

        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('privacy_consented_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('privacy_consented_at');
        });

        DB::table('concerns')->where('status', 'In Progress')->update(['status' => 'Pending']);

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE concerns MODIFY status ENUM('Pending','Ready for Pickup','Resolved','Rejected') NOT NULL DEFAULT 'Pending'");
        }
    }
};
