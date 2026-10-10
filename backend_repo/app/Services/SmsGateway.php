<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * DevSMS orqali parol tiklash kodini yuborish (universal_otp, template_type=2).
 *
 * Railway Variables:
 *   DEVSMS_TOKEN         - DevSMS kabinetidagi API token (chatga yozmang)
 *   DEVSMS_SERVICE_NAME  - xizmat nomi, 2-50 belgi, faqat harf/raqam/bo'shliq/nuqta/chiziqcha
 *                          (standart: "KU Hostel")
 */
class SmsGateway
{
    private const URL = 'https://devsms.uz/api/send_sms.php';
    private const TEMPLATE_PASSWORD_RESET = 2;

    /**
     * Parol tiklash kodini yuboradi. Xato bo'lsa RuntimeException tashlaydi.
     */
    public static function sendOtp(string $phone, string $code): void
    {
        $token = env('DEVSMS_TOKEN');
        if (!$token) {
            throw new \RuntimeException('DevSMS sozlanmagan: DEVSMS_TOKEN yo\'q.');
        }

        $digits = preg_replace('/\D+/', '', $phone);
        if (strlen($digits) === 9) {
            $digits = '998' . $digits;
        }

        $response = Http::withToken($token)
            ->timeout(15)
            ->acceptJson()
            ->post(self::URL, [
                'phone' => $digits,
                'type' => 'universal_otp',
                'template_type' => self::TEMPLATE_PASSWORD_RESET,
                'service_name' => env('DEVSMS_SERVICE_NAME', 'KU Hostel'),
                'otp_code' => $code,
            ]);

        $javob = $response->json();
        if (!$response->successful() || empty($javob['success'])) {
            Log::error('DevSMS OTP yuborilmadi', [
                'http' => $response->status(),
                'javob' => $response->body(),
            ]);
            throw new \RuntimeException('DevSMS OTP yuborilmadi.');
        }
    }
}