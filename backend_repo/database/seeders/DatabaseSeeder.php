<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Hostel;
use App\Models\Room;
use App\Models\RoomStudent;
use App\Models\Announcement;
use App\Models\Notification;
use App\Models\Payment;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * MUHIM: Bu seeder IDEMPOTENT qilib yozilgan — ya'ni uni bir necha marta
 * ishga tushirsangiz ham (masalan har bir deploy'da) ma'lumotlar
 * DUBLIKAT bo'lib qo'shilmaydi. Har bir yozuv "agar mavjud bo'lsa —
 * ustidan yozilmaydi / yangilanadi, agar mavjud bo'lmasa — yaratiladi"
 * mantig'i (updateOrCreate / firstOrCreate) bilan ishlaydi.
 */
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Hostels
        $boysHostel = Hostel::updateOrCreate(
            ['code' => 'boys'],
            [
                'name' => '1-bino (O\'g\'il bolalar yotoqxonasi)',
                'address' => 'Qo\'qon shahar, Universitet ko\'chasi 1-bino',
                'total_rooms' => 20,
                'total_capacity' => 80,
                'is_active' => true,
            ]
        );

        $girlsHostel = Hostel::updateOrCreate(
            ['code' => 'girls'],
            [
                'name' => '2-bino (Qiz bolalar yotoqxonasi)',
                'address' => 'Qo\'qon shahar, Universitet ko\'chasi 2-bino',
                'total_rooms' => 20,
                'total_capacity' => 80,
                'is_active' => true,
            ]
        );

        // 2. Users
        $defaultPassword = Hash::make('password123');

        $superAdmin = User::updateOrCreate(
            ['email' => 'superadmin@kuhostel.uz'],
            [
                'full_name' => 'Super Administrator',
                'phone' => '+998901234567',
                'password' => $defaultPassword,
                'role' => 'superAdmin',
                'hostel' => null,
                'is_active' => true,
            ]
        );

        $admin = User::updateOrCreate(
            ['email' => 'admin@kuhostel.uz'],
            [
                'full_name' => 'Administrator',
                'phone' => '+998901112233',
                'password' => $defaultPassword,
                'role' => 'admin',
                'hostel' => 'boys',
                'is_active' => true,
            ]
        );

        $mudir = User::updateOrCreate(
            ['email' => 'mudir@kuhostel.uz'],
            [
                'full_name' => 'Mudir (O\'g\'il bolalar)',
                'phone' => '+998902223344',
                'password' => $defaultPassword,
                'role' => 'mudir',
                'hostel' => 'boys',
                'is_active' => true,
            ]
        );

        $mudira = User::updateOrCreate(
            ['email' => 'mudira@kuhostel.uz'],
            [
                'full_name' => 'Mudir (Qiz bolalar)',
                'phone' => '+998903334455',
                'password' => $defaultPassword,
                'role' => 'mudir',
                'hostel' => 'girls',
                'is_active' => true,
            ]
        );

        $moliyachi = User::updateOrCreate(
            ['email' => 'moliya@kuhostel.uz'],
            [
                'full_name' => 'Bosh Moliyachi',
                'phone' => '+998904445566',
                'password' => $defaultPassword,
                'role' => 'moliyachi',
                'hostel' => null,
                'is_active' => true,
            ]
        );

        $talabaAli = User::updateOrCreate(
            ['email' => 'talaba@kuhostel.uz'],
            [
                'full_name' => 'Ali Valiyev',
                'phone' => '+998905556677',
                'password' => $defaultPassword,
                'role' => 'talaba',
                'hostel' => 'boys',
                'faculty' => "Ta'lim fakulteti",
                'course' => 2,
                'group_name' => 'TAL-202',
                'passport_id' => 'AA1234567',
                'jshshir' => '12345678901234',
                'region' => 'Farg\'ona viloyati',
                'district' => 'Qo\'qon shahri',
                'registered_by' => 'self',
                'is_active' => true,
            ]
        );

        $talabaNodira = User::updateOrCreate(
            ['email' => 'nodira@kuhostel.uz'],
            [
                'full_name' => 'Nodira Karimova',
                'phone' => '+998906667788',
                'password' => $defaultPassword,
                'role' => 'talaba',
                'hostel' => 'girls',
                'faculty' => 'Turizm va Iqtisodiyot fakulteti',
                'course' => 1,
                'group_name' => 'TUR-101',
                'passport_id' => 'AB7654321',
                'jshshir' => '43210987654321',
                'region' => 'Andijon viloyati',
                'district' => 'Andijon shahri',
                'registered_by' => 'self',
                'is_active' => true,
            ]
        );

        // 3. Rooms
        $boysRooms = [];
        foreach ([101, 102, 103, 104, 201, 202, 203, 204] as $num) {
            $floor = (int) substr((string) $num, 0, 1);
            $boysRooms[$num] = Room::updateOrCreate(
                ['hostel_id' => $boysHostel->id, 'room_number' => (string) $num],
                [
                    'hostel_type' => 'boys',
                    'floor' => $floor,
                    'capacity' => 4,
                    'price_per_month' => 450000,
                    'facilities' => ['WiFi', 'Konditsioner', 'Dush', 'Shkaf', 'Stol-stul'],
                    'amenities' => ['Muzlatgich', 'Balkon'],
                ]
            );
        }

        $girlsRooms = [];
        foreach ([101, 102, 103, 104, 201, 202, 203, 204] as $num) {
            $floor = (int) substr((string) $num, 0, 1);
            $girlsRooms[$num] = Room::updateOrCreate(
                ['hostel_id' => $girlsHostel->id, 'room_number' => (string) $num],
                [
                    'hostel_type' => 'girls',
                    'floor' => $floor,
                    'capacity' => 4,
                    'price_per_month' => 450000,
                    'facilities' => ['WiFi', 'Konditsioner', 'Dush', 'Shkaf', 'Stol-stul'],
                    'amenities' => ['Muzlatgich', 'Balkon', 'Dazmol'],
                ]
            );
        }

        // 4. Assignments (faqat mavjud bo'lmasa yaratiladi)
        RoomStudent::firstOrCreate(
            ['room_id' => $boysRooms[101]->id, 'student_id' => $talabaAli->id],
            ['assigned_at' => now(), 'status' => 'active']
        );
        $boysRooms[101]->updateOccupancy();

        RoomStudent::firstOrCreate(
            ['room_id' => $girlsRooms[101]->id, 'student_id' => $talabaNodira->id],
            ['assigned_at' => now(), 'status' => 'active']
        );
        $girlsRooms[101]->updateOccupancy();

        // 5. Sample Payments (faqat mavjud bo'lmasa yaratiladi)
        Payment::firstOrCreate(
            [
                'student_id' => $talabaAli->id,
                'room_id' => $boysRooms[101]->id,
                'period' => 'Sentabr 2026',
            ],
            [
                'hostel_id' => $boysHostel->id,
                'amount' => 450000,
                'method' => 'payme',
                'status' => 'approved',
                'reviewed_by' => $moliyachi->id,
                'paid_at' => now(),
            ]
        );

        Payment::firstOrCreate(
            [
                'student_id' => $talabaNodira->id,
                'room_id' => $girlsRooms[101]->id,
                'period' => 'Sentabr 2026',
            ],
            [
                'hostel_id' => $girlsHostel->id,
                'amount' => 450000,
                'method' => 'click',
                'status' => 'approved',
                'reviewed_by' => $moliyachi->id,
                'paid_at' => now(),
            ]
        );

        // 6. Sample Announcement & Notification (faqat mavjud bo'lmasa yaratiladi)
        Announcement::firstOrCreate(
            ['title' => 'Yangi o\'quv yili uchun yotoqxona qoidalari'],
            [
                'message' => 'Hurmatli talabalar! Yotoqxona ichki tartib qoidalariga qat\'iy rioya qilishingizni so\'raymiz.',
                'target_hostel' => 'all',
                'target_role' => 'all',
                'created_by' => $superAdmin->id,
            ]
        );

        Notification::firstOrCreate(
            ['user_id' => $talabaAli->id, 'title' => 'Xonaga joylashdingiz'],
            [
                'message' => 'Siz 1-bino 101-xonaga muvaffaqiyatli biriktirildingiz.',
                'type' => 'room',
                'is_read' => false,
            ]
        );

        Notification::firstOrCreate(
            ['user_id' => $talabaNodira->id, 'title' => 'Xonaga joylashdingiz'],
            [
                'message' => 'Siz 2-bino 101-xonaga muvaffaqiyatli biriktirildingiz.',
                'type' => 'room',
                'is_read' => false,
            ]
        );
    }
}
