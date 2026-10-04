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
        'must_change_password',
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
            'must_change_password' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        static::deleting(function (User $user) {
            // 1. Faol xonalar bandligini qayta hisoblash uchun xona ID larini olamiz
            $activeRoomIds = RoomStudent::where('student_id', $user->id)
                ->where('status', 'active')
                ->pluck('room_id')
                ->unique();

            // 2. Xona biriktirmalarini o'chiramiz
            RoomStudent::where('student_id', $user->id)->delete();

            // 3. Xonalar bandligini qayta hisoblab yangilaymiz
            foreach ($activeRoomIds as $roomId) {
                $room = Room::find($roomId);
                $room?->updateOccupancy();
            }

            // 4. To'lovlar va to'lov cheklarini o'chiramiz
            Payment::where('student_id', $user->id)->delete();
            PaymentCheck::where('student_id', $user->id)->delete();

            // 5. Arizalarni o'chiramiz
            Application::where('user_id', $user->id)->delete();

            // 6. Murojaatlar va ularning biriktirilgan fayllarini o'chiramiz
            $complaintIds = Complaint::where('student_id', $user->id)->pluck('id');
            if ($complaintIds->isNotEmpty()) {
                ComplaintAttachment::whereIn('complaint_id', $complaintIds)->delete();
                Complaint::whereIn('id', $complaintIds)->delete();
            }

            // 7. Reyting, bildirishnoma, so'rovnoma javoblari, todo yozuvlari
            Rating::where('student_id', $user->id)->delete();
            Notification::where('user_id', $user->id)->delete();
            SurveyAnswer::where('user_id', $user->id)->delete();
            Todo::where('owner_id', $user->id)->delete();

            // 8. Boshqa jadvallardagi ushbu foydalanuvchiga bog'langan tashqi kalitlarni bo'shatamiz
            Payment::where('reviewed_by', $user->id)->update(['reviewed_by' => null]);
            PaymentCheck::where('reviewed_by', $user->id)->update(['reviewed_by' => null]);
            Application::where('reviewed_by', $user->id)->update(['reviewed_by' => null]);
            Complaint::where('assigned_to', $user->id)->update(['assigned_to' => null]);
            Complaint::where('responded_by', $user->id)->update(['responded_by' => null]);
            Announcement::where('created_by', $user->id)->update(['created_by' => null]);
            Expense::where('created_by', $user->id)->update(['created_by' => null]);
            FinanceBudget::where('created_by', $user->id)->update(['created_by' => null]);
            Survey::where('created_by', $user->id)->update(['created_by' => null]);

            // 9. Tokenlarni tozalaymiz
            $user->tokens()->delete();
        });
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
