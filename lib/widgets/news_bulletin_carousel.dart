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
    _controller = PageController(viewportFraction: 0.92);
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
        final screenWidth = MediaQuery.of(context).size.width;
        final cardHeight = (screenWidth * 0.42).clamp(150.0, 190.0);

        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    itemBuilder: (context, index) {
                      final item = widget.news[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.02,
                        ),
                        child: _NewsCard(news: item, theme: theme),
                      );
                    },
                  ),
                ),
              ),
              if (widget.news.length > 1) ...[
                const SizedBox(height: 10),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.news.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.primary
                              : theme.textMuted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NewsDetailScreen(news: news)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
              AppNetworkImage(
                path: news.imageUrl!,
                fit: BoxFit.cover,
                fallback: () => Container(color: theme.primary.withValues(alpha: 0.25)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primary.withValues(alpha: 0.85),
                      theme.secondary.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            // Okunabilirlik için alttan karartma
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'BÜLTEN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    news.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  if (news.summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      news.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
