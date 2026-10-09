import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modules/services/api_service.dart';

// "Parolni unutdim" oynasi. Oqim: telefon -> 6 xonali kod -> yangi parol -> tasdiqlash.
class ParolTiklashDialog extends StatefulWidget {
  const ParolTiklashDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ParolTiklashDialog(),
    );
  }

  @override
  State<ParolTiklashDialog> createState() => _ParolTiklashDialogState();
}

enum _Qadam { telefon, kod, yangiParol, tayyor }

class _ParolTiklashDialogState extends State<ParolTiklashDialog> {
  static const _card = Color(0xFF13102A);
  static const _purple = Color(0xFF6C5CE7);
  static const _violet = Color(0xFFa29bfe);
  static const _teal = Color(0xFF00CEC9);
  static const _pink = Color(0xFFfd79a8);
  static const _muted = Color(0x99FFFFFF);

  final _api = ApiService();
  _Qadam _qadam = _Qadam.telefon;

  final _telefon = TextEditingController();
  final _kod = TextEditingController();
  final _parol = TextEditingController();
  final _parol2 = TextEditingController();

  bool _yuklanmoqda = false;
  bool _korsatish = false;
  String? _xato;
  String? _resetToken;

  @override
  void initState() {
    super.initState();
    _parol.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _telefon.dispose();
    _kod.dispose();
    _parol.dispose();
    _parol2.dispose();
    super.dispose();
  }

  Map<String, bool> get _qoidalar {
    final p = _parol.text;
    return {
      "Kamida 12 ta belgi": p.length >= 12,
      "Katta harf (A-Z)": RegExp(r'[A-Z]').hasMatch(p),
      "Kichik harf (a-z)": RegExp(r'[a-z]').hasMatch(p),
      "Raqam (0-9)": RegExp(r'[0-9]').hasMatch(p),
      "Belgi (!@#...)": RegExp(r'[^a-zA-Z0-9]').hasMatch(p),
    };
  }

  String _xatoMatni(Object e) {
    if (e is ApiException) return e.message;
    return "Xatolik yuz berdi. Qayta urinib ko'ring.";
  }

  Future<void> _bajar(Future<void> Function() amal) async {
    setState(() {
      _yuklanmoqda = true;
      _xato = null;
    });
    try {
      await amal();
    } catch (e) {
      if (mounted) setState(() => _xato = _xatoMatni(e));
    } finally {
      if (mounted) setState(() => _yuklanmoqda = false);
    }
  }

  Future<void> _kodYubor() => _bajar(() async {
        final tel = _telefon.text.trim();
        if (tel.replaceAll(RegExp(r'\D'), '').length < 9) {
          throw ApiException(message: "Telefon raqamini to'liq kiriting.");
        }
        await _api.post('password-reset/request',
            body: {'phone': tel}, auth: false);
        if (mounted) setState(() => _qadam = _Qadam.kod);
      });

  Future<void> _kodTasdiqla() => _bajar(() async {
        final javob = await _api.post('password-reset/verify', auth: false, body: {
          'phone': _telefon.text.trim(),
          'code': _kod.text.trim(),
        });
        _resetToken = javob['reset_token']?.toString();
        if (_resetToken == null) {
          throw ApiException(message: "Kod noto'g'ri yoki muddati tugagan.");
        }
        if (mounted) setState(() => _qadam = _Qadam.yangiParol);
      });

  Future<void> _parolniSaqla() => _bajar(() async {
        final qoidalar = _qoidalar;
        if (qoidalar.values.any((ok) => !ok)) {
          throw ApiException(
              message: "Parol talablarga javob bermayapti.");
        }
        if (_parol.text != _parol2.text) {
          throw ApiException(message: "Parollar bir xil emas.");
        }
        await _api.post('password-reset/confirm', auth: false, body: {
          'reset_token': _resetToken,
          'password': _parol.text,
          'password_confirmation': _parol2.text,
        });
        if (mounted) setState(() => _qadam = _Qadam.tayyor);
      });

  InputDecoration _maydon(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      prefixIcon: Icon(icon, color: _violet, size: 20),
      filled: true,
      fillColor: const Color(0xFF1C1838),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _purple, width: 1.5),
      ),
    );
  }

  Widget _qadamBelgisi() {
    final index = _Qadam.values.indexOf(_qadam);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final faol = i <= index && _qadam != _Qadam.tayyor;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == index ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: faol ? _purple : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _tugma(String matn, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _yuklanmoqda ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _yuklanmoqda
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white))
            : Text(matn,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  Widget _xatoKarta() {
    if (_xato == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _pink.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _pink.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _pink, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_xato!,
                style: const TextStyle(color: _pink, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _telefonQadami() => Column(
        key: const ValueKey('telefon'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Tizimga biriktirilgan telefon raqamingizni kiriting.",
              style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _telefon,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
            style: const TextStyle(color: Colors.white),
            decoration: _maydon("+998 90 123 45 67", Icons.phone_outlined),
          ),
          _xatoKarta(),
          const SizedBox(height: 20),
          _tugma("Kod yuborish", _kodYubor),
        ],
      );

  Widget _kodQadami() => Column(
        key: const ValueKey('kod'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "${_telefon.text.trim()} raqamiga yuborilgan 6 xonali kodni kiriting. Kod 5 daqiqa amal qiladi.",
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _kod,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
                color: Colors.white, fontSize: 24, letterSpacing: 12),
            decoration: _maydon("••••••", Icons.pin_outlined).copyWith(counterText: ''),
          ),
          _xatoKarta(),
          const SizedBox(height: 20),
          _tugma("Tasdiqlash", _kodTasdiqla),
        ],
      );

  Widget _parolQoidaChip(String matn, bool ok) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (ok ? _teal : Colors.white).withOpacity(ok ? 0.14 : 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 14, color: ok ? _teal : _muted),
            const SizedBox(width: 6),
            Text(matn,
                style: TextStyle(
                    color: ok ? _teal : _muted, fontSize: 11.5)),
          ],
        ),
      );

  Widget _yangiParolQadami() => Column(
        key: const ValueKey('parol'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Yangi parol o'rnating. Parol kamida 12 ta belgi bo'lib, katta harf, kichik harf, raqam va belgini o'z ichiga olishi shart.",
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _parol,
            obscureText: !_korsatish,
            style: const TextStyle(color: Colors.white),
            decoration: _maydon("Yangi parol", Icons.lock_outline_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _korsatish ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: _muted,
                  size: 20,
                ),
                onPressed: () => setState(() => _korsatish = !_korsatish),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _qoidalar.entries
                .map((e) => _parolQoidaChip(e.key, e.value))
                .toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _parol2,
            obscureText: !_korsatish,
            style: const TextStyle(color: Colors.white),
            decoration: _maydon("Parolni tasdiqlang", Icons.lock_reset_rounded),
          ),
          _xatoKarta(),
          const SizedBox(height: 20),
          _tugma("Parolni yangilash", _parolniSaqla),
        ],
      );

  Widget _tayyorQadami() => Column(
        key: const ValueKey('tayyor'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purple, _violet]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _purple.withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          const Text("Parol yangilandi",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text("Yangi parol bilan tizimga kirishingiz mumkin.",
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 20),
          _tugma("Kirish", () => Navigator.pop(context)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final body = switch (_qadam) {
      _Qadam.telefon => _telefonQadami(),
      _Qadam.kod => _kodQadami(),
      _Qadam.yangiParol => _yangiParolQadami(),
      _Qadam.tayyor => _tayyorQadami(),
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _purple.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(0.25),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _purple.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: _violet, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text("Parolni unutdim",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (_qadam != _Qadam.tayyor && !_yuklanmoqda)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _muted),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _qadamBelgisi(),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
