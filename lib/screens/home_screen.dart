import 'dart:async';
import 'package:flutter/material.dart';
import '../models/auth_user_model.dart';
import '../models/discount_model.dart';
import '../models/post_model.dart';
import '../services/supabase_data_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import '../widgets/discount_carousel.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';
import '../theme/app_theme.dart';
import 'notifications_screen.dart';
import 'create_post_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthUser? currentUser;

  const HomeScreen({super.key, this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseDataService _dataService = SupabaseDataService();

  bool _isLoading = true;
  String? _errorMsg;
  List<DiscountModel> _kuponlar = [];
  List<PostModel> _gonderiler = [];
  List<Map<String, dynamic>> _etkinlikler = [];

  static const int _haftalikDestekIzni = 2;
  int _kullanilanDestek = 0;
  Set<int> _supportedPostIds = {};
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToSocket();
  }

  void _listenToSocket() {
    _socketSub = socketService.onPostSupported.listen((event) {
      final postId = (event['postId'] as num?)?.toInt();
      final serverCount = (event['supportCount'] as num?)?.toInt();
      if (postId == null || serverCount == null || !mounted) return;
      // Sunucudan gelen yetkili sayıyı yansıt (kendi işlemlerimiz dahil)
      setState(() {
        _gonderiler = [
          for (final p in _gonderiler)
            p.id == postId ? p.copyWith(destekPuani: serverCount) : p,
        ];
      });
    });
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  void _updatePost(int postId, PostModel Function(PostModel) updater) {
    setState(() {
      _gonderiler = [
        for (final p in _gonderiler) p.id == postId ? updater(p) : p,
      ];
    });
  }

  /// Önbellekte veri varsa anında gösterir; varsa true döner (skeleton atlanır).
  bool _applyCachedLists() {
    final posts = _dataService.getCachedGonderiler();
    final kuponlar = _dataService.getCachedKuponlar();
    final etkinlikler = _dataService.getCachedUpcomingEvents();
    if (posts.isEmpty && kuponlar.isEmpty && etkinlikler.isEmpty) {
      return false;
    }
    if (!mounted) return false;
    setState(() {
      if (posts.isNotEmpty) _gonderiler = posts;
      if (kuponlar.isNotEmpty) _kuponlar = kuponlar;
      if (etkinlikler.isNotEmpty) _etkinlikler = etkinlikler;
      _isLoading = false;
      _errorMsg = null;
    });
    return true;
  }

  Future<void> _loadData() async {
    // 1) Önbellekten anında göster — ağ sonucu gelene kadar boş/skeleton bekleme.
    final hadCache = _applyCachedLists();
    if (!hadCache) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
    }
    try {
      final results = await Future.wait([
        _dataService.getKuponlar(),
        _dataService.getGonderiler(),
        _dataService.getSupportStatus().catchError((e) {
          debugPrint('[Home] Destek durumu alınamadı: $e');
          return <String, dynamic>{};
        }),
        _dataService.getUpcomingEvents().catchError((e) {
          debugPrint('[Home] Etkinlikler alınamadı: $e');
          return <Map<String, dynamic>>[];
        }),
        _dataService.getAllMyRatings().catchError((e) {
          debugPrint('[Home] Puanlarım alınamadı: $e');
          return <int, int>{};
        }),
      ]);
      final posts = results[1] as List<PostModel>;
      final myRatings = results[4] as Map<int, int>;
      final statusData = results[2] as Map<String, dynamic>;
      final supported =
          (statusData['supportedPostIds'] as List?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          {};
      final used = (statusData['weeklyUsed'] as num?)?.toInt() ?? 0;
      final updatedPosts = posts
          .map(
            (p) => p.copyWith(
              isSupportedByMe: supported.contains(p.id),
              myRating: myRatings[p.id],
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _kuponlar = results[0] as List<DiscountModel>;
        _gonderiler = updatedPosts;
        _etkinlikler = results[3] as List<Map<String, dynamic>>;
        _kullanilanDestek = used;
        _supportedPostIds = supported;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Önbellekte içerik gösteriliyorsa tam ekran hataya düşme — son veri kalsın.
        if (!hadCache) {
          _errorMsg =
              'Veriler yüklenirken bir hata oluştu. Yenilemek için çekin.';
        }
      });
    }
  }

  Future<void> _handleSupportTap(PostModel post) async {
    if (post.isSupportedByMe) {
      _updatePost(
        post.id,
        (p) =>
            p.copyWith(isSupportedByMe: false, destekPuani: p.destekPuani - 1),
      );
      setState(() {
        _kullanilanDestek -= 1;
        _supportedPostIds.remove(post.id);
      });
      _showNotification(
        '${post.toplulukAdi} üzerinden desteğini çektin.',
        isError: true,
      );
      try {
        await _dataService.unsupportPost(post.id);
      } catch (_) {
        if (!mounted) return;
        _updatePost(
          post.id,
          (p) =>
              p.copyWith(isSupportedByMe: true, destekPuani: p.destekPuani + 1),
        );
        setState(() {
          _kullanilanDestek += 1;
          _supportedPostIds.add(post.id);
        });
      }
    } else {
      if (_kullanilanDestek >= _haftalikDestekIzni) {
        _showNotification(
          'Haftalık destek haklarını tükettin! (2/2)',
          isError: true,
        );
        return;
      }
      _updatePost(
        post.id,
        (p) =>
            p.copyWith(isSupportedByMe: true, destekPuani: p.destekPuani + 1),
      );
      setState(() {
        _kullanilanDestek += 1;
        _supportedPostIds.add(post.id);
      });
      _showNotification(
        '${post.toplulukAdi}\'na destek verdin! ❤️',
        isError: false,
      );
      notificationService.add(
        title: 'Destek Verildi ❤️',
        body: '${post.toplulukAdi} topluluğuna destek verdin.',
        icon: Icons.favorite_outline,
        color: const Color(0xFFFF5252),
      );
      try {
        await _dataService.supportPost(post.id);
      } catch (_) {
        if (!mounted) return;
        _updatePost(
          post.id,
          (p) => p.copyWith(
            isSupportedByMe: false,
            destekPuani: p.destekPuani - 1,
          ),
        );
        setState(() {
          _kullanilanDestek -= 1;
          _supportedPostIds.remove(post.id);
        });
        _showNotification('Destek verilemedi, tekrar dene.', isError: true);
      }
    }
  }

  void _handleRatingChanged(PostModel post, int newRating) {
    _showNotification('Puan verildi: $newRating ⭐', isError: false);
    _updatePost(post.id, (p) => p.copyWith(myRating: newRating));
    if (widget.currentUser == null) return;
    _dataService
        .ratePost(post.id, newRating)
        .then((res) {
          final avg = (res['rating_avg'] as num?)?.toDouble();
          final cnt = (res['rating_count'] as num?)?.toInt();
          final firstTime = res['first_time'] == true;
          if (!mounted) return;
          setState(() {
            _gonderiler = [
              for (final p in _gonderiler)
                p.id == post.id
                    ? p.copyWith(
                        myRating: newRating,
                        ratingAvg: avg,
                        ratingCount: cnt,
                      )
                    : p,
            ];
          });
          if (firstTime) {
            notificationService.add(
              title: '10 XP Kazandın! 🎮',
              body: '${post.toplulukAdi} gönderisini $newRating ⭐ ile '
                  'değerlendirdin.',
              icon: Icons.star_outline,
              color: const Color(0xFFFFD700),
            );
          }
        })
        .catchError((e) {
          debugPrint('[Home] Puan güncellenemedi: $e');
          if (mounted) {
            _showNotification('Puan kaydedilemedi.', isError: true);
          }
        });
  }

  void _showNotification(String message, {bool isError = false}) {
    final theme = themeNotifier.value;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? theme.error : theme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleReport(PostModel post) async {
    final theme = themeNotifier.value;
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Gönderiyi Şikayet Et 🚩',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLength: 300,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Gerekçe (isteğe bağlı)',
            hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
            filled: true,
            fillColor: theme.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: TextStyle(color: theme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dataService.reportPost(post.id, reason: reasonCtrl.text.trim());
      if (mounted) _showNotification('Şikayetin alındı. İnceleyeceğiz. 🚩');
    } catch (e) {
      debugPrint('[Home] Şikayet gönderilemedi: $e');
      if (mounted) _showNotification('Şikayet gönderilemedi.', isError: true);
    }
  }

  Future<void> _openCreatePost() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(user: widget.currentUser),
      ),
    );
    if (created == true) _loadData();
  }

  String _getUserDisplayName() {
    final raw = widget.currentUser?.name.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw.split(' ').first;
    }
    return 'Ada';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        final canPost = widget.currentUser?.isAdmin == true ||
            widget.currentUser?.isBaskan == true;
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: canPost
              ? FloatingActionButton(
                  onPressed: _openCreatePost,
                  backgroundColor: theme.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
          body: AnimatedThemeBackground(
            child: SafeArea(
              child: _isLoading
                  ? ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      itemBuilder: (_, _) => const PostCardSkeleton(),
                    )
                  : _errorMsg != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 64,
                              color: theme.error.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMsg!,
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadData,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tekrar Dene'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: theme.primary,
                      backgroundColor: theme.surface,
                      onRefresh: _loadData,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: MediaQuery.of(context).size.width * 0.04,
                                right: MediaQuery.of(context).size.width * 0.04,
                                top: 16.0,
                                bottom: 4.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Merhaba, ${_getUserDisplayName()} ',
                                              style: TextStyle(
                                                color: theme.textColor,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            const Text(
                                              '👋',
                                              style: TextStyle(fontSize: 22),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Topluluklarla keşfet, öğren, geliş!',
                                          style: TextStyle(
                                            color: theme.textMuted,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ValueListenableBuilder<List<AppNotification>>(
                                    valueListenable:
                                        notificationService.notifications,
                                    builder: (ctx, notifs, _) {
                                      final unread =
                                          notifs.where((n) => !n.isRead).length;
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const NotificationsScreen(),
                                                ),
                                              );
                                            },
                                            icon: Icon(
                                              Icons.notifications_outlined,
                                              color: theme.textColor,
                                              size: 24,
                                            ),
                                            tooltip: 'Bildirimler',
                                            style: IconButton.styleFrom(
                                              backgroundColor: theme.isDark
                                                  ? theme.surface.withValues(
                                                      alpha: 0.6,
                                                    )
                                                  : theme.surface,
                                              padding: const EdgeInsets.all(10),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                side: BorderSide(
                                                  color: theme.isDark
                                                      ? theme.primary
                                                          .withValues(alpha: 0.3)
                                                      : const Color(0xFFE2E8F0),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (unread > 0)
                                            Positioned(
                                              top: -2,
                                              right: -2,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(5),
                                                decoration: BoxDecoration(
                                                  color: theme.error,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '$unread',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: DiscountCarousel(kuponlar: _kuponlar),
                          ),
                          if (_etkinlikler.isNotEmpty)
                            SliverToBoxAdapter(
                              child: _UpcomingEventsSection(
                                events: _etkinlikler,
                                theme: theme,
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: MediaQuery.of(context).size.width * 0.04,
                                right: MediaQuery.of(context).size.width * 0.04,
                                top: 16.0,
                                bottom: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Topluluk Akışı 🔮',
                                    style: TextStyle(
                                      color: theme.textColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Kalan Destek: ${_haftalikDestekIzni - _kullanilanDestek}/$_haftalikDestekIzni',
                                      style: TextStyle(
                                        color:
                                            _kullanilanDestek >=
                                                _haftalikDestekIzni
                                            ? theme.error
                                            : theme.secondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Sosyal Akış (Gönderiler)
                          if (_gonderiler.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 48,
                                  horizontal: 32,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.article_outlined,
                                      size: 64,
                                      color: theme.textMuted.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Henüz gönderi yok',
                                      style: TextStyle(
                                        color: theme.textMuted,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Topluluklar paylaşım yaptığında burada görünecek.',
                                      style: TextStyle(
                                        color: theme.textMuted.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                return PostCard(
                                  post: _gonderiler[index],
                                  onSupportTap: (post) =>
                                      _handleSupportTap(post),
                                  onRatingChanged: _handleRatingChanged,
                                  onReport: _handleReport,
                                );
                              }, childCount: _gonderiler.length),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        ],
                      ),
                    ),
            ),
          ), // closes AnimatedThemeBackground (body)
        ); // closes Scaffold
      },
    );
  }
}

// ── Yaklaşan Etkinlikler Bölümü ──────────────────────────────────────────────

class _UpcomingEventsSection extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final AppTheme theme;

  const _UpcomingEventsSection({required this.events, required this.theme});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(w * 0.04, 16, w * 0.04, 10),
          child: const Text(
            'Yaklaşan Etkinlikler 📅',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 148,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: w * 0.04),
            itemCount: events.length,
            itemBuilder: (context, index) => _EventCard(
              event: events[index],
              theme: theme,
              isLast: index == events.length - 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final AppTheme theme;
  final bool isLast;

  const _EventCard({
    required this.event,
    required this.theme,
    this.isLast = false,
  });

  String _formatDate(String raw) {
    try {
      final d = DateTime.parse(raw).toLocal();
      const months = [
        'Oca',
        'Şub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Ağu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara',
      ];
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${months[d.month - 1]} · $h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = event['title'] as String? ?? '';
    final imageUrl = event['image_url'] as String?;
    final location = event['location'] as String?;
    final eventDate = event['event_date'] as String? ?? '';
    final community = event['communities'] as Map?;
    final communityName = community?['name'] as String? ?? '';

    return Container(
      width: 180,
      margin: EdgeInsets.only(right: isLast ? 0 : 12),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Görsel veya placeholder
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 64,
              width: double.infinity,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? AppNetworkImage(
                      path: imageUrl,
                      fit: BoxFit.cover,
                      fallback: _placeholder,
                    )
                  : _placeholder(),
            ),
          ),
          // Bilgi
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (communityName.isNotEmpty)
                    Text(
                      communityName,
                      style: TextStyle(
                        color: theme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (eventDate.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 10, color: theme.warning),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _formatDate(eventDate),
                            style: TextStyle(
                              color: theme.warning,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (location != null && location.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 10,
                          color: theme.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: theme.warning.withValues(alpha: 0.12),
      child: Center(
        child: Icon(Icons.event_rounded, color: theme.warning, size: 28),
      ),
    );
  }
}
