<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('expenses', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->decimal('amount', 14, 2);
            $table->string('category', 100)->nullable(); // kommunal, ta'mirlash, inventar, maosh, boshqa
            $table->text('description')->nullable();
            $table->date('date')->nullable();
            $table->foreignUuid('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('finance_budgets', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('month_key', 20)->index(); // e.g. "09"
            $table->unsignedSmallInteger('year'); // e.g. 2026
            $table->decimal('amount', 14, 2);
            $table->text('description')->nullable();
            $table->foreignUuid('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['month_key', 'year']);
        });
    }

    public function down(): void {
        Schema::dropIfExists('finance_budgets');
        Schema::dropIfExists('expenses');
    }
};
