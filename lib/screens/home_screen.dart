import 'dart:async';
import 'package:flutter/material.dart';
import '../models/auth_user_model.dart';
import '../models/news_model.dart';
import '../models/post_model.dart';
import '../services/supabase_data_service.dart';
import '../services/socket_service.dart';
import '../services/block_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/category_button.dart';
import '../widgets/news_bulletin_carousel.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/app_network_image.dart';
import '../theme/app_theme.dart';
import 'notification_center_screen.dart';
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
  List<PostModel> _gonderiler = [];
  List<Map<String, dynamic>> _etkinlikler = [];
  List<NewsModel> _haberler = [];

  static const int _haftalikDestekIzni = 2;
  static const int _postsPerPage = 15;
  int _kullanilanDestek = 0;
  Set<int> _supportedPostIds = {};
  Map<int, int> _myRatings = {};
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  // Sonsuz kaydırma (bkz. kontrol.md Bölüm 16.13 — servis sayfalamayı zaten
  // destekliyordu ama bu ekran hep yalnızca ilk 15 gönderiyi gösteriyordu).
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  bool _hasMorePosts = true;
  bool _loadingMore = false;

  int _unreadNotifCount = 0;

  // Görev 8: Akış (kronolojik) / Konuya göre (kategori) görünümü.
  bool _byCategory = false;
  String? _selectedCategory;

  /// Gönderilerde fiilen bulunan kategoriler — topluluklar tablosundaki
  /// `category` sütunundan gelir (bkz. topluluk.md seed script'i).
  List<String> get _availableCategories {
    final set = <String>{};
    for (final p in _gonderiler) {
      if (p.kategori.isNotEmpty) set.add(p.kategori);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<PostModel> get _visiblePosts {
    final blocks = BlockService.instance;
    final posts = blocks.hasBlocks
        ? _gonderiler.where((p) => !blocks.isBlocked(p)).toList()
        : _gonderiler;
    if (!_byCategory || _selectedCategory == null) return posts;
    return posts.where((p) => p.kategori == _selectedCategory).toList();
  }

  void _onBlocksChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToSocket();
    _loadUnreadCount();
    _scrollController.addListener(_onScroll);
    BlockService.instance.changes.addListener(_onBlocksChanged);
    BlockService.instance.filter(const []).then((_) => _onBlocksChanged());
  }

  void _onScroll() {
    if (!_hasMorePosts || _loadingMore || _byCategory) return;
    // Sona yaklaşınca (son 300px) bir sonraki sayfayı yükle.
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    _loadingMore = true;
    try {
      final nextPage = _page + 1;
      final more = await _dataService.getGonderiler(
        page: nextPage,
        limit: _postsPerPage,
      );
      if (!mounted) return;
      final enriched = more
          .map(
            (p) => p.copyWith(
              isSupportedByMe: _supportedPostIds.contains(p.id),
              myRating: _myRatings[p.id],
            ),
          )
          .toList();
      setState(() {
        _gonderiler = [..._gonderiler, ...enriched];
        _page = nextPage;
        _hasMorePosts = more.length >= _postsPerPage;
      });
    } catch (e) {
      debugPrint('[Home] Sonraki sayfa yüklenemedi: $e');
      // Sessizce başarısız olur — kullanıcı scroll'a devam ederse tekrar denenir.
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _loadUnreadCount() async {
    final uid = widget.currentUser?.id;
    if (uid == null) return;
    final count = await _dataService.getUnreadNotificationCount(uid);
    if (mounted) setState(() => _unreadNotifCount = count);
  }

  Future<void> _openNotificationCenter() async {
    final user = widget.currentUser;
    if (user == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(currentUser: user),
      ),
    );
    // Bildirim merkezinde okundu işaretlenmiş olabilir — rozeti güncelle.
    _loadUnreadCount();
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
    BlockService.instance.changes.removeListener(_onBlocksChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    final etkinlikler = _dataService.getCachedUpcomingEvents();
    final haberler = _dataService.getCachedNews();
    if (posts.isEmpty && etkinlikler.isEmpty && haberler.isEmpty) {
      return false;
    }
    if (!mounted) return false;
    setState(() {
      if (posts.isNotEmpty) _gonderiler = posts;
      if (etkinlikler.isNotEmpty) _etkinlikler = etkinlikler;
      if (haberler.isNotEmpty) _haberler = haberler;
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
        // Ana içerik akışı — geçici bir ağ hatasında hemen "yüklenemedi"
        // göstermek yerine üstel geri çekilmeyle 3 kez denenir (bkz.
        // kontrol.md Bölüm 16.4/16.6).
        retryWithBackoff(
          () => _dataService.getGonderiler(page: 1, limit: _postsPerPage),
        ),
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
        _dataService.getNews().catchError((e) {
          debugPrint('[Home] Haberler alınamadı: $e');
          return <NewsModel>[];
        }),
      ]);
      final posts = results[0] as List<PostModel>;
      final myRatings = results[3] as Map<int, int>;
      final statusData = results[1] as Map<String, dynamic>;
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
        _gonderiler = updatedPosts;
        _etkinlikler = results[2] as List<Map<String, dynamic>>;
        _haberler = results[4] as List<NewsModel>;
        _kullanilanDestek = used;
        _supportedPostIds = supported;
        _myRatings = myRatings;
        _page = 1;
        _hasMorePosts = posts.length >= _postsPerPage;
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
            _showNotification(
              '10 XP Kazandın! 🎮 ${post.toplulukAdi} gönderisini değerlendirdin.',
              isError: false,
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
        title: Text(
          'Gönderiyi Şikayet Et 🚩',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLength: 300,
          maxLines: 3,
          style: TextStyle(color: theme.textColor, fontSize: 14),
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

  Future<void> _handleBlock(PostModel post) async {
    final theme = themeNotifier.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${post.toplulukAdi} engellensin mi?',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bu topluluğun ve gönderi sahibinin paylaşımları akışında artık '
          'görünmeyecek. Durum ekibimize de bildirilir. Engeli daha sonra '
          'menüdeki "Engellenenleri Kaldır" ile kaldırabilirsin.',
          style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.4),
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
            child: const Text('Engelle'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await BlockService.instance.blockPostSource(post);
    if (mounted) _showNotification('${post.toplulukAdi} engellendi.');
    // Moderasyon ekibinin haberdar olması için arka planda şikayet kaydı.
    unawaited(
      _dataService
          .reportPost(post.id, reason: 'Kullanıcı bu kaynağı engelledi.')
          .catchError((e) => debugPrint('[Home] Engel bildirimi gönderilemedi: $e')),
    );
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

  /// Görev 8: "Akış" (kronolojik, filtresiz) / "Konuya göre" (kategori
  /// çipleriyle filtreli) geçişi. Kategoriler `communities.category`
  /// sütunundan gelir — bkz. topluluk.md seed script'i.
  Widget _buildFeedFilterBar(AppTheme theme) {
    final w = MediaQuery.of(context).size.width;
    final categories = _availableCategories;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _FeedModeTab(
                  label: 'Akış',
                  isActive: !_byCategory,
                  theme: theme,
                  onTap: () => setState(() => _byCategory = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FeedModeTab(
                  label: 'Konuya Göre',
                  isActive: _byCategory,
                  theme: theme,
                  onTap: () => setState(() => _byCategory = true),
                ),
              ),
            ],
          ),
          if (_byCategory) ...[
            const SizedBox(height: 10),
            if (categories.isEmpty)
              Text(
                'Kategorili gönderi bulunamadı.',
                style: TextStyle(color: theme.textMuted, fontSize: 12),
              )
            else
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    CategoryButton(
                      title: 'Tümü',
                      isSelected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    for (final c in categories)
                      CategoryButton(
                        title: c,
                        isSelected: _selectedCategory == c,
                        onTap: () => setState(() => _selectedCategory = c),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
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
                      itemBuilder: (context, index) => const PostCardSkeleton(),
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
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          if (_haberler.isNotEmpty)
                            SliverToBoxAdapter(
                              child: NewsBulletinCarousel(news: _haberler),
                            ),
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
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      IconButton(
                                        onPressed: _openNotificationCenter,
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
                                      if (_unreadNotifCount > 0)
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: theme.error,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '$_unreadNotifCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
                          SliverToBoxAdapter(
                            child: _buildFeedFilterBar(theme),
                          ),
                          // Sosyal Akış (Gönderiler)
                          if (_visiblePosts.isEmpty && _byCategory)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                  horizontal: 32,
                                ),
                                child: Center(
                                  child: Text(
                                    'Bu kategoride henüz gönderi yok.',
                                    style: TextStyle(
                                      color: theme.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (_gonderiler.isEmpty)
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
                                final post = _visiblePosts[index];
                                return PostCard(
                                  key: ValueKey(post.id),
                                  post: post,
                                  onSupportTap: (post) =>
                                      _handleSupportTap(post),
                                  onRatingChanged: _handleRatingChanged,
                                  onReport: _handleReport,
                                  onBlock: _handleBlock,
                                );
                              }, childCount: _visiblePosts.length),
                            ),
                          if (!_byCategory && _hasMorePosts)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.primary.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ),
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

// ── Akış / Konuya Göre Sekme Butonu ─────────────────────────────────────────

class _FeedModeTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final AppTheme theme;
  final VoidCallback onTap;

  const _FeedModeTab({
    required this.label,
    required this.isActive,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? theme.primary
              : (theme.isDark
                  ? theme.surface.withValues(alpha: 0.5)
                  : theme.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? theme.primary
                : (theme.isDark
                    ? theme.textMuted.withValues(alpha: 0.25)
                    : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : theme.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
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
          child: Text(
            'Yaklaşan Etkinlikler 📅',
            style: TextStyle(
              color: theme.textColor,
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
                    style: TextStyle(
                      color: theme.textColor,
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
