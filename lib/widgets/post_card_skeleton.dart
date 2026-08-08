import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Gönderi yüklenirken gösterilen iskelet (skeleton) kartı.
/// Harici paket gerektirmez; hafif bir nabız (pulse) animasyonu kullanır.
class PostCardSkeleton extends StatefulWidget {
  const PostCardSkeleton({super.key});

  @override
  State<PostCardSkeleton> createState() => _PostCardSkeletonState();
}

class _PostCardSkeletonState extends State<PostCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeNotifier.value;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.textMuted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = 1 - (_c.value - 0.5).abs() * 2; // 0 → 1 → 0 nabız
        return Opacity(opacity: 0.45 + 0.35 * t, child: child);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.primary.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.textMuted.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(120, 12),
                    const SizedBox(height: 6),
                    bar(80, 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            bar(double.infinity, 12),
            const SizedBox(height: 8),
            bar(double.infinity, 12),
            const SizedBox(height: 8),
            bar(200, 12),
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: theme.textMuted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
