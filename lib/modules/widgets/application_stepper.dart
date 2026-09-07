import 'package:flutter/material.dart';

/// Talabaning yotoqxona arizasi jarayonini 1→5 ko'rinishida ko'rsatadi.
/// 1 — ariza to'ldirilmoqda
/// 2 — ariza ko'rib chiqilmoqda
/// 3 — yotoqxona ajratildi
/// 4 — shartnoma/to'lov bosqichi
/// 5 — yakunlandi
class ApplicationStepper extends StatelessWidget {
  final int activeStep;
  final String? subtitle;
  final String? hostelMessage;
  final bool compact;

  const ApplicationStepper({
    super.key,
    required this.activeStep,
    this.subtitle,
    this.hostelMessage,
    this.compact = false,
  });

  static const _teal = Color(0xFF38B7B5);
  static const _blue = Color(0xFF6176D8);
  static const _orange = Color(0xFFFFAE2E);
  static const _bg = Color(0xFFF4F1FF);
  static const _ink = Color(0xFF29264A);
  static const _muted = Color(0xFF8A86A8);

  @override
  Widget build(BuildContext context) {
    final current = activeStep.clamp(1, 5).toInt();
    final title = subtitle ?? switch (current) {
      1 => "Arizani to'ldiring",
      2 => "Arizangiz ko'rib chiqilmoqda",
      3 => "Siz uchun yotoqxona ajratildi",
      4 => "Shartnoma va to'lov bosqichi",
      _ => "Jarayon muvaffaqiyatli yakunlandi",
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 14 : 18,
        compact ? 12 : 16,
        compact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: const Color(0xFFE2DDF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact)
            Text(
              'YOTOQXONA ARIZASI',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: _muted,
              ),
            ),
          if (!compact) const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final stepWidth = (constraints.maxWidth - 80) / 5;
              return Row(
                children: List.generate(5, (index) {
                  final step = index + 1;
                  final isActive = step == current;
                  final isDone = step < current;
                  return Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: stepWidth.clamp(36, 90).toDouble(),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: isActive ? 48 : 40,
                                height: isActive ? 48 : 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive || isDone
                                      ? _orange
                                      : Colors.white,
                                  border: Border.all(
                                    color: isActive
                                        ? _orange
                                        : const Color(0xFFD9D5EE),
                                    width: isActive ? 3 : 2,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: _orange.withOpacity(.28),
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: isDone
                                      ? const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 19)
                                      : Text(
                                          '$step',
                                          style: TextStyle(
                                            color: isActive
                                                ? Colors.white
                                                : _muted,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _shortLabel(step),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isActive ? _ink : _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (step != 5)
                          Expanded(
                            child: Container(
                              height: 2,
                              margin: const EdgeInsets.only(bottom: 27),
                              decoration: BoxDecoration(
                                color: step < current
                                    ? _blue
                                    : const Color(0xFFD9D5EE),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSuccess(current)
                  ? _teal.withOpacity(.10)
                  : _blue.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSuccess(current)
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: isSuccess(current) ? _teal : _blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (hostelMessage != null &&
                          hostelMessage!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          hostelMessage!,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool isSuccess(int step) => step >= 3;

  static String _shortLabel(int step) => switch (step) {
        1 => 'Ariza',
        2 => 'Ko‘rib chiqish',
        3 => 'Ajratildi',
        4 => 'Shartnoma',
        _ => 'Yakun',
      };
}
