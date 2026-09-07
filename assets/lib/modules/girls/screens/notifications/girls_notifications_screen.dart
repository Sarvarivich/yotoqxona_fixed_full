import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart';
import '../../providers/girls_notification_provider.dart';
import '../../services/girls_notification_model.dart';
import '../../theme/girls_theme.dart';
import 'send_girls_notification_screen.dart';

// ─── GirlsNotificationsScreen: yuborilgan bildirishnomalar tarixi.
class GirlsNotificationsScreen extends StatelessWidget {
  final UserModel? currentUser;
  const GirlsNotificationsScreen({super.key, this.currentUser});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GirlsNotificationProvider>();

    return Scaffold(
      backgroundColor: GTheme.bgBase,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GTheme.pink,
        icon: const Icon(Icons.campaign_rounded, color: Colors.white),
        label: const Text('Yuborish',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SendGirlsNotificationScreen(currentUser: currentUser),
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<GirlsNotificationModel>>(
          stream: provider.notifications,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GTheme.pink));
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 56, color: GTheme.white.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Text('Hozircha bildirishnomalar yoq',
                        style: TextStyle(color: GTheme.white.withOpacity(0.5))),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final n = items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: GTheme.cardDecoration(),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: GTheme.pink.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.campaign_rounded, color: GTheme.pink, size: 20),
                    ),
                    title: Text(n.title,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.message,
                              style: TextStyle(color: GTheme.white.withOpacity(0.6), fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Text(
                            '${n.target.displayName}${n.targetLabel != null ? " • ${n.targetLabel}" : ""} • ${GTheme.formatDateTime(n.createdAt)}',
                            style: TextStyle(color: GTheme.white.withOpacity(0.35), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: GTheme.red, size: 20),
                      onPressed: () => provider.delete(n.id),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
