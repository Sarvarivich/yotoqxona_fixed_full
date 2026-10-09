<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\PasswordChangeNotifier;
use App\Services\SmsGateway;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class PasswordResetController extends Controller
{
    // Javob hech qachon raqam tizimda borligini oshkor qilmaydi.
    private const GENERIC = "Agar bu raqam tizimda bo'lsa, tasdiqlash kodi yuborildi.";

    private const CODE_TTL_MIN = 5;
    private const RESET_TTL_MIN = 10;
    private const MAX_ATTEMPTS = 3;
    private const RESEND_COOLDOWN_SEC = 60;

    /**
     * Telefon bo'yicha yagona talabani topadi.
     * Raqamlar solishtirilganda faqat oxirgi 9 ta raqam olinadi
     * (format: +998..., 998..., 90 123 45 67 va h.k. bir xil ishlaydi).
     * Bir nechta talaba bo'lsa null qaytaradi (xavfsizlik uchun).
     */
    private function findStudentByPhone(string $raw): ?User
    {
        $digits = preg_replace('/\D+/', '', $raw);
        if (strlen($digits) < 9) {
            return null;
        }
        $last9 = substr($digits, -9);

        $matches = User::where('role', 'talaba')
            ->where('is_active', true)
            ->whereRaw("right(regexp_replace(phone, '\\D', '', 'g'), 9) = ?", [$last9])
            ->limit(2)
            ->get();

        if ($matches->count() !== 1) {
            if ($matches->count() > 1) {
                Log::warning('Parol tiklash: telefon raqami bir nechta talabada.', ['last9' => $last9]);
            }
            return null;
        }

        return $matches->first();
    }

    /**
     * 1-qadam: telefon raqami bo'yicha kod yuborish.
     */
    public function requestCode(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'phone' => 'required|string|max:30',
        ]);
        if ($validator->fails()) {
            return response()->json(['success' => false, 'message' => "Telefon raqamini kiriting."], 422);
        }

        $user = $this->findStudentByPhone($request->phone);
        if (!$user) {
            return response()->json(['success' => true, 'message' => self::GENERIC]);
        }

        // Juda tez qayta so'rashni cheklash
        $oxirgi = DB::table('password_reset_codes')
            ->where('user_id', $user->id)
            ->orderByDesc('created_at')
            ->value('created_at');
        if ($oxirgi && now()->diffInSeconds($oxirgi) < self::RESEND_COOLDOWN_SEC) {
            return response()->json(['success' => true, 'message' => self::GENERIC]);
        }

        // Oldingi faol kodlarni bekor qilamiz
        DB::table('password_reset_codes')
            ->where('user_id', $user->id)
            ->whereNull('used_at')
            ->update(['used_at' => now(), 'updated_at' => now()]);

        $kod = (string) random_int(100000, 999999);
        $now = now();

        DB::table('password_reset_codes')->insert([
            'id'         => (string) Str::uuid(),
            'user_id'    => $user->id,
            'code_hash'  => Hash::make($kod),
            'attempts'   => 0,
            'expires_at' => $now->copy()->addMinutes(self::CODE_TTL_MIN),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        try {
            // Kod FAQAT bazadagi raqamga yuboriladi
            SmsGateway::send(
                $user->phone,
                "KU Hostel: parolni tiklash kodi: {$kod}. Kod " . self::CODE_TTL_MIN . " daqiqa amal qiladi. Kodni hech kimga bermang."
            );
        } catch (\Throwable $e) {
            Log::error('Parol tiklash SMS yuborilmadi: ' . $e->getMessage(), ['user_id' => $user->id]);
        }

        return response()->json(['success' => true, 'message' => self::GENERIC]);
    }

    /**
     * 2-qadam: kodni tekshirish. To'g'ri bo'lsa, qisqa muddatli reset_token qaytaradi.
     */
    public function verifyCode(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'phone' => 'required|string|max:30',
            'code'  => 'required|digits:6',
        ]);
        if ($validator->fails()) {
            return response()->json(['success' => false, 'message' => "Kod 6 ta raqamdan iborat bo'lishi kerak."], 422);
        }

        $xato = "Kod noto'g'ri yoki muddati tugagan.";

        $user = $this->findStudentByPhone($request->phone);
        if (!$user) {
            return response()->json(['success' => false, 'message' => $xato], 422);
        }

        $kod = DB::table('password_reset_codes')
            ->where('user_id', $user->id)
            ->whereNull('used_at')
            ->whereNull('verified_at')
            ->where('expires_at', '>', now())
            ->orderByDesc('created_at')
            ->first();

        if (!$kod || $kod->attempts >= self::MAX_ATTEMPTS) {
            return response()->json(['success' => false, 'message' => $xato], 422);
        }

        DB::table('password_reset_codes')->where('id', $kod->id)
            ->update(['attempts' => $kod->attempts + 1, 'updated_at' => now()]);

        if (!Hash::check($request->code, $kod->code_hash)) {
            $qoldi = self::MAX_ATTEMPTS - ($kod->attempts + 1);
            if ($qoldi <= 0) {
                DB::table('password_reset_codes')->where('id', $kod->id)
                    ->update(['used_at' => now(), 'updated_at' => now()]);
                return response()->json(['success' => false, 'message' => "Urinishlar tugadi. Yangi kod so'rang."], 422);
            }
            return response()->json([
                'success' => false,
                'message' => "Kod noto'g'ri. Qolgan urinishlar: {$qoldi}.",
            ], 422);
        }

        $token = Str::random(64);
        DB::table('password_reset_codes')->where('id', $kod->id)->update([
            'reset_token_hash' => hash('sha256', $token),
            'verified_at'      => now(),
            'expires_at'       => now()->addMinutes(self::RESET_TTL_MIN),
            'updated_at'       => now(),
        ]);

        return response()->json(['success' => true, 'reset_token' => $token]);
    }

    /**
     * 3-qadam: yangi parolni o'rnatish.
     */
    public function confirmReset(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'reset_token' => 'required|string|size:64',
            'password' => [
                'required', 'string', 'min:12', 'confirmed',
                'regex:/[a-z]/', 'regex:/[A-Z]/', 'regex:/[0-9]/', 'regex:/[^a-zA-Z0-9]/',
            ],
            'password_confirmation' => 'required|string',
        ], [
            'password.min' => "Parol kamida 12 ta belgidan iborat bo'lishi kerak.",
            'password.regex' => "Parolda katta harf, kichik harf, raqam va belgi bo'lishi shart.",
            'password.confirmed' => "Parollar bir xil emas.",
        ]);
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'errors' => $validator->errors(),
            ], 422);
        }

        $yaroqsiz = response()->json([
            'success' => false,
            'message' => "Tiklash sessiyasi tugagan. Qaytadan urinib ko'ring.",
        ], 422);

        $kod = DB::table('password_reset_codes')
            ->where('reset_token_hash', hash('sha256', $request->reset_token))
            ->whereNotNull('verified_at')
            ->whereNull('used_at')
            ->where('expires_at', '>', now())
            ->first();

        if (!$kod) {
            return $yaroqsiz;
        }

        $user = User::find($kod->user_id);
        if (!$user || !$user->is_active || $user->role !== 'talaba') {
            return $yaroqsiz;
        }

        if (Hash::check($request->password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => "Yangi parol eskisidan farq qilishi kerak.",
            ], 422);
        }

        $user->password = Hash::make($request->password);
        $user->must_change_password = false;
        $user->save();

        DB::table('password_reset_codes')->where('id', $kod->id)
            ->update(['used_at' => now(), 'updated_at' => now()]);

        // Eski seanslarni (tokenlarni) bekor qilamiz
        DB::table('personal_access_tokens')
            ->where('tokenable_id', $user->id)
            ->delete();

        PasswordChangeNotifier::notify($user, 'reset_code');

        return response()->json([
            'success' => true,
            'message' => "Parol muvaffaqiyatli yangilandi. Yangi parol bilan kirishingiz mumkin.",
        ]);
    }
}
