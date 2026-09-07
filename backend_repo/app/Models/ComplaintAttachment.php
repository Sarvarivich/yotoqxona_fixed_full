<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ComplaintAttachment extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'complaint_id',
        'category',
        'storage_path',
        'file_name',
        'file_type',
    ];

    public function complaint()
    {
        return $this->belongsTo(Complaint::class);
    }
}
