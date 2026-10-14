<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Brevo HTTP API orqali email yuborish (SMTP ishlatilmaydi, chunki Railway SMTP portlarini bloklaydi).
 *
 * config/services.php → 'brevo' orqali o'qiladi (Railway config cache bilan muammosiz ishlaydi).
 *
 * Railway Variables (web servisi):
 *   BREVO_API_KEY       - Brevo API kaliti
 *   BREVO_SENDER_EMAIL  - Brevo'da tasdiqlangan yuboruvchi email
 *   BREVO_SENDER_NAME   - yuboruvchi nomi (standart: "KU Hostel")
 */
class BrevoMailer
{
    private const URL = 'https://api.brevo.com/v3/smtp/email';

    /**
     * Matnli email yuboradi. Xato bo'lsa RuntimeException tashlaydi.
     */
    public static function send(string $to, string $subject, string $text): void
    {
        // config() ishlatiladi - Railway config:cache bilan muammosiz ishlaydi
        $apiKey      = config('services.brevo.api_key');
        $senderEmail = config('services.brevo.sender_email');
        $senderName  = config('services.brevo.sender_name', 'KU Hostel');

        if (!$apiKey || !$senderEmail) {
            Log::error('Brevo sozlanmagan', [
                'has_api_key'      => !empty($apiKey),
                'has_sender_email' => !empty($senderEmail),
            ]);
            throw new \RuntimeException('Brevo sozlanmagan: BREVO_API_KEY yoki BREVO_SENDER_EMAIL yo\'q.');
        }

        Log::info('Brevo: email yuborilmoqda', ['to' => $to, 'subject' => $subject]);

        $response = Http::withHeaders([
                'api-key' => $apiKey,
                'accept'  => 'application/json',
            ])
            ->timeout(15)
            ->post(self::URL, [
                'sender' => [
                    'name'  => $senderName,
                    'email' => $senderEmail,
                ],
                'to'          => [['email' => $to]],
                'subject'     => $subject,
                'textContent' => $text,
            ]);

        if (!$response->successful()) {
            Log::error('Brevo: email yuborilmadi', [
                'to'     => $to,
                'status' => $response->status(),
                'body'   => $response->body(),
            ]);
            throw new \RuntimeException(
                'Brevo email yuborilmadi: HTTP ' . $response->status() . ' ' . $response->body()
            );
        }

        Log::info('Brevo: email muvaffaqiyatli yuborildi', ['to' => $to]);
    }
}
