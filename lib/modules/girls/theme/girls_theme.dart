import 'package:flutter/material.dart';

// ─── GirlsTheme: Qizlar yotoqxonasi moduli uchun ranglar palitrasi.
// Boys moduli (roles/admin_screen.dart dagi _C) bilan BIR XIL dizayn
// tili ishlatiladi — shunda ikkala tizim vizual jihatdan bir xil
// ko'rinadi, faqat ma'lumotlari alohida bo'ladi.
class GTheme {
  static const bgBase = Color(0xFF0F0D1A);
  static const bgCard = Color(0xFF1A1730);
  static const bgCard2 = Color(0xFF16132B);
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFa29bfe);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFfd79a8);
  static const orange = Color(0xFFfdcb6e);
  static const coral = Color(0xFFe17055);
  static const red = Color(0xFFff7675);
  static const white = Color(0xFFFFFFFF);
  static const soft = Color(0xB3FFFFFF);
  static const muted = Color(0x66FFFFFF);
  static const faint = Color(0x0FFFFFFF);

  static const primaryGradient = LinearGradient(
    colors: [pink, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration cardDecoration({Color? color, double radius = 18}) {
    return BoxDecoration(
      color: color ?? bgCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: white.withOpacity(0.06)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static InputDecoration inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: white.withOpacity(0.55), fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, color: pink, size: 20) : null,
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: pink, width: 1.5),
      ),
    );
  }

  /// Sana va vaqtni tashqi `intl` paketisiz formatlash (loyihada intl
  /// to'g'ridan-to'g'ri deklaratsiya qilinmagani uchun).
  static String formatDate(DateTime? dt) {
    if (dt == null) return '-';
    const oylar = [
      'Yan',
      'Fev',
      'Mar',
      'Apr',
      'May',
      'Iyun',
      'Iyul',
      'Avg',
      'Sen',
      'Okt',
      'Noy',
      'Dek'
    ];
    final oy = oylar[dt.month - 1];
    return '${dt.day} $oy ${dt.year}';
  }

  static String formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${formatDate(dt)}, $h:$m';
  }

  static String formatMoney(num value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }
}
