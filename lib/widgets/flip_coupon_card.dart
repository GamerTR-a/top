import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';
import '../models/discount_model.dart';
import '../services/location_service.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';

/// Konum tabanlı, 3D flip (arkaya dönme) animasyonlu ve çevrimdışı doğrulanabilir
/// kupon kartı bileşeni.
class FlipCouponCard extends StatefulWidget {
  final DiscountModel kupon;
  final int index;
  final double cardWidth;
  final double cardHeight;
  final AppTheme theme;
  final EdgeInsetsGeometry margin;
  final Function(DiscountModel updatedKupon)? onKuponUpdated;

  const FlipCouponCard({
    super.key,
    required this.kupon,
    required this.index,
    required this.cardWidth,
    required this.cardHeight,
    required this.theme,
    this.onKuponUpdated,
    this.margin = const EdgeInsets.only(right: 12.0),
  });

  @override
  State<FlipCouponCard> createState() => _FlipCouponCardState();
}

class _FlipCouponCardState extends State<FlipCouponCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isBackVisible = false;

  // Hak etme (Claim) Durumları
  bool _isLoadingLocation = false;
  String? _unlockedCode;
  String? _errorMessage;
  double? _userDistanceMeters;
  bool _isClaimed = false;

  final SupabaseDataService _dataService = SupabaseDataService();

  @override
  void initState() {
    super.initState();
    _unlockedCode = widget.kupon.claimedCode;
    _isClaimed = widget.kupon.isClaimed;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    )..addListener(() {
        setState(() {
          _isBackVisible = _animation.value >= (math.pi / 2);
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_controller.isAnimating) return;

    if (_controller.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
      // Arkaya dönerken henüz alınmamışsa konum kontrolü ve claim yap
      if (!_isClaimed && _unlockedCode == null && !_isLoadingLocation) {
        _checkLocationAndClaim();
      }
    }
  }

  Future<void> _checkLocationAndClaim() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      // 0. Sahte konum (mock location) uygulaması kontrolü — GPS spoofing ile
      // uzaktan kupon açma girişimlerine karşı istemci tarafı ek bir bariyer
      // (sunucu tarafındaki gerçek mesafe kontrolüne ek olarak; bkz. kontrol.md
      // Bölüm 9.6/9.7). Kontrol başarısız olursa (paket hatası vb.) sessizce
      // devam edilir — asıl güvenlik sunucu tarafında zaten sağlanıyor.
      final mockLocation = await SafeDevice.isMockLocation;
      if (mockLocation) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _errorMessage =
                'Sahte konum (mock location) uygulaması tespit edildi. '
                'Kupon almak için lütfen gerçek konumunuzu kullanın.';
          });
        }
        return;
      }

      // 1. Konum al
      final position = await LocationService.getCurrentPosition();

      // 2. Client-side mesafe hesabı (Önbilgi için)
      final distance = LocationService.distanceMeters(
        position.latitude,
        position.longitude,
        widget.kupon.latitude,
        widget.kupon.longitude,
      );

      _userDistanceMeters = distance;

      // 3. Supabase RPC claim_coupon çağrısı — mesafe/geofence kontrolü ve
      // kod üretimi sunucuda yapılır, istemci yalnızca konumu gönderir.
      final result = await _dataService.claimCoupon(
        discountId: widget.kupon.id,
        userLat: position.latitude,
        userLng: position.longitude,
      );

      if (mounted) {
        if (result['success'] == true) {
          final code = result['code'] as String;
          setState(() {
            _unlockedCode = code;
            _isClaimed = true;
            _isLoadingLocation = false;
          });

          // Model güncellemesini bildir
          final updated = widget.kupon.copyWith(
            claimedCode: code,
            claimedAt: DateTime.now(),
          );
          widget.onKuponUpdated?.call(updated);

          // Hafif titreşim dokunsal geri bildirim
          HapticFeedback.heavyImpact();
        } else {
          setState(() {
            _errorMessage = result['message'] as String? ??
                'Konum doğrulaması başarısız oldu.';
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'GPS konumu alınamadı. Lütfen konum servislerini açın.';
          _isLoadingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGreen = widget.index % 2 == 1;

    final primaryColor = isGreen
        ? const Color(0xFF0F9D58)
        : const Color(0xFF00ACC1);

    return Container(
      width: widget.cardWidth,
      height: widget.cardHeight,
      margin: widget.margin,
      child: GestureDetector(
        onDoubleTap: _flipCard,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 3D perspektif derinliği
              ..rotateY(_animation.value);

            return Transform(
              transform: transform,
              alignment: Alignment.center,
              child: _isBackVisible
                  ? Transform(
                      transform: Matrix4.identity()..rotateY(math.pi),
                      alignment: Alignment.center,
                      child: _buildBackSide(primaryColor, isGreen),
                    )
                  : _buildFrontSide(primaryColor, isGreen),
            );
          },
        ),
      ),
    );
  }

  // ── ÖN YÜZ (Front Side) ──────────────────────────────────────────────────
  Widget _buildFrontSide(Color primaryColor, bool isGreen) {
    final theme = widget.theme;
    final List<Color> lightGradient = isGreen
        ? const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]
        : const [Color(0xFFE0F7FA), Color(0xFFB2EBF2)];

    final List<Color> darkGradient = isGreen
        ? const [Color(0xFF064E3B), Color(0xFF047857)]
        : const [Color(0xFF083344), Color(0xFF164E63)];

    final displayDiscountText = widget.kupon.indirimOrani.contains('İndirim')
        ? widget.kupon.indirimOrani
        : '${widget.kupon.indirimOrani} İndirim';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.isDark ? darkGradient : lightGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isClaimed
              ? Colors.amber.withValues(alpha: 0.8)
              : (theme.isDark
                  ? primaryColor.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.8)),
          width: _isClaimed ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isClaimed
                ? Colors.amber.withValues(alpha: 0.25)
                : primaryColor.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst İkon & Durum Rozeti
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isGreen ? Colors.white : primaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isClaimed
                          ? Icons.lock_open_rounded
                          : Icons.sell_rounded,
                      color: _isClaimed
                          ? const Color(0xFFD97706)
                          : (isGreen ? primaryColor : Colors.white),
                      size: 18,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isClaimed
                        ? Colors.amber.withValues(alpha: 0.2)
                        : primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isClaimed ? Icons.check_circle : Icons.touch_app,
                        size: 11,
                        color: _isClaimed ? Colors.amber[800] : primaryColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _isClaimed ? 'Açıldı' : 'Çift Tıkla',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _isClaimed ? Colors.amber[800] : primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Şirket Adı & Kupon Başlığı
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.kupon.sirketAd,
                    style: TextStyle(
                      color: theme.isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.kupon.kuponAdi,
                    style: TextStyle(
                      color: theme.isDark
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFF0F172A),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Alt İndirim Rozeti
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  displayDiscountText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ARKA YÜZ (Back Side - Locked / Unlocked State) ───────────────────────
  Widget _buildBackSide(Color primaryColor, bool isGreen) {
    final theme = widget.theme;

    final backBg = theme.isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    return Container(
      decoration: BoxDecoration(
        color: backBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isClaimed
              ? const Color(0xFF10B981)
              : (_errorMessage != null
                  ? Colors.redAccent
                  : primaryColor.withValues(alpha: 0.5)),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _isClaimed
                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoadingLocation) ...[
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Konum Kontrol Ediliyor...',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            const Text(
              '50m geofence doğrulanıyor',
              style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
            ),
          ] else if (_isClaimed && _unlockedCode != null) ...[
            // ── KİLİT AÇILDI / KOD TESLİM EDİLDİ ──
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: Color(0xFF059669),
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'KUPON KODUNUZ',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 4),
            // Büyük Kod Gösterimi (Örn: AB12X34)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _unlockedCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kod kopyalandı: $_unlockedCode'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFF059669),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _unlockedCode!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: theme.isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.copy_rounded,
                      size: 13,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Kasada bu kodu gösterin.\nİşletme listeden üstünü çizer.',
              style: TextStyle(
                fontSize: 9,
                color: theme.isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            // ── MESAFE UYARISI / HATA DURUMU ──
            const Icon(
              Icons.location_off_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              _errorMessage ?? 'Konum doğrulanamadı',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.isDark
                    ? const Color(0xFFF8FAFC)
                    : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (_userDistanceMeters != null) ...[
              const SizedBox(height: 2),
              Text(
                'Mevcut Mesafe: ${_userDistanceMeters!.toStringAsFixed(0)}m (Sınır: 50m)',
                style: const TextStyle(fontSize: 8, color: Colors.redAccent),
              ),
            ],

            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: _checkLocationAndClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Tekrar Dene',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
