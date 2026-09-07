<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, HasUuids, Notifiable;

    protected $fillable = [
        'firebase_uid',
        'full_name',
        'email',
        'phone',
        'password',
        'role',
        'faculty',
        'course',
        'group_name',
        'jshshir',
        'passport_id',
        'birth_date',
        'region',
        'district',
        'hostel',
        'registered_by',
        'fcm_token',
        'additional_data',
        'is_active',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'birth_date' => 'date',
            'course' => 'integer',
            'is_active' => 'boolean',
            'additional_data' => 'array',
            'password' => 'hashed',
        ];
    }

    public function roomAssignments()
    {
        return $this->hasMany(RoomStudent::class, 'student_id');
    }

    public function activeRoomAssignment()
    {
        return $this->hasOne(RoomStudent::class, 'student_id')->where('status', 'active');
    }

    public function payments()
    {
        return $this->hasMany(Payment::class, 'student_id');
    }

    public function paymentChecks()
    {
        return $this->hasMany(PaymentCheck::class, 'student_id');
    }

    public function applications()
    {
        return $this->hasMany(Application::class, 'user_id');
    }

    public function complaints()
    {
        return $this->hasMany(Complaint::class, 'student_id');
    }

    public function notifications()
    {
        return $this->hasMany(Notification::class, 'user_id');
    }
}
