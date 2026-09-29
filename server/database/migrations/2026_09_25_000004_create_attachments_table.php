<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('attachments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('concern_id')->constrained()->cascadeOnDelete();
            // validIdFront, validIdBack, proofOfAddress, cedula, or evidence
            $table->enum('kind', ['validIdFront', 'validIdBack', 'proofOfAddress', 'cedula', 'evidence']);
            // Random name on the private disk; the file itself is encrypted.
            $table->string('path', 255);
            $table->string('mime', 50);
            $table->unsignedInteger('size');
            // SHA-256 of the plaintext, checked on download to detect tampering.
            $table->char('sha256', 64);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attachments');
    }
};
