<?php

namespace App\Policies;

use App\Models\User;

/**
 * Foydalanuvchi yozuvlari ustidan obyekt darajasidagi ruxsatlar.
 *
 * Middleware "mudir talabalar bo'limiga kira oladi" deydi.
 * Policy esa "mudir AYNAN SHU talabaga tegishi mumkinmi?" degan
 * savolga javob beradi — masalan o'g'il bolalar mudiri qizlar
 * yotoqxonasi talabasini tahrirlay olmasligi kerak.
 */
class UserPolicy
{
    /** Tizimni to'liq boshqaradigan rollar. */
    private const ADMINS = ['admin', 'superAdmin'];

    /** Talaba ma'lumotlarini ko'ra oladigan xodimlar. */
    private const STAFF = ['mudir', 'moliyachi', 'admin', 'superAdmin'];

    private function isAdmin(User $actor): bool
    {
        return in_array($actor->role, self::ADMINS, true);
    }

    /**
     * Mudir faqat o'z binosidagi talabalar bilan ishlaydi.
     * Admin va superAdmin uchun bino cheklovi yo'q.
     */
    private function sameHostel(User $actor, User $target): bool
    {
        if ($this->isAdmin($actor)) {
            return true;
        }

        // Mudirning binosi belgilanmagan bo'lsa — cheklovni qo'llamaymiz,
        // lekin bu holat ma'lumotlar to'g'ri kiritilmaganini bildiradi.
        if (empty($actor->hostel)) {
            return true;
        }

        return $actor->hostel === $target->hostel;
    }

    /**
     * Ro'yxatni umuman ko'rish huquqi.
     */
    public function viewAny(User $actor): bool
    {
        return in_array($actor->role, self::STAFF, true);
    }

    /**
     * Bitta foydalanuvchi kartasini ko'rish.
     * Talaba faqat o'zinikini ko'radi.
     */
    public function view(User $actor, User $target): bool
    {
        if ($actor->id === $target->id) {
            return true;
        }

        if (!in_array($actor->role, self::STAFF, true)) {
            return false;
        }

        // Moliyachi to'lovlar uchun barcha talabalarni ko'rishi kerak.
        if ($actor->role === 'moliyachi') {
            return true;
        }

        return $this->sameHostel($actor, $target);
    }

    /**
     * Yangi foydalanuvchi yaratish.
     * Xodim (admin/mudir/moliyachi) hisobini faqat superAdmin ocha oladi.
     */
    public function create(User $actor, string $newRole = 'talaba'): bool
    {
        if ($newRole !== 'talaba') {
            return $actor->role === 'superAdmin';
        }

        return in_array($actor->role, ['mudir', 'admin', 'superAdmin'], true);
    }

    /**
     * Tahrirlash.
     * Talaba o'z profilini tahrirlay oladi (qaysi maydonlarni —
     * buni FormRequest cheklaydi, bu yerda faqat "tegishi mumkinmi").
     */
    public function update(User $actor, User $target): bool
    {
        if ($actor->id === $target->id) {
            return true;
        }

        if (!in_array($actor->role, ['mudir', 'admin', 'superAdmin'], true)) {
            return false;
        }

        // Xodim hisobini faqat superAdmin tahrirlaydi.
        if ($target->role !== 'talaba') {
            return $actor->role === 'superAdmin';
        }

        return $this->sameHostel($actor, $target);
    }

    /**
     * Rolni o'zgartirish — eng xavfli amal, faqat superAdmin.
     */
    public function changeRole(User $actor): bool
    {
        return $actor->role === 'superAdmin';
    }

    /**
     * Boshqa foydalanuvchining parolini majburan almashtirish.
     * O'z parolini o'zgartirish alohida oqim (joriy parol so'raladi).
     */
    public function resetPassword(User $actor, User $target): bool
    {
        if ($actor->id === $target->id) {
            return false; // o'ziga /auth/change-password ishlatsin
        }

        if ($target->role !== 'talaba') {
            return $actor->role === 'superAdmin';
        }

        return $this->isAdmin($actor);
    }

    /**
     * O'chirish. superAdmin hisobini hech kim o'chira olmaydi.
     */
    public function delete(User $actor, User $target): bool
    {
        if ($actor->id === $target->id) {
            return false; // o'zini o'chirib qo'yishning oldini olamiz
        }

        if ($target->role === 'superAdmin') {
            return false;
        }

        if ($target->role !== 'talaba') {
            return $actor->role === 'superAdmin';
        }

        return $this->isAdmin($actor);
    }
}
