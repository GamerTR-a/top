import 'package:flutter/material.dart';
import '../models/leaderboard_model.dart';
import '../theme/app_theme.dart';
import 'app_network_image.dart';

Widget _buildRankImage(String path, AppTheme theme) {
  final fallback = Container(
    color: theme.surface,
    child: Icon(Icons.person, color: theme.primary, size: 24),
  );
  return AppNetworkImage(
    path: path,
    fit: BoxFit.cover,
    cacheWidth: 80,
    fallback: () => fallback,
  );
}

class RankingItem extends StatelessWidget {
  final RankingModel rank;
  final int index;

  const RankingItem({super.key, required this.rank, required this.index});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.isDark
                ? theme.surface.withValues(alpha: 0.4)
                : theme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.isDark
                  ? theme.primary.withValues(alpha: 0.1)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '${rank.siralama}',
                  style: TextStyle(
                    color: theme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ClipOval(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: _buildRankImage(rank.gorsel, theme),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rank.isim,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _buildTrendIcon(theme),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${rank.puan}',
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Puan',
                    style: TextStyle(color: theme.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendIcon(AppTheme theme) {
    switch (rank.trend) {
      case 'up':
        return Icon(Icons.arrow_upward, color: theme.secondary, size: 16);
      case 'down':
        return Icon(Icons.arrow_downward, color: theme.error, size: 16);
      default:
        return Icon(Icons.horizontal_rule, color: theme.textMuted, size: 16);
    }
  }
}
