<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Room extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'hostel_id',
        'room_number',
        'hostel_type',
        'floor',
        'capacity',
        'current_occupants',
        'price_per_month',
        'status',
        'facilities',
        'amenities',
        'last_payment_date',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'floor' => 'integer',
            'capacity' => 'integer',
            'current_occupants' => 'integer',
            'price_per_month' => 'float',
            'facilities' => 'array',
            'amenities' => 'array',
            'last_payment_date' => 'datetime',
        ];
    }

    public function hostel()
    {
        return $this->belongsTo(Hostel::class);
    }

    public function roomStudents()
    {
        return $this->hasMany(RoomStudent::class);
    }

    public function activeStudents()
    {
        return $this->hasManyThrough(
            User::class,
            RoomStudent::class,
            'room_id', // Foreign key on room_students table...
            'id', // Foreign key on users table...
            'id', // Local key on rooms table...
            'student_id' // Local key on room_students table...
        )->where('room_students.status', 'active');
    }

    public function payments()
    {
        return $this->hasMany(Payment::class);
    }

    public function updateOccupancy(): void
    {
        $count = $this->roomStudents()->where('status', 'active')->count();
        $this->current_occupants = $count;

        if ($count >= $this->capacity && $this->capacity > 0) {
            $this->status = 'full';
        } elseif ($count > 0) {
            $this->status = 'partially_filled';
        } else {
            $this->status = 'empty';
        }

        $this->save();
    }
}
