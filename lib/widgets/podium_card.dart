import 'package:flutter/material.dart';
import '../models/leaderboard_model.dart';
import '../theme/app_theme.dart';
import 'app_network_image.dart';

Widget _buildAvatar(String path, double size) {
  final fallback = Container(
    color: Colors.grey.shade800,
    child: Icon(Icons.person, color: Colors.white, size: size * 0.5),
  );
  return AppNetworkImage(
    path: path,
    fit: BoxFit.cover,
    fallback: () => fallback,
  );
}

class PodiumCard extends StatelessWidget {
  final RankingModel rank;
  final double height;
  final Color color;
  final String crown;

  const PodiumCard({
    super.key,
    required this.rank,
    required this.height,
    required this.color,
    required this.crown,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        final isFirst = rank.siralama == 1;
        final avatarSize = height * 0.45;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Taç / Kask emojisi
            Text(crown, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),

            // Profil Avatarı
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: isFirst ? 3 : 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isFirst ? 0.7 : 0.5),
                    blurRadius: isFirst ? 18 : 10,
                    spreadRadius: isFirst ? 3 : 2,
                  ),
                ],
              ),
              child: ClipOval(child: _buildAvatar(rank.gorsel, avatarSize)),
            ),
            const SizedBox(height: 8),

            // İsim
            Text(
              rank.isim,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),

            // Puan
            Text(
              '${rank.puan} P',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Podyum Tabanı — ŞERİTLİ & ŞIK
            _StripedPodiumBase(
              width: 82,
              height: height,
              color: color,
              rank: rank.siralama,
              isDark: theme.isDark,
            ),
          ],
        );
      },
    );
  }
}

/// Şeritli, gradient podyum tabanı widget'ı
class _StripedPodiumBase extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final int rank;
  final bool isDark;

  const _StripedPodiumBase({
    required this.width,
    required this.height,
    required this.color,
    required this.rank,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(14),
        topRight: Radius.circular(14),
      ),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.55),
              color.withValues(alpha: 0.25),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
          ),
          border: Border.all(
            color: color.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Şeritler (diagonal stripes)
            CustomPaint(
              size: Size(width, height),
              painter: _StripePainter(
                color: color.withValues(alpha: 0.18),
              ),
            ),
            // Sıralama numarası
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.85),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diagonal şerit çizer
class _StripePainter extends CustomPainter {
  final Color color;

  const _StripePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    const spacing = 14.0;
    final total = (size.width + size.height) / spacing;

    for (int i = -1; i < total + 1; i++) {
      final x = i * spacing;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) =>
      oldDelegate.color != color;
}
