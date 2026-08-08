import 'package:latlong2/latlong.dart';

/// Kampüs Cepte POI kategorileri.
enum PoiCategory {
  dormitory, // yurt (özel + KYK)
  busStop, // otobüs durağı
  wifi, // wi-fi alanı
  study, // ders çalışma / kütüphane
  bikeRoute, // bisiklet rotası (polyline)
  walkingRoute; // yürüyüş rotası (polyline)

  static PoiCategory fromString(String s) {
    switch (s) {
      case 'dormitory':
        return PoiCategory.dormitory;
      case 'busStop':
        return PoiCategory.busStop;
      case 'wifi':
        return PoiCategory.wifi;
      case 'study':
        return PoiCategory.study;
      case 'bikeRoute':
        return PoiCategory.bikeRoute;
      case 'walkingRoute':
        return PoiCategory.walkingRoute;
      default:
        return PoiCategory.study;
    }
  }

  /// Kullanıcıya gösterilen kısa Türkçe etiket.
  String get label => switch (this) {
        PoiCategory.dormitory => 'Yurt',
        PoiCategory.busStop => 'Durak',
        PoiCategory.wifi => 'Wi-Fi',
        PoiCategory.study => 'Ders Çalışma',
        PoiCategory.bikeRoute => 'Bisiklet',
        PoiCategory.walkingRoute => 'Yürüyüş',
      };
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
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: PoiCategory.fromString(json['category'] as String? ?? ''),
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
