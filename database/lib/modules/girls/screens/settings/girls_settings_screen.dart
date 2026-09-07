import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../theme/girls_theme.dart';

// ─── GirlsSettingsScreen: profil, hisob va tizim sozlamalari.
class GirlsSettingsScreen extends StatelessWidget {
  final UserModel user;
  const GirlsSettingsScreen({super.key, required this.user});

  bool get _isSuperAdmin => user.role == UserRole.superAdmin;

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GTheme.bgCard,
        title: const Text('Chiqish', style: TextStyle(color: Colors.white)),
        content: const Text('Tizimdan chiqishni xohlaysizmi?',
            style: TextStyle(color: GTheme.soft)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Bekor qilish')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chiqish', style: TextStyle(color: GTheme.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseAuth.instance.signOut();
      await AuthService.logout();
    } finally {
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GTheme.bgBase,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            const Text('Sozlamalar',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Container(
              decoration: GTheme.cardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      gradient: GTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(user.email,
                            style: TextStyle(
                                color: GTheme.white.withOpacity(0.5),
                                fontSize: 12)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: GTheme.pink.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_roleLabel(user.role),
                              style: const TextStyle(
                                  color: GTheme.pink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SettingsTile(
              icon: Icons.apartment_rounded,
              iconColor: GTheme.pink,
              title: 'Yotoqxona',
              subtitle: 'Qiz bolalar uchun yotoqxona',
            ),
            _SettingsTile(
              icon: Icons.security_rounded,
              iconColor: GTheme.violet,
              title: "Ma'lumotlar xavfsizligi",
              subtitle: "Barcha malumotlar boys tizimidan alohida saqlanadi",
            ),
            if (_isSuperAdmin)
              _SettingsTile(
                icon: Icons.storage_rounded,
                iconColor: GTheme.teal,
                title: "Malumotlar bazasi",
                subtitle:
                    "girls_students, xonalar (hostel: girls), girls_complaints, girls_payments",
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                label: const Text('Tizimdan chiqish',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GTheme.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'SUPER ADMIN';
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.mudir:
        return 'MUDIRA';
      case UserRole.moliyachi:
        return 'MOLIYACHI';
      case UserRole.talaba:
        return 'TALABA';
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: GTheme.cardDecoration(),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        subtitle: Text(subtitle,
            style:
                TextStyle(color: GTheme.white.withOpacity(0.5), fontSize: 11)),
      ),
    );
  }
}
