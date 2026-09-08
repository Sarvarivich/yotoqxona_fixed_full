<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Marshrut darajasidagi rol filtri.
 *
 * Ishlatilishi:
 *   Route::get('/expenses', [...])->middleware('role:moliyachi,admin,superAdmin');
 *
 * Bu middleware faqat "bu rol bu bo'limga umuman kira oladimi?" degan
 * savolga javob beradi. "Aynan shu yozuvga tegishi mumkinmi?" degan
 * nozikroq savol Policy'lar (app/Policies/) ichida hal qilinadi.
 */
class EnsureRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        // auth:sanctum middleware'i oldin ishlashi kerak, lekin
        // xavfsizlik uchun bu yerda ham tekshiramiz.
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Avtorizatsiyadan o\'tilmagan.',
            ], 401);
        }

        if (!$user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Hisobingiz bloklangan yoki nofaol.',
            ], 403);
        }

        if (!in_array($user->role, $roles, true)) {
            return response()->json([
                'success' => false,
                'message' => 'Bu amalni bajarish uchun sizda ruxsat yo\'q.',
            ], 403);
        }

        return $next($request);
    }
}
