<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('concerns', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->enum('type', ['Complaint', 'Suggestion', 'Request', 'Blotter']);
            $table->string('title', 150);
            // Encrypted at application level (AES-256-CBC + HMAC via APP_KEY),
            // so these columns hold ciphertext and need TEXT length.
            $table->text('description');
            $table->text('purpose')->nullable();
            $table->string('request_type', 100)->nullable();
            $table->enum('status', ['Pending', 'In Progress', 'Resolved', 'Rejected'])->default('Pending');
            $table->date('requested_date')->nullable();
            $table->date('final_date')->nullable();
            $table->date('claim_date')->nullable();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['user_id', 'created_at']);
            $table->index('status');
        });

        // Integrity rules the database enforces even if the API had a bug.
        // (MySQL 8.0.16+ / MariaDB 10.2+; skipped on the SQLite test database.)
        if (! in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            return;
        }
        DB::statement("ALTER TABLE concerns ADD CONSTRAINT chk_request_type
            CHECK (type <> 'Request' OR request_type IS NOT NULL)");
        DB::statement("ALTER TABLE concerns ADD CONSTRAINT chk_blotter_date
            CHECK (type <> 'Blotter' OR requested_date IS NOT NULL)");
    }

    public function down(): void
    {
        Schema::dropIfExists('concerns');
    }
};
