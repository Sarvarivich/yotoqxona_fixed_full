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

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Barcha API endpointlar.
| Laravel avtomatik ravishda /api prefiksini qo'shadi.
|
| Masalan:
| POST /api/auth/login
|
*/


/*
|--------------------------------------------------------------------------
| PUBLIC AUTH ROUTES
|--------------------------------------------------------------------------
*/

Route::prefix('auth')->group(function () {

    Route::post('/login', [
        AuthController::class,
        'login'
    ])->middleware('throttle:10,1');

    Route::post('/register', [
        AuthController::class,
        'register'
    ])->middleware('throttle:10,1');

});


/*
|--------------------------------------------------------------------------
| DIRECT AUTH ROUTES
|--------------------------------------------------------------------------
|
| /api/login va /api/register ham ishlashi uchun.
|
*/

Route::post('/login', [
    AuthController::class,
    'login'
])->middleware('throttle:10,1');

Route::post('/register', [
    AuthController::class,
    'register'
])->middleware('throttle:10,1');


/*
|--------------------------------------------------------------------------
| PUBLIC HOSTELS ROUTES
|--------------------------------------------------------------------------
*/

Route::get('/hostels', [
    HostelController::class,
    'index'
]);

Route::get('/hostels/{id}', [
    HostelController::class,
    'show'
]);


/*
|--------------------------------------------------------------------------
| PROTECTED ROUTES
|--------------------------------------------------------------------------
|
| Quyidagi barcha endpointlar Sanctum token talab qiladi.
|
*/

Route::middleware('auth:sanctum')->group(function () {


    /*
    |--------------------------------------------------------------------------
    | AUTH / PROFILE
    |--------------------------------------------------------------------------
    */

    Route::prefix('auth')->group(function () {

        Route::get('/me', [
            AuthController::class,
            'me'
        ]);

        Route::post('/logout', [
            AuthController::class,
            'logout'
        ]);

        Route::post('/change-password', [
            AuthController::class,
            'changePassword'
        ]);

    });


    // Qisqa variantdagi endpointlar

    Route::get('/me', [
        AuthController::class,
        'me'
    ]);

    Route::post('/logout', [
        AuthController::class,
        'logout'
    ]);


    /*
    |--------------------------------------------------------------------------
    | ADMIN USER MANAGEMENT
    |--------------------------------------------------------------------------
    */

    Route::post('/admin-reset-password', [
        AuthController::class,
        'adminResetPassword'
    ]);

    Route::post('/delete-user', [
        AuthController::class,
        'deleteUser'
    ]);


    /*
    |--------------------------------------------------------------------------
    | DASHBOARD
    |--------------------------------------------------------------------------
    */

    Route::get('/dashboard', [
        DashboardController::class,
        'index'
    ]);


    /*
    |--------------------------------------------------------------------------
    | STUDENTS
    |--------------------------------------------------------------------------
    */

    Route::put('/students/{id}/password', [
        StudentController::class,
        'updatePassword'
    ]);

    Route::apiResource(
        'students',
        StudentController::class
    );


    /*
    |--------------------------------------------------------------------------
    | ROOMS
    |--------------------------------------------------------------------------
    */

    Route::apiResource(
        'rooms',
        RoomController::class
    );


    /*
    |--------------------------------------------------------------------------
    | ROOM ASSIGNMENTS
    |--------------------------------------------------------------------------
    */

    Route::get('/my-room', [
        RoomAssignmentController::class,
        'myRoom'
    ]);

    Route::get('/room-assignments', [
        RoomAssignmentController::class,
        'index'
    ]);

    Route::post('/room-assignments', [
        RoomAssignmentController::class,
        'store'
    ]);

    Route::delete('/room-assignments/{id}', [
        RoomAssignmentController::class,
        'destroy'
    ]);


    /*
    |--------------------------------------------------------------------------
    | APPLICATIONS / ARIZALAR
    |--------------------------------------------------------------------------
    */

    Route::apiResource(
        'applications',
        ApplicationController::class
    );


    /*
    |--------------------------------------------------------------------------
    | PAYMENTS
    |--------------------------------------------------------------------------
    */

    Route::get('/payments/summary', [
        PaymentController::class,
        'summary'
    ]);

    Route::apiResource(
        'payments',
        PaymentController::class
    );


    /*
    |--------------------------------------------------------------------------
    | CONTRACT
    |--------------------------------------------------------------------------
    */

    Route::get('/contract/status', [
        ContractController::class,
        'status'
    ]);

    Route::get('/contract/download', [
        ContractController::class,
        'download'
    ]);


    /*
    |--------------------------------------------------------------------------
    | COMPLAINTS / MUROJAATLAR
    |--------------------------------------------------------------------------
    */

    Route::apiResource(
        'complaints',
        ComplaintController::class
    );


    /*
    |--------------------------------------------------------------------------
    | NOTIFICATIONS
    |--------------------------------------------------------------------------
    */

    Route::get('/notifications', [
        NotificationController::class,
        'index'
    ]);

    Route::post('/notifications', [
        NotificationController::class,
        'store'
    ]);

    Route::patch('/notifications/{id}/read', [
        NotificationController::class,
        'markAsRead'
    ]);


    /*
    |--------------------------------------------------------------------------
    | ANNOUNCEMENTS
    |--------------------------------------------------------------------------
    */

    Route::get('/announcements', [
        NotificationController::class,
        'announcements'
    ]);

    Route::post('/announcements', [
        NotificationController::class,
        'storeAnnouncement'
    ]);


    /*
    |--------------------------------------------------------------------------
    | FINANCE / EXPENSES
    |--------------------------------------------------------------------------
    */

    Route::get('/expenses', [
        FinanceController::class,
        'expenses'
    ]);

    Route::post('/expenses', [
        FinanceController::class,
        'storeExpense'
    ]);

    Route::delete('/expenses/{id}', [
        FinanceController::class,
        'destroyExpense'
    ]);


    /*
    |--------------------------------------------------------------------------
    | BUDGETS
    |--------------------------------------------------------------------------
    */

    Route::get('/budgets', [
        FinanceController::class,
        'budgets'
    ]);

    Route::post('/budgets', [
        FinanceController::class,
        'setBudget'
    ]);


    /*
    |--------------------------------------------------------------------------
    | SURVEYS / SO'ROVNOMALAR
    |--------------------------------------------------------------------------
    */

    Route::get('/surveys', [
        SurveyController::class,
        'index'
    ]);

    Route::get('/surveys/{id}', [
        SurveyController::class,
        'show'
    ]);

    Route::post('/surveys/{id}/answers', [
        SurveyController::class,
        'submitAnswers'
    ]);

});