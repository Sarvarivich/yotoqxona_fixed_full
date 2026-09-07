<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Complaint extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'student_id',
        'hostel_id',
        'target_role',
        'title',
        'description',
        'category',
        'priority',
        'status',
        'is_anonymous',
        'assigned_to',
        'response',
        'responded_by',
        'responded_by_role',
        'resolved_at',
    ];

    protected function casts(): array
    {
        return [
            'is_anonymous' => 'boolean',
            'resolved_at' => 'datetime',
        ];
    }

    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    public function hostel()
    {
        return $this->belongsTo(Hostel::class);
    }

    public function assignedTo()
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }

    public function respondedBy()
    {
        return $this->belongsTo(User::class, 'responded_by');
    }

    public function attachments()
    {
        return $this->hasMany(ComplaintAttachment::class);
    }
}
