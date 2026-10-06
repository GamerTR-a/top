import 'package:latlong2/latlong.dart';

/// Kampüs Cepte POI kategorileri. Adlar `campus_poi.json` ve `campus_pois`
/// tablosundaki `category` değerleriyle aynıdır.
enum PoiCategory {
  dormitory('Yurt'),
  busStop('Durak'),
  faculty('Fakülte'),
  study('Ders Çalışma'),
  wifi('Wi-Fi'),
  food('Yeme İçme'),
  market('Market'),
  health('Sağlık'),
  sport('Spor'),
  park('Park'),
  worship('Cami'),
  finance('Banka / ATM'),
  culture('Kültür'),
  walkingRoute('Yürüyüş'),
  bikeRoute('Bisiklet');

  const PoiCategory(this.label);

  /// Kullanıcıya gösterilen kısa Türkçe etiket.
  final String label;

  bool get isRouteCategory =>
      this == PoiCategory.walkingRoute || this == PoiCategory.bikeRoute;

  /// Bilinmeyen değer (yeni sürümde eklenmiş kategori) için null döner;
  /// çağıran taraf o kaydı atlar.
  static PoiCategory? tryParse(String s) {
    for (final c in values) {
      if (c.name == s) return c;
    }
    return null;
  }
}

/// Kampüs Cepte POI — nokta (yurt, durak, wifi, ders) veya rota (polyline).
class CampusPoi {
  final String id;
  final String name;
  final PoiCategory category;
  final double lat;
  final double lng;
  final String description;
  final String address;
  final List<LatLng> routePoints;

  CampusPoi({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    this.description = '',
    this.address = '',
    this.routePoints = const [],
  });

  factory CampusPoi.fromJson(Map<String, dynamic> json) {
    final points = <LatLng>[];
    final rawPoints = json['points'];
    if (rawPoints is List) {
      for (final p in rawPoints) {
        if (p is Map<String, dynamic>) {
          final lat = (p['lat'] as num?)?.toDouble();
          final lng = (p['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) points.add(LatLng(lat, lng));
        }
      }
    }
    return CampusPoi(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      category: PoiCategory.tryParse(json['category'] as String? ?? '') ??
          PoiCategory.study,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      routePoints: points,
    );
  }

  /// Rota POI'si (polyline verisi var).
  bool get isRoute => routePoints.isNotEmpty;

  /// Nokta olarak kullanım için koordinat.
  LatLng get point => LatLng(lat, lng);
}
