<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
 public function up(): void {
  Schema::create('users', function (Blueprint $table) {
   $table->uuid('id')->primary();
   $table->string('firebase_uid',128)->nullable()->unique();
   $table->string('full_name');
   $table->string('email')->nullable()->unique();
   $table->string('phone',30)->nullable();
   $table->string('password_hash')->nullable();
   $table->string('role',30)->default('talaba')->index();
   $table->string('faculty')->nullable();
   $table->unsignedSmallInteger('course')->nullable();
   $table->string('group_name',100)->nullable();
   $table->text('jshshir_encrypted')->nullable();
   $table->string('passport_id',50)->nullable();
   $table->date('birth_date')->nullable();
   $table->string('region',150)->nullable();
   $table->string('district',150)->nullable();
   $table->string('hostel',20)->nullable()->index();
   $table->string('registered_by',30)->nullable();
   $table->text('fcm_token')->nullable();
   $table->boolean('is_active')->default(true)->index();
   $table->timestamps();
  });
 }
 public function down(): void { Schema::dropIfExists('users'); }
};