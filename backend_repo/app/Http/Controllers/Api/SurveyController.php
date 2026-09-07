<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Survey;
use App\Models\SurveyAnswer;
use App\Models\SurveyQuestion;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class SurveyController extends Controller
{
    /**
     * Faol so'rovnomalar ro'yxati
     */
    public function index()
    {
        $surveys = Survey::with(['questions'])->where('is_active', true)->get();

        return response()->json([
            'success' => true,
            'data' => $surveys,
        ]);
    }

    /**
     * Bitta so'rovnomani ko'rish
     */
    public function show($id)
    {
        $survey = Survey::with(['questions'])->find($id);

        if (!$survey) {
            return response()->json(['message' => 'So\'rovnoma topilmadi.'], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $survey,
        ]);
    }

    /**
     * So'rovnomaga javob yuborish (Talaba)
     */
    public function submitAnswers(Request $request, $id)
    {
        $survey = Survey::find($id);

        if (!$survey) {
            return response()->json(['message' => 'So\'rovnoma topilmadi.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'answers' => 'required|array',
            'answers.*.question_id' => 'required|exists:survey_questions,id',
            'answers.*.answer' => 'required',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $user = $request->user();

        foreach ($request->answers as $ans) {
            SurveyAnswer::updateOrCreate(
                [
                    'survey_id' => $survey->id,
                    'question_id' => $ans['question_id'],
                    'user_id' => $user->id,
                ],
                [
                    'answer' => is_array($ans['answer']) ? $ans['answer'] : ['value' => $ans['answer']],
                ]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Javoblaringiz qabul qilindi. Rahmat!'
        ]);
    }
}
