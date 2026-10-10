<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\PasswordChangeNotifier;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class PasswordResetController extends Controller
{
    // Javob hech qachon hisob mavjudligini oshkor qilmaydi.
    private const GENERIC = "Agar email va telefon ma'lumotlari to'g'ri bo'lsa, tasdiqlash kodi yuborildi.";

    private const CODE_TTL_MIN = 5;
    private const RESET_TTL_MIN = 10;
    private const MAX_ATTEMPTS = 3;
    private const RESEND_COOLDOWN_SEC = 60;

    /**
     * Email VA telefon bir xil talabaga tegishli bo'lsagina foydalanuvchini qaytaradi.
     * Telefon solishtirilganda faqat oxirgi 9 ta raqam olinadi
     * (+998..., 998..., 90 123 45 67 va h.k. bir xil ishlaydi).
     */
    private function findStudent(string $email, string $phone): ?User
    {
        $digits = preg_replace('/\D+/', '', $phone);
        if (strlen($digits) < 9) {
            return null;
        }
        $last9 = substr($digits, -9);

        $matches = User::where('role', 'talaba')
            ->where('is_active', true)
            ->whereRaw('lower(email) = ?', [strtolower(trim($email))])
            ->whereRaw("right(regexp_replace(phone, '\\D', '', 'g'), 9) = ?", [$last9])
            ->limit(2)
            ->get();

        return $matches->count() === 1 ? $matches->first() : null;
    }

    /**
     * 1-qadam: email + telefon mos kelsa, talaba emailiga kod yuborish.
     */
    public function requestCode(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|string|max:255',
            'phone' => 'required|string|max:30',
        ]);
        if ($validator->fails()) {
            return response()->json(['success' => false, 'message' => "Email va telefon raqamini kiriting."], 422);
        }

        $user = $this->findStudent($request->email, $request->phone);
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
            // Kod FAQAT bazadagi talaba emailiga yuboriladi
            Mail::raw(
                "Parolni tiklash kodi: {$kod}\n\nKod 5 daqiqa amal qiladi. Agar bu so'rovni siz