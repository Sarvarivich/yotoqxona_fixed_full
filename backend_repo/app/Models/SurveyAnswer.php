<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SurveyAnswer extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'survey_id',
        'question_id',
        'user_id',
        'answer',
    ];

    protected function casts(): array
    {
        return [
            'answer' => 'array',
        ];
    }

    public function survey()
    {
        return $this->belongsTo(Survey::class);
    }

    public function question()
    {
        return $this->belongsTo(SurveyQuestion::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
