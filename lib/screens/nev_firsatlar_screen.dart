import 'package:flutter/material.dart';
import '../models/discount_model.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../utils/secure_screen.dart';
import '../widgets/animated_theme_background.dart';
import '../widgets/discount_carousel.dart';

/// Nev Plus içine taşınan "Nev Fırsatlar" bölümü.
/// Önceden anasayfada gösterilen kupon/indirim akışı — veri kaynağı ve
/// işlevsellik (konum tabanlı kupon açma) değişmeden buraya taşındı.
class NevFirsatlarScreen extends StatefulWidget {
  const NevFirsatlarScreen({super.key});

  @override
  State<NevFirsatlarScreen> createState() => _NevFirsatlarScreenState();
}

class _NevFirsatlarScreenState extends State<NevFirsatlarScreen> {
  final SupabaseDataService _dataService = SupabaseDataService();
  List<DiscountModel> _kuponlar = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Kupon kodları görev değiştirici önizlemesinde/ekran görüntüsünde
    // görünmesin (bkz. kontrol.md Bölüm 7 — FLAG_SECURE).
    SecureScreen.enable();
    _loadData();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }

  Future<void> _loadData() async {
    final cached = _dataService.getCachedKuponlar();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _kuponlar = cached;
        _isLoading = false;
      });
    }
    try {
      final fresh = await _dataService.getKuponlar();
      if (!mounted) return;
      setState(() {
        _kuponlar = fresh;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Geri',
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department_rounded, color: theme.primary),
                const SizedBox(width: 8),
                Text(
                  'Nev Fırsatlar',
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          body: AnimatedThemeBackground(
            child: SafeArea(
              child: RefreshIndicator(
                color: theme.primary,
                backgroundColor: theme.surface,
                onRefresh: _loadData,
                child: _isLoading && _kuponlar.isEmpty
                    ? Center(child: CircularProgressIndicator(color: theme.primary))
                    : ListView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        children: [
                          const SizedBox(height: 8),
                          if (_kuponlar.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 64,
                                horizontal: 32,
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.local_offer_outlined,
                                    size: 56,
                                    color: theme.textMuted.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Şu anda aktif bir fırsat bulunmuyor.',
                                    style: TextStyle(color: theme.textMuted),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            DiscountCarousel(kuponlar: _kuponlar),
                          const SizedBox(height: 32),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
