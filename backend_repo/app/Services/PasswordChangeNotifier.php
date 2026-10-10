<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class PasswordChangeNotifier
{
    /**
     * Parol o'zgarganda superAdminlarga bildirishnoma yuboradi.
     * Parol matni hech qachon yuborilmaydi. Xato bo'lsa ham parol o'zgarishi to'xtamaydi.
     *
     * $method: 'self' | 'admin' | 'reset_code'
     */
    public static function notify(User $target, string $method, ?User $actor = null): void
    {
        try {
            $who = match ($method) {
                'self'       => "talaba o'zi",
                'admin'      => 'admin: ' . ($actor?->full_name ?? '—'),
                'reset_code' => 'SMS kod orqali tiklash',
                default      => $method,
            };

            // Xabar ichidagi vaqt Toshkent vaqtida chiqadi (UTC+5)
            $message = "{$target->full_name} (ID: {$target->id}) parolini o'zgartirdi.\n"
                     . "Kim: {$who}\n"
                     . 'Vaqt: ' . now()->setTimezone('Asia/Tashkent')->format('d.m.Y H:i');

            $superAdminIds = User::where('role', 'superAdmin')
                ->where('is_active', true)
                ->pluck('id');

            $now = now();
            $rows = $superAdminIds->map(fn ($id) => [
                'id'         => (string) Str::uuid(),
                'user_id'    => $id,
                'title'      => "Parol o'zgartirildi",
                'message'    => $message,
                'type'       => 'password_changed',
                'is_read'    => false,
                'created_at' => $now,
                'updated_at' => $now,
            ])->all();

            if (!empty($rows)) {
                DB::table('notifications')->insert($rows);
            }
        } catch (\Throwable $e) {
            Log::error('Parol bildirishnomasi yuborilmadi: ' . $e->getMessage(), [
                'target_id' => $target->id,
            ]);
        }
    }
}
