import 'dart:async';
import 'package:flutter/material.dart';
import '../models/topluluk.dart';
import '../services/supabase_data_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_theme_background.dart';
import '../theme/app_theme.dart';

class CommunityMazeScreen extends StatefulWidget {
  const CommunityMazeScreen({super.key});

  @override
  State<CommunityMazeScreen> createState() => _CommunityMazeScreenState();
}

class _CommunityMazeScreenState extends State<CommunityMazeScreen> {
  final SupabaseDataService _dataService = SupabaseDataService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  late Future<List<Topluluk>> _topluluklarFuture;
  String? _selectedKategori;

  /// Filtre çipleri için tüm kategoriler — bir kategori seçilse bile liste
  /// daralmasın diye filtresiz, ayrıca yüklenir.
  List<String> _kategoriler = [];

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _topluluklarFuture = _dataService.getTopluluklar(
            search: _searchCtrl.text.trim().isEmpty
                ? null
                : _searchCtrl.text.trim(),
            category: _selectedKategori,
          );
        });
      }
    });
  }

  void _onCategoryChanged(String? kategori) {
    setState(() {
      _selectedKategori = kategori;
      _topluluklarFuture = _dataService.getTopluluklar(
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
        category: kategori,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    // Önbellekten anında göster, arka planda tazele.
    final cached = _dataService.getCachedTopluluklar();
    if (cached.isNotEmpty) {
      _topluluklarFuture = Future.value(cached);
      unawaited(_refreshTopluluklar());
    } else {
      _topluluklarFuture = _dataService.getTopluluklar();
    }
    _searchCtrl.addListener(_onSearchChanged);
    _loadKategoriler();
  }

  Future<void> _loadKategoriler() async {
    try {
      final all = await _dataService.getTopluluklar();
      if (!mounted) return;
      setState(() {
        _kategoriler = all
            .map((t) => t.kategori)
            .where((k) => k.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      });
    } catch (_) {}
  }

  Future<void> _refreshTopluluklar() async {
    try {
      final fresh = await _dataService.getTopluluklar();
      if (mounted) setState(() => _topluluklarFuture = Future.value(fresh));
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  // Server zaten filtrelenmiş sonuç döndürüyor; local filtre yalnızca anlık UI senkronizasyonu için
  List<Topluluk> _filter(List<Topluluk> all) => all;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return AnimatedThemeBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.05,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Topluluklar',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'İlgi alanına göre toplulukları keşfet, etkinliklere katıl!',
                        style: TextStyle(
                          color: theme.textMuted.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Gerçek arama çubuğu
                      Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: theme.isDark
                              ? theme.surface.withValues(alpha: 0.6)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.isDark
                                ? theme.primary.withValues(alpha: 0.3)
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: theme.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Topluluk ara...',
                                  hintStyle: TextStyle(
                                    color: theme.textMuted.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_searchCtrl.text.isNotEmpty)
                              GestureDetector(
                                onTap: () => _searchCtrl.clear(),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: theme.textMuted,
                                  size: 18,
                                ),
                              )
                            else
                              Icon(
                                Icons.tune_rounded,
                                color: theme.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Kategori filtre çipleri — sıralama (en başarılı/aktif/yeni/popüler)
                // yerine kategorilere göre sınıflandırma öne çıkar. "Tümü" filtreyi sıfırlar.
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildChip('Tümü', null, theme),
                      if (_kategoriler.isNotEmpty)
                        ..._kategoriler.map((k) => _buildChip(k, k, theme)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Grid View
                Expanded(
                  child: FutureBuilder<List<Topluluk>>(
                    future: _topluluklarFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: theme.primary,
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: theme.error.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Topluluklar yüklenemedi',
                                style: TextStyle(color: theme.textMuted),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => setState(() {
                                  _topluluklarFuture =
                                      _dataService.getTopluluklar();
                                }),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tekrar Dene'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final tumTopuluklar = snapshot.data ?? [];
                      final filtered = _filter(tumTopuluklar);
                      final crossAxisCount = 3;
                      final gridSpacing = 10.0;

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            'Topluluk bulunamadı',
                            style: TextStyle(color: theme.textMuted),
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: theme.primary,
                        backgroundColor: theme.surface,
                        onRefresh: () async {
                          setState(() {
                            _topluluklarFuture = _dataService.getTopluluklar(
                              search: _searchCtrl.text.trim().isEmpty
                                  ? null
                                  : _searchCtrl.text.trim(),
                              category: _selectedKategori,
                            );
                          });
                          await _topluluklarFuture;
                        },
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: gridSpacing,
                            mainAxisSpacing: gridSpacing,
                            childAspectRatio: 0.56,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) =>
                              GlassCard(topluluk: filtered[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip(String label, String? kategori, AppTheme theme) {
    final isSelected = _selectedKategori == kategori;
    return GestureDetector(
      onTap: () => _onCategoryChanged(kategori),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primary.withValues(alpha: 0.25)
              : theme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.primary
                : theme.primary.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.primary : theme.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
