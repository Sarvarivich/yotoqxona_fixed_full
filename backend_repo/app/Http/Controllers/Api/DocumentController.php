<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;

class DocumentController extends Controller
{
    /**
     * Ruxsat berilgan hujjat turlari va ular saqlanadigan ustunlar.
     */
    private const TYPE_COLUMN_MAP = [
        'student_card' => 'student_card_path',
        'payment_receipt' => 'payment_receipt_doc_path',
        'medical_certificate' => 'medical_certificate_path',
    ];

    /**
     * Talabaning hujjat URL'larini olish.
     * Talaba o'zinikini, admin/mudir/moliyachi/superadmin istalgan talabanikini ko'ra oladi.
     */
    public function show(Request $request, string $studentId)
    {
        $user = $request->user();

        if ($user->role === 'talaba' && $user->id !== $studentId) {
            return response()->json([
                'success' => false,
                'message' => 'Sizga bu talaba hujjatlarini ko\'rish uchun ruxsat yo\'q.',
            ], 403);
        }

        $student = User::findOrFail($studentId);

        return response()->json([
            'success' => true,
            'data' => $this->formatDocuments($student),
        ]);
    }

    /**
     * Hujjat yuklash (kamera/galereyadan olingan rasm yoki fayl).
     */
    public function upload(Request $request, string $studentId)
    {
        $user = $request->user();

        if ($user->role === 'talaba' && $user->id !== $studentId) {
            return response()->json([
                'success' => false,
                'message' => 'Sizga bu talaba uchun hujjat yuklash ruxsati yo\'q.',
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'document_type' => 'required|string|in:' . implode(',', array_keys(self::TYPE_COLUMN_MAP)),
            'file' => 'required|file|mimes:jpeg,png,jpg,webp,pdf|max:10240',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Hujjat ma\'lumotlari xato yoki fayl yuklanmadi.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $student = User::findOrFail($studentId);
        $column = self::TYPE_COLUMN_MAP[$request->document_type];

        // Eski faylni tozalash (bo'lsa)
        if ($student->$column) {
            Storage::disk('public')->delete($student->$column);
        }

        $path = $request->file('file')->store("documents/$studentId", 'public');
        $student->update([$column => $path]);

        return response()->json([
            'success' => true,
            'message' => 'Hujjat muvaffaqiyatli yuklandi.',
            'data' => $this->formatDocuments($student),
        ]);
    }

    private function formatDocuments(User $student): array
    {
        $data = [];
        foreach (self::TYPE_COLUMN_MAP as $type => $column) {
            $data["{$type}_url"] = $student->$column ? asset('storage/' . $student->$column) : null;
        }
        return $data;
    }
}
