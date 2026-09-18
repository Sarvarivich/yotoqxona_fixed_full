<?php

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------
| Flutter Web ilovasi
|--------------------------------------------------------------
|
| Ilova fayllari public/ papkasida yotadi va Laravel ularni
| beradi. Shu tufayli backend va ilova bitta domenda ishlaydi -
| CORS sozlash kerak emas.
|
| API marshrutlari routes/api.php da va ular /api prefiksi bilan
| keladi, shuning uchun bu yerdagi qoida ularga tegmaydi.
|
| Ilova ichidagi yonaltirish (SPA) server tomonda mavjud emas,
| shuning uchun har qanday notanish yol index.html ga
| yonaltiriladi - qolganini Flutter router hal qiladi.
|
*/

Route::get('/{any}', function () {
    $yol = public_path('index.html');

    if (!file_exists($yol)) {
        return response()->json([
            'success' => false,
            'message' => 'Ilova hali qurilmagan.',
        ], 404);
    }

    return response()->file($yol);
})->where('any', '^(?!api|storage).*$');

