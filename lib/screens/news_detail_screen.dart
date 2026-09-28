import 'package:flutter/material.dart';
import '../models/news_model.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';

class NewsDetailScreen extends StatelessWidget {
  final NewsModel news;

  const NewsDetailScreen({super.key, required this.news});

  String _formatDate(DateTime dt) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final local = dt.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: theme.background,
          body: AnimatedThemeBackground(
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Geri',
                      ),
                    ),
                  ),
                  if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: AppNetworkImage(
                              path: news.imageUrl!,
                              fit: BoxFit.cover,
                              fallback: () => Container(
                                color: theme.primary.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.campaign_rounded, color: theme.primary, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(news.publishedAt),
                                style: TextStyle(
                                  color: theme.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            news.title,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            news.content.isNotEmpty ? news.content : news.summary,
                            style: TextStyle(
                              color: theme.textColor.withValues(alpha: 0.9),
                              fontSize: 15,
                              height: 1.6,
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
