<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Filesystem Disk
    |--------------------------------------------------------------------------
    |
    | Here you may specify the default filesystem disk that should be used
    | by the framework. The "local" disk, as well as a variety of cloud
    | based disks are available to your application for file storage.
    |
    */

    'default' => env('FILESYSTEM_DISK', 'local'),

    /*
    |--------------------------------------------------------------------------
    | Filesystem Disks
    |--------------------------------------------------------------------------
    |
    | Below you may configure as many filesystem disks as necessary, and you
    | may even configure multiple disks for the same driver. Examples for
    | most supported storage drivers are configured here for reference.
    |
    | Supported drivers: "local", "ftp", "sftp", "s3"
    |
    */

    'disks' => [

        'local' => [
            'driver' => 'local',
            'root' => storage_path('app/private'),
            'serve' => true,
            'throw' => false,
            'report' => false,
        ],

        // Obyekt saqlagich (Supabase Storage yoki Cloudflare R2).
        //
        // AWS_BUCKET ornatilgan bolsa fayllar bulutga yoziladi.
        // Ornatilmagan bolsa - mahalliy diskka, ishlab chiqish
        // muhitida shunday qulay.
        //
        // Railway diski VAQTINCHALIK: har deploy'da tozalanadi.
        // Shuning uchun production'da AWS_BUCKET majburiy.
        'public' => env('AWS_BUCKET')
            ? [
                'driver' => 's3',
                'key' => env('AWS_ACCESS_KEY_ID'),
                'secret' => env('AWS_SECRET_ACCESS_KEY'),
                'region' => env('AWS_DEFAULT_REGION', 'auto'),
                'bucket' => env('AWS_BUCKET'),
                'endpoint' => env('AWS_ENDPOINT'),
                'url' => env('AWS_URL'),
                'use_path_style_endpoint' => env(
                    'AWS_USE_PATH_STYLE_ENDPOINT',
                    true
                ),
                // visibility ATAYLAB yoq: R2 obyekt ACL sini
                // qollab-quvvatlamaydi va x-amz-acl sarlavhasi
                // bilan kelgan sorovni rad etadi. Fayllar bucket
                // sozlamasi (Public Development URL) orqali
                // ommaviy boladi.
                // throw => true: saqlash xatosi endi yashirilmaydi.
                // Ilgari false edi va store() jimgina $false
                // qaytarardi - bazaga 0 bolib yozilardi.
                'throw' => true,
            ]
            : [
                'driver' => 'local',
                'root' => storage_path('app/public'),
                'url' => env('APP_URL') . '/storage',
                'visibility' => 'public',
                'throw' => false,
            ],


        's3' => [
            'driver' => 's3',
            'key' => env('AWS_ACCESS_KEY_ID'),
            'secret' => env('AWS_SECRET_ACCESS_KEY'),
            'region' => env('AWS_DEFAULT_REGION'),
            'bucket' => env('AWS_BUCKET'),
            'url' => env('AWS_URL'),
            'endpoint' => env('AWS_ENDPOINT'),
            'use_path_style_endpoint' => env('AWS_USE_PATH_STYLE_ENDPOINT', false),
            'throw' => false,
            'report' => false,
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Symbolic Links
    |--------------------------------------------------------------------------
    |
    | Here you may configure the symbolic links that will be created when the
    | `storage:link` Artisan command is executed. The array keys should be
    | the locations of the links and the values should be their targets.
    |
    */

    'links' => [
        public_path('storage') => storage_path('app/public'),
    ],

];
