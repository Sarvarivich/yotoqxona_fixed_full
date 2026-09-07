<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SurveyQuestion extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'survey_id',
        'question',
        'type',
        'options',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'options' => 'array',
            'sort_order' => 'integer',
        ];
    }

    public function survey()
    {
        return $this->belongsTo(Survey::class);
    }
}
