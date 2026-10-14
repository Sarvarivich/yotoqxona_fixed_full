<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

/**
 * Brevo HTTP API orqali email yuborish (SMTP ishlatilmaydi, chunki Railway SMTP portlarini bloklaydi).
 *
 * Railway Variables (web servisi):
 *   BREVO_API_KEY       - Brevo API kaliti (chatga yozmang)
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
        $apiKey = env('BREVO_API_KEY');
        $senderEmail = env('BREVO_SENDER_EMAIL');
        if (!$apiKey || !$senderEmail) {
            throw new \RuntimeException('Brevo sozlanmagan: BREVO_API_KEY yoki BREVO_SENDER_EMAIL yo\'q.');
        }

        $response = Http::withHeaders([
                'api-key' => $apiKey,
                'accept' => 'application/json',
            ])
            ->timeout(15)
            ->post(self::URL, [
                'sender' => [
                    'name' => env('BREVO_SENDER_NAME', 'KU Hostel'),
                    'email' => $senderEmail,
                ],
                'to' => [['email' => $to]],
                'subject' => $subject,
                'textContent' => $text,
            ]);

        if (!$response->successful()) {
            throw new \RuntimeException('Brevo email yuborilmadi: HTTP ' . $response->status() . ' ' . $response->body());
        }
    }
}
