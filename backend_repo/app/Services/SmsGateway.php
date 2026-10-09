<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

/**
 * SMS yuborish. Kredensiallar Railway Variables'da saqlanadi:
 *   SMS_GATEWAY_URL, SMS_GATEWAY_TOKEN, SMS_SENDER
 *
 * DIQQAT: so'rov tanasi (payload) provayderning hujjatiga qarab
 * o'zgartirilishi kerak. Hozirgi shakl umumiy (phone, text, sender).
 */
class SmsGateway
{
    public static function send(string $phone, string $text): void
    {
        $url = env('SMS_GATEWAY_URL');
        $token = env('SMS_GATEWAY_TOKEN');

        if (!$url || !$token) {
            throw new \RuntimeException('SMS gateway sozlanmagan.');
        }

        $response = Http::withToken($token)
            ->timeout(15)
            ->acceptJson()
            ->post($url, [
                'phone'  => $phone,
                'text'   => $text,
                'sender' => env('SMS_SENDER', 'KU HOSTEL'),
            ]);

        if (!$response->successful()) {
            throw new \RuntimeException('SMS gateway xato: HTTP ' . $response->status());
        }
    }
}
