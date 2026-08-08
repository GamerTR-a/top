import 'package:flutter/material.dart';
import '../models/topluluk.dart';
import '../theme/app_theme.dart';
import '../screens/community_detail_screen.dart';
import '../services/joined_communities_service.dart';
import 'app_network_image.dart';

class GlassCard extends StatefulWidget {
  final Topluluk topluluk;

  const GlassCard({super.key, required this.topluluk});

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isJoined = false;

  @override
  void initState() {
    super.initState();
    _loadJoinedState();
  }

  Future<void> _loadJoinedState() async {
    final joined = await JoinedCommunitiesService.instance
        .isJoined(widget.topluluk.id);
    if (mounted && joined != _isJoined) setState(() => _isJoined = joined);
  }

  Color _getPastelBgColor(int id) {
    const pastels = [
      Color(0xFFE0F2FE), // Soft Cyan / Sky
      Color(0xFFDCFCE7), // Soft Green
      Color(0xFFFEF3C7), // Soft Yellow
      Color(0xFFF3E8FF), // Soft Purple
      Color(0xFFFCE7F3), // Soft Pink
      Color(0xFFFFEDD5), // Soft Orange
      Color(0xFFE0E7FF), // Soft Indigo
    ];
    return pastels[id % pastels.length];
  }

  IconData _getCategoryFallbackIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('bilişim') || cat.contains('yazılım')) {
      return Icons.code_rounded;
    } else if (cat.contains('teknoloji') || cat.contains('havacılık')) {
      return Icons.rocket_launch_rounded;
    } else if (cat.contains('mühendislik')) {
      return Icons.precision_manufacturing_rounded;
    } else if (cat.contains('kültür') || cat.contains('sanat')) {
      return Icons.palette_rounded;
    } else if (cat.contains('sosyal')) {
      return Icons.volunteer_activism_rounded;
    } else if (cat.contains('spor')) {
      return Icons.fitness_center_rounded;
    } else if (cat.contains('uluslararası')) {
      return Icons.language_rounded;
    } else if (cat.contains('çevre')) {
      return Icons.eco_rounded;
    } else if (cat.contains('yardım')) {
      return Icons.favorite_rounded;
    }
    return Icons.groups_rounded;
  }

  Widget _logoWidget(String path, String category, Color themePrimary) {
    final fallbackIcon = _getCategoryFallbackIcon(category);
    final fallbackWidget = Icon(fallbackIcon, color: themePrimary, size: 28);
    if (path.isEmpty) return fallbackWidget;
    return AppNetworkImage(
      path: path,
      fit: BoxFit.cover,
      cacheWidth: 128,
      fallback: () => fallbackWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.topluluk;
    final ratingScore = (t.puan > 5.0 ? t.puan / 20.0 : t.puan).toStringAsFixed(1);
    final pastelColor = _getPastelBgColor(t.id);

    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        final cardBgColor = theme.isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = theme.isDark
            ? const Color(0xFF334155)
            : const Color(0xFFE2E8F0);
        final primaryTeal = theme.primary;

        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CommunityDetailScreen(topluluk: t),
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: theme.isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color(0x0F0F172A),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Card Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Center Circular Avatar
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.isDark
                                ? pastelColor.withValues(alpha: 0.18)
                                : pastelColor,
                          ),
                          child: Center(
                            child: ClipOval(
                              child: Container(
                                width: 44,
                                height: 44,
                                color: Colors.transparent,
                                child: _logoWidget(t.logoPath, t.kategori, primaryTeal),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Title
                        Text(
                          t.ad,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            height: 1.2,
                          ),
                        ),

                        // Member count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 11.5,
                              color: theme.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                '${t.uyeSayisi} üye',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textMuted,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Full-width "Katıl" Button
                        SizedBox(
                          width: double.infinity,
                          height: 30,
                          child: ElevatedButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final joined = await JoinedCommunitiesService
                                  .instance
                                  .toggle(t);
                              if (!mounted) return;
                              setState(() => _isJoined = joined);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    joined
                                        ? '${t.ad} topluluğuna katıldınız! 🎉'
                                        : '${t.ad} topluluğundan ayrıldınız.',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isJoined
                                  ? (theme.isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0))
                                  : const Color(0xFF14B8A6), // Canlı Turkuaz/Cyan
                              foregroundColor: _isJoined
                                  ? (theme.isDark ? Colors.white : Colors.black87)
                                  : Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _isJoined ? 'Katıldın ✓' : 'Katıl',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Top-Right Rating Badge (⭐ 4.8)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFFFFDE7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB800),
                            size: 11,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            ratingScore,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

