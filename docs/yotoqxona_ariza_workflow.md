# Yotoqxona ariza workflow — 1 → 5

## Talaba

1. **Ariza to‘ldirish** — `register.dart` dagi stepper 1-bosqichni ko‘rsatadi.
2. **Ariza ko‘rib chiqilmoqda** — ro‘yxatdan o‘tish yakunlanganda Firestore:
   - `applicationStep: 2`
   - `applicationStatus: submitted`
3. **Yotoqxona ajratildi** — mudir fizik yotoqxona + xona yoki ijara variantini biriktirganda:
   - `applicationStep: 3`
   - `applicationStatus: assigned`
4. **Shartnoma / to‘lov** — talaba xona bilan biriktirilgan bo‘lsa To‘lovlar bo‘limi ochiladi. Chek moliyaga yuborilganda:
   - `applicationStep: 4`
   - `applicationStatus: payment_pending`
5. **Yakunlandi** — moliyachi chekni tasdiqlaganda:
   - `applicationStep: 5`
   - `applicationStatus: completed`

## Mudir

Ariza yuborgan talabalar real-time ro‘yxatda ko‘rinadi. Filtrlar:
- Barchasi
- Ijtimoiy holatdagi
- Oddiy holatdagi

Talabani biriktirish variantlari:
- Universitet yotoqxonasi (`university`)
- Avto yo‘l yotoqxonasi (`avto_yol`)
- Med kollej yotoqxonasi (`med_college`)
- Navoiydagi obyekt yotoqxonasi (`navoi_object`)
- Ijara uchun ajratilgan (`rental`)

Fizik yotoqxona tanlanganda faqat tanlangan tur va mudirning o‘g‘il/qiz yo‘nalishiga mos, sig‘imida bo‘sh joy bor xonalar ko‘rsatiladi. Bo‘sh xona bo‘lmasa **Yangi xona qo‘shish** oynasi chiqadi.

Ijara tanlanganda xona yaratilmaydi va talaba 3-bosqichda maxsus Yoshlar bilan ishlash departamenti xabarini ko‘radi.

## To‘lovlar

`TalabaProfileScreen` To‘lovlar bo‘limini faqat `hasRoom == true` bo‘lganda menyuga chiqaradi. Talaba xona bilan biriktirilmaguncha To‘lovlar sahifasi UI’da ko‘rinmaydi.

To‘lovlar sahifasida:
- Shartnomani yuklab olish
- To‘lov sanasini tanlash
- Summani kiritish
- Chek faylini yuklash
- Moliya bo‘limiga yuborish
- Chek holatini kuzatish

Moliya tasdiqlagach 5-bosqich avtomatik faollashadi.
