import 'package:flutter/material.dart';
import '../modules/services/api_service.dart';

/// Parol muddati tugaganda chiqadigan dialog.
///
/// Talab:
/// "Siz qo'ygan joriy parolni muddati tugadi.Tizimga qaytdan kirish uchun parolingizni yangilang."
/// degan yozuv chiqsin va 41-kuni eski qo'ygan paroli bilan kirmasin va
/// oldin qo'ygan parolini ham ishlata olmasin.
class ParolMuddatiDialog extends StatefulWidget {
  final String email;
  final String? initialCurrentPassword;
  final String? message;

  const ParolMuddatiDialog({
    super.key,
    required this.email,
    this.initialCurrentPassword,
    this.message,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String email,
    String? currentPassword,
    String? message,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ParolMuddatiDialog(
        email: email,
        initialCurrentPassword: currentPassword,
        message: message,
      ),
    );
  }

  @override
  State<ParolMuddatiDialog> createState() => _ParolMuddatiDialogState();
}

class _ParolMuddatiDialogState extends State<ParolMuddatiDialog> {
  static const _card = Color(0xFF13102A);
  static const _purple = Color(0xFF6C5CE7);
  static const _violet = Color(0xFFa29bfe);
  static const _pink = Color(0xFFfd79a8);
  static const _muted = Color(0x99FFFFFF);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _currentPasswordCtrl;
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPasswordCtrl = TextEditingController(
      text: widget.initialCurrentPassword ?? '',
    );
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentPasswordCtrl.text.trim();
    final newPass = _newPasswordCtrl.text.trim();
    final confirmPass = _confirmPasswordCtrl.text.trim();

    if (newPass == currentPass) {
      setState(() {
        _errorMessage = "Yangi parol joriy paroldan farq qilishi kerak.";
      });
      return;
    }

    if (newPass != confirmPass) {
      setState(() {
        _errorMessage = "Yangi parollar bir-biriga mos kelmadi.";
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService().updateExpiredPassword(
        email: widget.email,
        currentPassword: currentPass,
        newPassword: newPass,
        newPasswordConfirmation: confirmPass,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = res['message']?.toString() ??
              "Parolni yangilashda xatolik yuz berdi.";
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Xatolik: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertMessage = widget.message ??
        "Siz qo'ygan joriy parolni muddati tugadi.Tizimga qaytdan kirish uchun parolingizni yangilang.";

    return PopScope(
      canPop: !_isLoading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _violet.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ikonka
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [_pink, _purple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _pink.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_clock_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Sarlavha
                  const Text(
                    "Parol muddati tugadi",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Asosiy talab qilingan matn
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amberAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            alertMessage,
                            style: const TextStyle(
                              color: Color(0xFFF1F2F6),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Email ko'rsatish
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_outlined,
                            size: 18, color: _muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.email,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Xatolik xabari bo'lsa
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Joriy parol
                  _buildPasswordField(
                    controller: _currentPasswordCtrl,
                    label: "Joriy (eski) parol",
                    hint: "Eski parolingizni kiriting",
                    obscure: _obscureCurrent,
                    onToggleObscure: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Joriy parolni kiriting";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Yangi parol
                  _buildPasswordField(
                    controller: _newPasswordCtrl,
                    label: "Yangi parol",
                    hint: "Kamida 6 ta belgi",
                    obscure: _obscureNew,
                    onToggleObscure: () =>
                        setState(() => _obscureNew = !_obscureNew),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Yangi parolni kiriting";
                      }
                      if (v.trim().length < 6) {
                        return "Parol kamida 6 ta belgidan iborat bo'lsin";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Yangi parolni tasdiqlash
                  _buildPasswordField(
                    controller: _confirmPasswordCtrl,
                    label: "Yangi parolni tasdiqlang",
                    hint: "Yangi parolni qayta kiriting",
                    obscure: _obscureConfirm,
                    onToggleObscure: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Parolni tasdiqlang";
                      }
                      if (v.trim() != _newPasswordCtrl.text.trim()) {
                        return "Parollar mos kelmadi";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Eslatma matni
                  const Text(
                    "Eslatma: Oldin ishlatilgan parollarni qayta tanlash mumkin emas.",
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tugmalar
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Bekor qilish",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_purple, _pink],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _purple.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "Parolni yangilash",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _violet, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.white54,
                size: 20,
              ),
              onPressed: onToggleObscure,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
