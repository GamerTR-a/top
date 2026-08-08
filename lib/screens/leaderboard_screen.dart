import 'package:flutter/material.dart';
import '../models/leaderboard_model.dart';
import '../services/supabase_data_service.dart';
import '../widgets/podium_card.dart';
import '../widgets/ranking_item.dart';
import '../widgets/animated_theme_background.dart';
import '../theme/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _listAnimController;
  List<CurvedAnimation> _itemAnims = [];
  final SupabaseDataService _dataService = SupabaseDataService();
  LeaderboardData? _leaderboardData;
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listAnimController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _loadData();
  }

  void _buildItemAnims(int count) {
    for (final anim in _itemAnims) {
      anim.dispose();
    }
    _itemAnims = List.generate(
      count,
      (i) => CurvedAnimation(
        parent: _listAnimController,
        curve: Interval(
          (i * 0.05).clamp(0.0, 0.7),
          ((i * 0.05) + 0.3).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final data = await _dataService.getLeaderboardData();
      if (!mounted) return;
      final maxItems = [
        data.topluluklar.length - 3,
        data.uyeler.length - 3,
      ].fold(0, (a, b) => a > b ? a : b).clamp(0, 30);
      setState(() {
        _leaderboardData = data;
        _isLoading = false;
      });
      _buildItemAnims(maxItems);
      _listAnimController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = 'Veriler yüklenemedi. Tekrar deneyin.';
      });
    }
  }

  @override
  void dispose() {
    for (final anim in _itemAnims) {
      anim.dispose();
    }
    _tabController.dispose();
    _listAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            title: Text(
              'Öne Çıkanlar ✨',
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.textColor),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: theme.primary,
              indicatorWeight: 3,
              labelColor: theme.primary,
              unselectedLabelColor: theme.textMuted,
              tabs: const [
                Tab(text: 'Topluluklar'),
                Tab(text: 'Üyeler'),
              ],
            ),
          ),
          body: AnimatedThemeBackground(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.primary))
                : _errorMsg != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 56,
                            color: theme.error.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMsg!,
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 14,
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
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLeaderboardTab(
                        _leaderboardData?.topluluklar ?? [],
                        theme,
                      ),
                      _buildLeaderboardTab(
                        _leaderboardData?.uyeler ?? [],
                        theme,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardTab(List<RankingModel> items, AppTheme theme) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 56,
              color: theme.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Henüz veri yok',
              style: TextStyle(color: theme.textMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final top3 = items.take(3).toList();
    final remaining = items.skip(3).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Podyum Kısmı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2. Sıra — Gümüş
                if (top3.length > 1)
                  PodiumCard(
                    rank: top3[1],
                    height: 100,
                    color: const Color(0xFFB0BEC5),
                    crown: '🥈',
                  ),
                // 1. Sıra — Altın
                if (top3.isNotEmpty)
                  PodiumCard(
                    rank: top3[0],
                    height: 140,
                    color: const Color(0xFFFFD700),
                    crown: '👑',
                  ),
                // 3. Sıra — Bronz
                if (top3.length > 2)
                  PodiumCard(
                    rank: top3[2],
                    height: 80,
                    color: const Color(0xFFCD7F32),
                    crown: '🥉',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Geri Kalan Liste
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: remaining.length,
              itemBuilder: (context, index) {
                final anim = index < _itemAnims.length
                    ? _itemAnims[index]
                    : _listAnimController;
                return AnimatedBuilder(
                  animation: anim,
                  builder: (context, child) => Opacity(
                    opacity: anim.value,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - anim.value)),
                      child: child,
                    ),
                  ),
                  child: RankingItem(rank: remaining[index], index: index + 4),
                );
              },
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
