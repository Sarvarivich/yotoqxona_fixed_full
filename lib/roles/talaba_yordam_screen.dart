import 'package:flutter/material.dart';
import '../modules/models/user_model.dart';
import '../modules/murojaat/murojaat_yozish.dart';
import '../modules/murojaat/murojaatlar_list.dart';

// Talaba uchun "Yordam markazi" sahifasi.
// Bosh sahifadagi "Yordam markazi" tez harakat tugmasidan ochiladi.

class _Y {
  static const bgBase = Color(0xFF0F0D1A);
  static const bgCard = Color(0xFF1A1730);
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFa29bfe);
  static const teal = Color(0xFF00CEC9);
  static const pink = Color(0xFFfd79a8);
  static const white = Color(0xFFFFFFFF);
  static const soft = Color(0xB3FFFFFF);
  static const muted = Color(0x66FFFFFF);
}

class _Faq {
  final String savol;
  final String javob;
  const _Faq(this.savol, this.javob);
}

// Umumiy savollar. Aniq sana, narx yoki telefon raqamlarini bu yerga
// yozmang: ular o'zgarishi mumkin. Shunday ma'lumotlarni backend'dan oling.
const List<_Faq> _savollar = [
  _Faq(
    "Arizamning holatini qayerdan bilsam bo'ladi?",
    "Bosh sahifadagi \"Yotoqxona arizasi\" bo'limida joriy bosqich ko'rsatiladi. "
        "Batafsil ma'lumot uchun \"Murojaat\" bo'limidan foydalaning.",
  ),
  _Faq(
    "Yotoqxona to'lovini qanday amalga oshiraman?",
    "\"To'lov qilish\" tugmasi orqali to'lov sahifasiga o'ting. "
        "To'lov tasdiqlangandan keyin holat avtomatik yangilanadi.",
  ),
  _Faq(
    "Xona ma'lumotlarim noto'g'ri bo'lsa nima qilaman?",
    "Bu haqda murojaat yuboring. Yotoqxona mudiri ma'lumotlarni tekshirib, javob beradi.",
  ),
  _Faq(
    "Murojaatimga qachon javob beriladi?",
    "Javob muddati murojaat turiga bog'liq. Holatini \"Murojaat\" bo'limida kuzatib boring.",
  ),
  _Faq(
    "Murojaatimni o'zgartira olamanmi?",
    "Yuborilgan murojaatni o'zgartirib bo'lmaydi. Yangi ma'lumot bo'lsa, yangi murojaat yuboring.",
  ),
];

class TalabaYordamScreen extends StatelessWidget {
  final UserModel? user;
  final bool showAppBar;
  const TalabaYordamScreen({
    super.key,
    required this.user,
    this.showAppBar = true,
  });

  bool get _canWrite => user != null && user!.id.isNotEmpty;

  void _openNewComplaint(BuildContext context) {
    final u = user!;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MurojaatYozish(
        studentId: u.id,
        studentName: u.fullName,
        hostel: u.hostel ?? 'boys',
      ),
    ));
  }

  void _openMyComplaints(BuildContext context) {
    final u = user!;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MurojaatlarList(
        isAdmin: false,
        hostel: u.hostel ?? 'boys',
        studentId: u.id,
        studentName: u.fullName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Y.bgBase,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: _Y.bgBase,
              foregroundColor: _Y.white,
              elevation: 0,
              title: const Text(
                'Yordam markazi',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (!showAppBar)
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 16),
              child: Text(
                'Yordam markazi',
                style: TextStyle(
                  color: _Y.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          _Kartochka(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Qanday yordam kerak?',
                  style: TextStyle(
                    color: _Y.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Savolingizga quyida javob toping yoki murojaat yuboring.",
                  style: TextStyle(color: _Y.soft, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                _Tugma(
                  icon: Icons.edit_note_rounded,
                  label: 'Murojaat yuborish',
                  color: _Y.purple,
                  onTap: _canWrite ? () => _openNewComplaint(context) : null,
                ),
                const SizedBox(height: 10),
                _Tugma(
                  icon: Icons.forum_rounded,
                  label: 'Mening murojaatlarim',
                  color: _Y.teal,
                  onTap: _canWrite ? () => _openMyComplaints(context) : null,
                ),
                if (!_canWrite)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      "Murojaat yuborish uchun tizimga kiring.",
                      style: TextStyle(color: _Y.muted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "Tez-tez so'raladigan savollar",
              style: TextStyle(
                color: _Y.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _Kartochka(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _savollar.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: _Y.white.withOpacity(0.06)),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      iconColor: _Y.violet,
                      collapsedIconColor: _Y.muted,
                      title: Text(
                        _savollar[i].savol,
                        style: const TextStyle(
                          color: _Y.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _savollar[i].javob,
                            style: const TextStyle(
                              color: _Y.soft,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Kartochka(
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: _Y.pink.withOpacity(0.9), size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Savolingiz javobsiz qolsa, \"Murojaat yuborish\" orqali yozing.",
                    style: TextStyle(color: _Y.soft, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Kartochka extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Kartochka({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _Y.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Y.white.withOpacity(0.06)),
      ),
      child: child,
    );
  }
}

class _Tugma extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _Tugma({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: _Y.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    color: _Y.white.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
