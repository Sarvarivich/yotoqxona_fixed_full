<?php

use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\StudentController;
use App\Http\Controllers\Api\HostelController;
use App\Http\Controllers\Api\RoomController;
use App\Http\Controllers\Api\RoomAssignmentController;
use App\Http\Controllers\Api\ApplicationController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\ComplaintController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\FinanceController;
use App\Http\Controllers\Api\SurveyController;
use App\Http\Controllers\Api\ContractController;
use App\Http\Controllers\Api\DocumentController;
use App\Http\Controllers\Api\ReportController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Laravel avtomatik ravishda /api prefiksini qo'shadi.
|
| ROL GURUHLARI (izchillik uchun shu qisqartmalarga amal qiling):
|
|   ADMINS   = admin, superAdmin
|   MANAGERS = mudir, admin, superAdmin          (talaba/xona boshqaruvi)
|   FINANCE  = moliyachi, admin, superAdmin      (pul bilan bog'liq amallar)
|   STAFF    = mudir, moliyachi, admin, superAdmin  (barcha xodimlar)
|
| Talabalar (role = talaba) faqat o'z ma'lumotlari bilan ishlaydi вЂ”
| bu cheklov controller yoki Policy ichida amalga oshiriladi.
|
*/

// Rol ro'yxatlarini bir joyda saqlaymiz вЂ” keyinchalik o'zgartirish oson.
$ADMINS   = 'role:admin,superAdmin';
$MANAGERS = 'role:mudir,admin,superAdmin';
$FINANCE  = 'role:moliyachi,admin,superAdmin';
$STAFF    = 'role:mudir,moliyachi,admin,superAdmin';


/*
|--------------------------------------------------------------------------
| OCHIQ (PUBLIC) MARSHRUTLAR
|--------------------------------------------------------------------------
|
| Faqat login, ro'yxatdan o'tish va binolar ro'yxati. Boshqa hech narsa
| autentifikatsiyasiz ochiq bo'lmasligi kerak.
|
*/

Route::middleware('throttle:10,1')->group(function () {

    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/register', [AuthController::class, 'register']);

    // Eski mijozlar uchun /api/auth/... variantlari ham qoldirilgan.
    // Flutter to'liq ko'chirilgach, bu ikkitasini o'chirib tashlang.
    Route::post('/auth/login', [AuthController::class, 'login']);
    Route::post('/auth/register', [AuthController::class, 'register']);

});

// Ro'yxatdan o'tishdan oldin bino tanlash uchun kerak вЂ” ochiq qoladi.
Route::get('/hostels', [HostelController::class, 'index']);
Route::get('/hostels/{id}', [HostelController::class, 'show']);


/*
|--------------------------------------------------------------------------
| HIMOYALANGAN MARSHRUTLAR
|--------------------------------------------------------------------------
|
| Sanctum tokeni talab qilinadi.
|
*/

Route::middleware('auth:sanctum')->group(function () use ($ADMINS, $MANAGERS, $FINANCE, $STAFF) {


    /*
    |----------------------------------------------------------------------
    | PROFIL вЂ” har qanday tizimga kirgan foydalanuvchi
    |----------------------------------------------------------------------
    */

    Route::get('/me', [AuthController::class, 'me']);
    // Talaba o'z profilini tahrirlaydi. PUT /api/students/{id}
    // dan farqi: faqat o'z yozuvi va faqat xavfsiz maydonlar.
    Route::put('/me', [AuthController::class, 'updateProfile']);
    Route::patch('/me', [AuthController::class, 'updateProfile']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/change-password', [AuthController::class, 'changePassword']);

    Route::prefix('auth')->group(function () {
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::post('/change-password', [AuthController::class, 'changePassword']);
    });


    /*
    |----------------------------------------------------------------------
    | FOYDALANUVCHILARNI BOSHQARISH вЂ” faqat ADMINS
    |----------------------------------------------------------------------
    |
    | Ilgari bu ikki endpoint har qanday talabaga ochiq edi.
    |
    */

    Route::post('/admin-reset-password', [AuthController::class, 'adminResetPassword'])
        ->middleware($ADMINS);

    Route::post('/delete-user', [AuthController::class, 'deleteUser'])
        ->middleware($ADMINS);


    /*
    |----------------------------------------------------------------------
    | DASHBOARD вЂ” faqat xodimlar
    |----------------------------------------------------------------------
    |
    | Umumiy statistika (jami talabalar, bandlik, moliya) talabaga
    | ko'rsatilmaydi. Talaba uchun /me va /my-room yetarli.
    |
    */

    Route::get('/dashboard', [DashboardController::class, 'index'])
        ->middleware($STAFF);


    /*
    |----------------------------------------------------------------------
    | TALABALAR
    |----------------------------------------------------------------------
    |
    | O'qish вЂ” barcha xodimlar (moliyachiga to'lovlar uchun kerak).
    | Yozish/o'chirish вЂ” faqat MANAGERS.
    | Parolni majburan almashtirish вЂ” faqat ADMINS.
    |
    | Har bir metod ichida qo'shimcha ravishda UserPolicy tekshiriladi:
    | mudir faqat o'z binosidagi talabaga tegishi mumkin.
    |
    */

    Route::get('/students', [StudentController::class, 'index'])
        ->middleware($STAFF);

    Route::get('/students/{id}', [StudentController::class, 'show'])
        ->middleware($STAFF);

    Route::post('/students', [StudentController::class, 'store'])
        ->middleware($MANAGERS);

    Route::put('/students/{id}', [StudentController::class, 'update'])
        ->middleware($MANAGERS);

    Route::patch('/students/{id}', [StudentController::class, 'update'])
        ->middleware($MANAGERS);

    Route::delete('/students/{id}', [StudentController::class, 'destroy'])
        ->middleware($ADMINS);

    Route::put('/students/{id}/password', [StudentController::class, 'updatePassword'])
        ->middleware($ADMINS);


    /*
    |----------------------------------------------------------------------
    | HUJJATLAR
    |----------------------------------------------------------------------
    |
    | Talaba o'z hujjatini yuklaydi va ko'radi вЂ” cheklov
    | DocumentController ichida ($user->id !== $studentId).
    |
    */

    Route::get('/students/{studentId}/documents', [DocumentController::class, 'show']);
    Route::post('/students/{studentId}/documents', [DocumentController::class, 'upload']);


    /*
    |----------------------------------------------------------------------
    | XONALAR
    |----------------------------------------------------------------------
    |
    | Ro'yxatni ko'rish вЂ” hamma (talaba bo'sh joylarni ko'rishi mumkin).
    | Yaratish/tahrirlash/o'chirish вЂ” MANAGERS.
    |
    */

    Route::get('/rooms', [RoomController::class, 'index']);
    Route::get('/rooms/{id}', [RoomController::class, 'show']);

    Route::post('/rooms', [RoomController::class, 'store'])
        ->middleware($MANAGERS);

    Route::put('/rooms/{id}', [RoomController::class, 'update'])
        ->middleware($MANAGERS);

    Route::patch('/rooms/{id}', [RoomController::class, 'update'])
        ->middleware($MANAGERS);

    Route::delete('/rooms/{id}', [RoomController::class, 'destroy'])
        ->middleware($MANAGERS);


    /*
    |----------------------------------------------------------------------
    | XONAGA BIRIKTIRISH
    |----------------------------------------------------------------------
    */

    // Talaba o'z xonasini ko'radi.
    Route::get('/my-room', [RoomAssignmentController::class, 'myRoom']);

    Route::get('/room-assignments', [RoomAssignmentController::class, 'index'])
        ->middleware($STAFF);

    Route::post('/room-assignments', [RoomAssignmentController::class, 'store'])
        ->middleware($MANAGERS);

    Route::delete('/room-assignments/{id}', [RoomAssignmentController::class, 'destroy'])
        ->middleware($MANAGERS);


    /*
    |----------------------------------------------------------------------
    | ARIZALAR
    |----------------------------------------------------------------------
    |
    | Talaba ariza yaratadi va o'zinikini ko'radi (filtr controller ichida).
    | Ko'rib chiqish (update) va o'chirish вЂ” MANAGERS.
    |
    */

    Route::get('/applications', [ApplicationController::class, 'index']);
    Route::get('/applications/{id}', [ApplicationController::class, 'show']);
    Route::post('/applications', [ApplicationController::class, 'store']);

    Route::put('/applications/{id}', [ApplicationController::class, 'update'])
        ->middleware($MANAGERS);

    Route::patch('/applications/{id}', [ApplicationController::class, 'update'])
        ->middleware($MANAGERS);

    Route::delete('/applications/{id}', [ApplicationController::class, 'destroy'])
        ->middleware($MANAGERS);


    /*
    |----------------------------------------------------------------------
    | TO'LOVLAR
    |----------------------------------------------------------------------
    |
    | MUHIM: to'lovni tasdiqlash (update) faqat FINANCE uchun.
    | Ilgari talabaning o'zi ham to'lovini "approved" qila olardi va
    | shu orqali shartnoma yuklab olardi.
    |
    */

    Route::get('/payments/summary', [PaymentController::class, 'summary'])
        ->middleware($STAFF);

    // Talaba o'z to'lovlarini ko'radi va chek yuboradi.
    Route::get('/payments', [PaymentController::class, 'index']);
    Route::get('/payments/{id}', [PaymentController::class, 'show']);
    Route::post('/payments', [PaymentController::class, 'store']);

    Route::put('/payments/{id}', [PaymentController::class, 'update'])
        ->middleware($FINANCE);

    Route::patch('/payments/{id}', [PaymentController::class, 'update'])
        ->middleware($FINANCE);

    Route::delete('/payments/{id}', [PaymentController::class, 'destroy'])
        ->middleware($ADMINS);


    /*
    |----------------------------------------------------------------------
    | SHARTNOMA
    |----------------------------------------------------------------------
    */

    Route::get('/contract/status', [ContractController::class, 'status']);
    Route::get('/contract/download', [ContractController::class, 'download']);


    /*
    |----------------------------------------------------------------------
    | MUROJAATLAR
    |----------------------------------------------------------------------
    |
    | Talaba murojaat yozadi va o'zinikini ko'radi.
    | Javob berish (update) вЂ” xodimlar.
    |
    */

    Route::get('/complaints', [ComplaintController::class, 'index']);
    Route::get('/complaints/{id}', [ComplaintController::class, 'show']);
    Route::post('/complaints', [ComplaintController::class, 'store']);

    Route::put('/complaints/{id}', [ComplaintController::class, 'update'])
        ->middleware($STAFF);

    Route::patch('/complaints/{id}', [ComplaintController::class, 'update'])
        ->middleware($STAFF);

    Route::delete('/complaints/{id}', [ComplaintController::class, 'destroy'])
        ->middleware($MANAGERS);


    /*
    |----------------------------------------------------------------------
    | BILDIRISHNOMALAR
    |----------------------------------------------------------------------
    */

    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::patch('/notifications/{id}/read', [NotificationController::class, 'markAsRead']);

    // Boshqa foydalanuvchiga bildirishnoma yuborish вЂ” faqat xodimlar.
    Route::post('/notifications', [NotificationController::class, 'store'])
        ->middleware($STAFF);

    Route::delete('/notifications/{id}', [NotificationController::class, 'destroy']);


    /*
    |----------------------------------------------------------------------
    | E'LONLAR
    |----------------------------------------------------------------------
    */

    Route::get('/announcements', [NotificationController::class, 'announcements']);

    Route::post('/announcements', [NotificationController::class, 'storeAnnouncement'])
        ->middleware($STAFF);


    /*
    |----------------------------------------------------------------------
    | MOLIYA вЂ” XARAJATLAR VA BYUDJET
    |----------------------------------------------------------------------
    |
    | To'liq yopiq: talaba universitetning xarajatlarini ko'rmasligi kerak.
    |
    */

    Route::middleware($FINANCE)->group(function () {

        Route::get('/expenses', [FinanceController::class, 'expenses']);
        Route::post('/expenses', [FinanceController::class, 'storeExpense']);
        Route::delete('/expenses/{id}', [FinanceController::class, 'destroyExpense']);

        Route::get('/budgets', [FinanceController::class, 'budgets']);
        Route::post('/budgets', [FinanceController::class, 'setBudget']);

    });


    /*
    |----------------------------------------------------------------------
    | HISOBOTLAR
    |----------------------------------------------------------------------
    */

    Route::get('/reports/summary', [ReportController::class, 'summary'])
        ->middleware($STAFF);


    /*
    |----------------------------------------------------------------------
    | SO'ROVNOMALAR
    |----------------------------------------------------------------------
    */

    Route::get('/surveys', [SurveyController::class, 'index']);
    Route::get('/surveys/{id}', [SurveyController::class, 'show']);
    Route::post('/surveys/{id}/answers', [SurveyController::class, 'submitAnswers']);

});
