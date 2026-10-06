import 'dart:async';
import 'package:flutter/material.dart';
import '../models/news_model.dart';
import '../screens/news_detail_screen.dart';
import '../theme/app_theme.dart';
import 'app_network_image.dart';

/// Anasayfanın en üstünde gösterilen, otomatik kayan haber/bülten akışı.
/// - 5 saniyede bir otomatik sonraki karta geçer.
/// - Kullanıcı kaydırdığında otomatik geçiş kısa süre duraklar.
/// - Sayfa göstergesi (nokta) ile mevcut konum gösterilir.
/// - Karta dokununca haber detay sayfası açılır.
class NewsBulletinCarousel extends StatefulWidget {
  final List<NewsModel> news;

  const NewsBulletinCarousel({super.key, required this.news});

  @override
  State<NewsBulletinCarousel> createState() => _NewsBulletinCarouselState();
}

class _NewsBulletinCarouselState extends State<NewsBulletinCarousel> {
  static const _autoAdvanceInterval = Duration(seconds: 5);
  static const _resumeDelay = Duration(seconds: 8);

  late final PageController _controller;
  Timer? _autoTimer;
  Timer? _resumeTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoAdvance();
  }

  @override
  void didUpdateWidget(covariant NewsBulletinCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.news.length != widget.news.length) {
      _currentPage = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _startAutoAdvance();
    }
  }

  void _startAutoAdvance() {
    _autoTimer?.cancel();
    if (widget.news.length < 2) return;
    _autoTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_currentPage + 1) % widget.news.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  /// Kullanıcı manuel kaydırdığında otomatik geçişi geçici olarak durdurur,
  /// bir süre etkileşim olmazsa otomatik geçişi tekrar başlatır.
  void _pauseThenResume() {
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeDelay, () {
      if (mounted) _startAutoAdvance();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.news.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        final gutter = MediaQuery.of(context).size.width * 0.04;
        // Büyük yazı tipi ayarında iki satır başlık + özet sığsın.
        final cardHeight =
            MediaQuery.textScalerOf(context).scale(96).clamp(96.0, 132.0);

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: cardHeight,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notif) {
                    if (notif is UserScrollNotification ||
                        notif is ScrollStartNotification) {
                      _pauseThenResume();
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.news.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: _NewsCard(news: widget.news[index], theme: theme),
                    ),
                  ),
                ),
              ),
              if (widget.news.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.news.length, (i) {
                    final isActive = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: isActive ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.primary
                            : theme.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsModel news;
  final AppTheme theme;

  const _NewsCard({required this.news, required this.theme});

  static const _months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  String get _dateLabel {
    final d = news.publishedAt.toLocal();
    return '${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = news.imageUrl != null && news.imageUrl!.isNotEmpty;
    final radius = BorderRadius.circular(16);

    Widget placeholder() => Container(
          color: theme.primary.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: Icon(Icons.article_outlined, color: theme.primary, size: 26),
        );

    return Material(
      color: theme.isDark ? theme.surface.withValues(alpha: 0.7) : theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: theme.isDark
              ? theme.textMuted.withValues(alpha: 0.18)
              : const Color(0xFFE2E8F0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NewsDetailScreen(news: news)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: hasImage
                      ? AppNetworkImage(
                          path: news.imageUrl!,
                          fit: BoxFit.cover,
                          fallback: placeholder,
                        )
                      : placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Haber · $_dateLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      news.title,
                      maxLines: news.summary.isEmpty ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (news.summary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        news.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textMuted.withValues(alpha: 0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
