<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\RoomStudent;
use Illuminate\Http\Request;

class ContractController extends Controller
{
    /**
     * Shartnoma faylining storage/app/public/contracts/ ichidagi nomi.
     * Fayl shu nom bilan saqlangan bo'lishi kerak.
     */
    private const CONTRACT_FILE = 'contracts/shartnoma_shablon.doc';

    /**
     * Talaba uchun shartnoma yuklab olish tugmasi ko'rinishi/ko'rinmasligini
     * aniqlash uchun holat: xonasi biriktirilganmi?
     */
    public function status(Request $request)
    {
        $user = $request->user();

        // Shartnoma xonaga biriktirilgan talabaga beriladi.
        //
        // Ilgari tasdiqlangan to'lov talab qilinardi, lekin
        // tartib teskari: avval shartnoma imzolanadi, keyin
        // talaba unga asoslanib to'laydi.
        $hasRoom = RoomStudent::where('student_id', $user->id)
            ->where('status', 'active')
            ->exists();

        return response()->json([
            'success' => true,
            'available' => $hasRoom,
        ]);
    }

    /**
     * Shartnoma faylini yuklab olish.
     * Faqat xonaga biriktirilgan talabaga ruxsat beriladi.
     */
    public function download(Request $request)
    {
        $user = $request->user();

        // Shartnoma xonaga biriktirilgan talabaga beriladi.
        //
        // Ilgari tasdiqlangan to'lov talab qilinardi, lekin
        // tartib teskari: avval shartnoma imzolanadi, keyin
        // talaba unga asoslanib to'laydi.
        $hasRoom = RoomStudent::where('student_id', $user->id)
            ->where('status', 'active')
            ->exists();

        if (!$hasRoom) {
            return response()->json([
                'success' => false,
                'message' => 'Shartnoma xonangiz biriktirilgandan so\'ng yuklab olinadi.',
            ], 403);
        }

        // Shablon ATAYLAB storage/ da emas, resources/ da saqlanadi:
        // Railway'da storage papkasi vaqtinchalik va har deploy'da
        // tozalanadi. resources/ esa kod bilan birga deploy bo'ladi,
        // shuning uchun shartnoma hech qachon yo'qolmaydi.
        $path = resource_path(self::CONTRACT_FILE);

        if (!file_exists($path)) {
            return response()->json([
                'success' => false,
                'message' => 'Shartnoma fayli hali tizimga yuklanmagan. Administratorga murojaat qiling.',
            ], 404);
        }

        return response()->download(
            $path,
            'Yotoqxona_Shartnomasi.doc',
            [
                'Content-Type' => 'application/msword',
            ]
        );
    }
}
