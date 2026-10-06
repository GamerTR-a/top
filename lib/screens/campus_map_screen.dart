import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/campus_poi.dart';
import '../utils/turkish_text.dart';
import '../services/campus_poi_data.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';
import 'qibla_compass_screen.dart';

enum _GateStatus {
  loading,
  permissionDenied,
  deniedForever,
  noGps,
  ready,
}

/// Kampüs Cepte — gerçek harita (OSM) + Sakarya geofence + POI katmanları.
class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen>
    with WidgetsBindingObserver {
  _GateStatus _status = _GateStatus.loading;
  Position? _position;
  String? _adminArea;
  double _distanceToCampus = 0;
  // Sakarya dışındaki kullanıcı (ör. App Review) haritayı yine görebilmeli —
  // kilit yerine kapatılabilir bir bilgi bandı gösterilir.
  bool _isOutsideSakarya = false;
  bool _outsideBannerDismissed = false;

  final TextEditingController _searchCtrl = TextEditingController();
  final MapController _mapController = MapController();
  bool _mapReady = false;

  List<CampusPoi> _allPois = [];
  bool _poisLoading = true;
  PoiCategory? _activeCategory;
  CampusPoi? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPois();
    _initLocation();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı izni Ayarlar'dan değiştirip uygulamaya geri dönmüş olabilir —
    // yalnızca izin sorunlu bir durumdaysak (ret/kalıcı ret) yeniden kontrol
    // ediyoruz, zaten hazırsa (ready) gereksiz yeniden sorgu yapmıyoruz
    // (bkz. kontrol.md Bölüm 15.8 / 28.4).
    if (state == AppLifecycleState.resumed &&
        (_status == _GateStatus.permissionDenied ||
            _status == _GateStatus.deniedForever)) {
      _initLocation();
    }
  }

  Future<void> _showLocationRationale() async {
    final theme = themeNotifier.value;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.location_on_rounded, color: theme.primary),
            const SizedBox(width: 10),
            Text('Konum İzni', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Kampüs haritasında bulunduğun konumu gösterebilmek ve kıble yönünü '
          'hesaplayabilmek için konumuna ihtiyacımız var. Konumun yalnızca '
          'cihazında işlenir, sunucuya gönderilmez.',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: Colors.white),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPois() async {
    final pois = await CampusPoiData.load();
    if (!mounted) return;
    setState(() {
      _allPois = pois;
      _poisLoading = false;
    });
  }

  Future<void> _initLocation() async {
    setState(() => _status = _GateStatus.loading);

    // Apple/Google rehberlerine uygun: sistem izin penceresi açılmadan önce
    // konumun ne için istendiğini açıklayan bir rationale diyaloğu göster
    // (yalnızca izin henüz hiç sorulmamışsa/daha önce reddedilmişse).
    final currentPermission = await Geolocator.checkPermission();
    if (mounted &&
        (currentPermission == LocationPermission.denied)) {
      await _showLocationRationale();
    }

    final permission = await LocationService.requestLocationPermission();
    if (!mounted) return;
    if (permission == LocationPermission.denied) {
      setState(() => _status = _GateStatus.permissionDenied);
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _status = _GateStatus.deniedForever);
      return;
    }
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      // Haritayı konum alınır alınmaz göster — OSM tile'ları yüklenmeye başlar.
      // Geofence kararı arka planda tek jeokodlama ile gelir (çift geocode yok);
      // kullanıcı Sakarya dışındaysa harita kampüs merkezinde kalır ve bilgi
      // bandı gösterilir.
      setState(() {
        _position = pos;
        _isOutsideSakarya = false;
        _status = _GateStatus.ready;
      });
      final check = await LocationService.sakaryaCheck(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      if (!check.inSakarya) {
        setState(() {
          _adminArea = check.placemark?.administrativeArea;
          _distanceToCampus = LocationService.distanceToCampusKm(
            pos.latitude,
            pos.longitude,
          );
          _isOutsideSakarya = true;
          _outsideBannerDismissed = false;
        });
        if (_mapReady) {
          _mapController.move(LocationService.campusCenter, 15.5);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _GateStatus.noGps);
    }
  }

  /// Konum olmadan haritayı kampüs merkezinde açar (izin reddi / GPS yok).
  void _browseWithoutLocation() {
    setState(() {
      _position = null;
      _isOutsideSakarya = false;
      _status = _GateStatus.ready;
    });
  }

  // ------------------------------------------------------------------
  // Filtreleme
  // ------------------------------------------------------------------

  bool _categoryMatches(CampusPoi p) {
    final c = _activeCategory;
    // 'Tümü': yüzlerce yol parçası haritayı okunmaz kıldığı için rotalar
    // yalnızca kendi filtreleri seçiliyken çizilir.
    if (c == null) return !p.category.isRouteCategory;
    return p.category == c;
  }

  List<CampusPoi> get _visiblePois {
    final q = turkishToLower(_searchCtrl.text.trim());
    return _allPois.where((p) {
      if (!_categoryMatches(p)) return false;
      if (q.isNotEmpty) {
        final hay = turkishToLower('${p.name} ${p.description} ${p.address}');
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Color _categoryColor(PoiCategory c) => switch (c) {
        PoiCategory.dormitory => const Color(0xFF6366F1),
        PoiCategory.busStop => const Color(0xFFFB8C00),
        PoiCategory.faculty => const Color(0xFF1E88E5),
        PoiCategory.study => const Color(0xFFF9A825),
        PoiCategory.wifi => const Color(0xFF00ACC1),
        PoiCategory.food => const Color(0xFFE64A19),
        PoiCategory.market => const Color(0xFF8E24AA),
        PoiCategory.health => const Color(0xFFE53935),
        PoiCategory.sport => const Color(0xFF00897B),
        PoiCategory.park => const Color(0xFF43A047),
        PoiCategory.worship => const Color(0xFF5D4037),
        PoiCategory.finance => const Color(0xFF546E7A),
        PoiCategory.culture => const Color(0xFFD81B60),
        PoiCategory.walkingRoute => const Color(0xFF2E7D32),
        PoiCategory.bikeRoute => const Color(0xFF00838F),
      };

  IconData _categoryIcon(PoiCategory c) => switch (c) {
        PoiCategory.dormitory => Icons.apartment_rounded,
        PoiCategory.busStop => Icons.directions_bus_rounded,
        PoiCategory.faculty => Icons.school_rounded,
        PoiCategory.study => Icons.menu_book_rounded,
        PoiCategory.wifi => Icons.wifi_rounded,
        PoiCategory.food => Icons.restaurant_rounded,
        PoiCategory.market => Icons.shopping_basket_rounded,
        PoiCategory.health => Icons.local_pharmacy_rounded,
        PoiCategory.sport => Icons.sports_soccer_rounded,
        PoiCategory.park => Icons.park_rounded,
        PoiCategory.worship => Icons.mosque_rounded,
        PoiCategory.finance => Icons.atm_rounded,
        PoiCategory.culture => Icons.theater_comedy_rounded,
        PoiCategory.walkingRoute => Icons.directions_walk_rounded,
        PoiCategory.bikeRoute => Icons.directions_bike_rounded,
      };

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

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
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: theme.textColor),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Geri',
            ),
            title: Text(
              'Kampüs Cepte 🗺️',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Kıble Pusulası',
                icon: Icon(Icons.explore_rounded, color: theme.primary),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QiblaCompassScreen(),
                  ),
                ),
              ),
            ],
          ),
          body: AnimatedThemeBackground(
            child: SafeArea(
              child: _status == _GateStatus.ready
                  ? _buildMap(theme)
                  : _buildStatusScreen(theme),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Durum ekranları (gate / kilit)
  // ------------------------------------------------------------------

  Widget _buildStatusScreen(AppTheme theme) {
    switch (_status) {
      case _GateStatus.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Konumunuz alınıyor...',
                  style: TextStyle(color: theme.textMuted)),
            ],
          ),
        );
      case _GateStatus.permissionDenied:
        return _buildGate(
          theme,
          icon: Icons.location_off_rounded,
          accent: theme.error,
          title: 'Konum izni gerekli',
          subtitle: 'Kampüs haritası için konum izninize ihtiyacımız var.',
          buttonLabel: 'İzin Ver',
          onPressed: _initLocation,
          secondaryLabel: 'Haritayı konumsuz göster',
          onSecondary: _browseWithoutLocation,
        );
      case _GateStatus.deniedForever:
        return _buildGate(
          theme,
          icon: Icons.location_off_rounded,
          accent: theme.error,
          title: 'Konum izni kapalı',
          subtitle:
              'Ayarlardan konum iznini açmalısınız, sonra geri gelip tekrar deneyin.',
          buttonLabel: 'Ayarları Aç',
          onPressed: () => Geolocator.openAppSettings(),
          secondaryLabel: 'Haritayı konumsuz göster',
          onSecondary: _browseWithoutLocation,
        );
      case _GateStatus.noGps:
        return _buildGate(
          theme,
          icon: Icons.gps_off_rounded,
          accent: theme.warning,
          title: 'GPS sinyali bulunamadı',
          subtitle:
              'Açık havada olun veya telefonunuzun konum servisinin açık olduğundan emin olun.',
          buttonLabel: 'Tekrar Dene',
          onPressed: _initLocation,
          secondaryLabel: 'Haritayı konumsuz göster',
          onSecondary: _browseWithoutLocation,
        );
      case _GateStatus.ready:
        return _buildMap(theme);
    }
  }

  Widget _buildGate(
    AppTheme theme, {
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    String? buttonLabel,
    VoidCallback? onPressed,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: accent, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.4),
            ),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(buttonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel,
                    style: TextStyle(color: theme.primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOutsideBanner(AppTheme theme) {
    final where = _adminArea != null ? '$_adminArea · ' : '';
    return Material(
      color: theme.isDark ? theme.surface : Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: theme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${where}Kampüsten ${_distanceToCampus.toStringAsFixed(1)} km '
                'uzaktasın. Harita kampüs merkezinde gösteriliyor.',
                style: TextStyle(color: theme.textColor, fontSize: 12.5, height: 1.3),
              ),
            ),
            IconButton(
              tooltip: 'Kapat',
              icon: Icon(Icons.close_rounded, color: theme.textMuted, size: 18),
              onPressed: () => setState(() => _outsideBannerDismissed = true),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Harita
  // ------------------------------------------------------------------

  Widget _buildMap(AppTheme theme) {
    return Column(
      children: [
        _buildSearch(theme),
        const SizedBox(height: 8),
        _buildCategoryChips(theme),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _buildFlutterMap(theme)),
              if (_isOutsideSakarya && !_outsideBannerDismissed)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 8,
                  child: _buildOutsideBanner(theme),
                ),
              if (_mapReady && _position != null && !_isOutsideSakarya)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _buildLocateButton(theme),
                ),
              if (_selected != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _buildDetailCard(theme),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearch(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.isDark
              ? theme.surface.withValues(alpha: 0.7)
              : theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.isDark
                ? theme.primary.withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(color: theme.textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Mekan, durak veya yurt ara...',
            hintStyle: TextStyle(color: theme.textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: theme.primary),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(AppTheme theme) {
    const plural = {
      PoiCategory.dormitory: 'Yurtlar',
      PoiCategory.busStop: 'Duraklar',
      PoiCategory.faculty: 'Fakülteler',
      PoiCategory.walkingRoute: 'Yürüyüş Rotaları',
      PoiCategory.bikeRoute: 'Bisiklet Yolları',
    };
    const order = [
      PoiCategory.dormitory,
      PoiCategory.busStop,
      PoiCategory.walkingRoute,
      PoiCategory.bikeRoute,
      PoiCategory.faculty,
      PoiCategory.study,
      PoiCategory.wifi,
      PoiCategory.food,
      PoiCategory.market,
      PoiCategory.health,
      PoiCategory.sport,
      PoiCategory.park,
      PoiCategory.worship,
      PoiCategory.finance,
      PoiCategory.culture,
    ];
    final chips = <(PoiCategory?, String, IconData)>[
      (null, 'Tümü', Icons.all_inclusive_rounded),
      for (final c in order) (c, plural[c] ?? c.label, _categoryIcon(c)),
    ];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        itemBuilder: (ctx, idx) {
          final (cat, label, icon) = chips[idx];
          final isSelected = cat == _activeCategory;
          return GestureDetector(
            onTap: () => setState(() {
              _activeCategory = cat;
              _selected = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.primary
                    : (theme.isDark
                        ? theme.surface.withValues(alpha: 0.5)
                        : theme.surface),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? theme.primary
                      : (theme.isDark
                          ? theme.textMuted.withValues(alpha: 0.2)
                          : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? Colors.white : theme.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : theme.textColor,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlutterMap(AppTheme theme) {
    final visible = _visiblePois;
    final polylines = visible
        .where((p) => p.isRoute)
        .map((p) {
          final color = _categoryColor(p.category);
          return Polyline(
            points: p.routePoints,
            strokeWidth: p.category == PoiCategory.bikeRoute ? 5 : 4,
            color: color.withValues(alpha: 0.85),
            borderColor: color.withValues(alpha: 0.35),
            borderStrokeWidth: 2,
            pattern: p.category == PoiCategory.bikeRoute
                ? StrokePattern.dashed(segments: [7, 5])
                : const StrokePattern.solid(),
          );
        })
        .toList();

    final markers = visible
        .where((p) => !p.isRoute)
        .map((p) => Marker(
              point: p.point,
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => setState(() => _selected = p),
                child: _PoiMarker(
                  poi: p,
                  color: _categoryColor(p.category),
                  icon: _categoryIcon(p.category),
                  isSelected: _selected?.id == p.id,
                ),
              ),
            ))
        .toList();

    if (_position != null) {
      markers.add(Marker(
        point: LatLng(_position!.latitude, _position!.longitude),
        width: 30,
        height: 30,
        child: const _UserDot(),
      ));
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LocationService.campusCenter,
        initialZoom: 15.5,
        minZoom: 12,
        maxZoom: 19,
        onMapReady: () {
          _mapReady = true;
          if (_position != null && !_isOutsideSakarya) {
            _mapController.move(
              LatLng(_position!.latitude, _position!.longitude),
              16,
            );
          }
        },
        onTap: (tapPosition, point) => setState(() => _selected = null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.Nevgenc',
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
        if (_poisLoading)
          const Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Widget _buildLocateButton(AppTheme theme) {
    return Material(
      color: theme.isDark ? theme.surface : Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Konumuma git',
        icon: Icon(Icons.my_location_rounded, color: theme.primary),
        onPressed: () {
          if (_mapReady && _position != null) {
            _mapController.move(
              LatLng(_position!.latitude, _position!.longitude),
              17,
            );
          }
        },
      ),
    );
  }

  Widget _buildDetailCard(AppTheme theme) {
    final poi = _selected!;
    final color = _categoryColor(poi.category);
    final distance = _position == null
        ? null
        : LocationService.haversineKm(
            _position!.latitude,
            _position!.longitude,
            poi.lat,
            poi.lng,
          );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.isDark ? theme.surface.withValues(alpha: 0.97) : theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_categoryIcon(poi.category), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            poi.name,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            poi.category.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (distance != null)
                      Row(
                        children: [
                          Icon(Icons.near_me_rounded,
                              size: 12, color: theme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            distance < 1
                                ? 'Sana ~${(distance * 1000).round()} m'
                                : 'Sana ~${distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selected = null),
                child: Icon(Icons.close_rounded,
                    color: theme.textMuted, size: 20),
              ),
            ],
          ),
          if (poi.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              poi.description,
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.8),
                fontSize: 12,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (poi.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 12, color: theme.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    poi.address,
                    style: TextStyle(color: theme.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openDirections(poi),
              icon: const Icon(Icons.near_me_rounded, size: 16),
              label: const Text('Yol Tarifi Al',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDirections(CampusPoi poi) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${poi.lat},${poi.lng}',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yol tarifi açılamadı. Google Maps kurulu mu?'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yol tarifi açılamadı.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _PoiMarker extends StatelessWidget {
  final CampusPoi poi;
  final Color color;
  final IconData icon;
  final bool isSelected;

  const _PoiMarker({
    required this.poi,
    required this.color,
    required this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.25 : 1.0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isSelected ? 0.7 : 0.4),
              blurRadius: isSelected ? 14 : 8,
              spreadRadius: isSelected ? 3 : 1,
            ),
          ],
          border: Border.all(color: Colors.white, width: 2.5),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
