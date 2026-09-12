import 'dart:math' as math;
import 'dart:ui' show Locale;

import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Konum, Sakarya geofence ve kıble hesabı için yardımcı servis.
///
/// Sakarya dışında "Kampüsten uzaktasın" gate'i şu sırayla karar verir:
/// 1. Ters jeokodlama → `administrativeArea` "Sakarya" içeriyor mu (kesin karar)
/// 2. Jeokodlama başarısız/offline ise haversine mesafe fallback'i
class LocationService {
  LocationService._();

  /// SAÜ Esentepe kampüs merkezi (gerçek koşullara göre ayarlanabilir).
  static const LatLng campusCenter = LatLng(40.7408, 30.3333);

  /// Haversine fallback yarıçapı — tüm Sakarya ilini kaplar
  /// (Karasu doğu kenarı ~65 km, Kocaali kuzey ~57 km).
  static const double fallbackRadiusKm = 70.0;

  /// Kabe (Mekke).
  static const LatLng kaaba = LatLng(21.4225, 39.8262);

  static final geo.Geocoding _geocoding = geo.Geocoding();

  /// Konum iznini kontrol eder, gerekirse ister.
  /// Kalıcı reddedildiyse `deniedForever` döner (UI "Ayarlar"a yönlendirir).
  static Future<LocationPermission> requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Güncel konum. Önce taze GPS çözümü dener (doğruluk kritik — geofence
  /// gate'i bayat bir "son bilinen konum"a takılıp yanlış "dışarıdasın"
  /// kararı verebilir), taze çözüm zaman aşımına uğrarsa son bilinen konuma
  /// düşer. İkisi de yoksa hata fırlatır → UI "GPS bulunamadı" gösterir.
  static Future<Position> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      // GPS yavaş/kapalı — son bilinen konum hızlı bir tahmin verir.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }

  // Ters jeokodlama önbelleği — aynı/komşu koordinatlara yapılan tekrarlı ağ
  // çağrılarını engeller (harita gate'i + kıble ekranı + "Konumu Yenile").
  static double? _geocodeLat;
  static double? _geocodeLng;
  static geo.Placemark? _geocodePlacemark;

  /// Ters jeokodlama. Hata/offline/rate-limit durumlarında `null` döndürür —
  /// asla fırlatmaz (gate'i jeokodlamaya asla kilitleme).
  ///
  /// Aynı noktaya (~2 km kare komşuluk) yapılan ikinci çağrı önbellekten
  /// anında döner, ağ çağrısını tekrarlamaz.
  static Future<geo.Placemark?> reverseGeocode(double lat, double lng) async {
    final cachedLat = _geocodeLat;
    final cachedLng = _geocodeLng;
    if (cachedLat != null &&
        cachedLng != null &&
        (lat - cachedLat).abs() < 0.02 &&
        (lng - cachedLng).abs() < 0.02) {
      return _geocodePlacemark;
    }
    try {
      final places = await _geocoding.placemarkFromCoordinates(
        lat,
        lng,
        locale: const Locale('tr_TR'),
      );
      final placemark = places.isNotEmpty ? places.first : null;
      _geocodeLat = lat;
      _geocodeLng = lng;
      _geocodePlacemark = placemark;
      return placemark;
    } catch (_) {
      return null;
    }
  }

  /// Sakarya geofence kontrolü — tek ters jeokodlama ile hem kararı hem
  /// placemark'ı döndürür (UI dış-gate için il/uzaklık gösterebilir).
  ///
  /// - `administrativeArea` içinde "sakarya" varsa → inSakarya=true (kesin)
  /// - `administrativeArea` var ama Sakarya değilse → inSakarya=false (kesin)
  /// - Jeokodlama `null`/hata verdiyse → haversine fallback (70 km)
  static Future<({bool inSakarya, geo.Placemark? placemark})>
      sakaryaCheck(double lat, double lng) async {
    final placemark = await reverseGeocode(lat, lng);
    final area = placemark?.administrativeArea?.trim().toLowerCase();
    if (area != null && area.isNotEmpty) {
      return (inSakarya: area.contains('sakarya'), placemark: placemark);
    }
    return (
      inSakarya: haversineKm(
              lat, lng, campusCenter.latitude, campusCenter.longitude) <=
          fallbackRadiusKm,
      placemark: placemark,
    );
  }

  /// Sakarya geofence kontrolü (yalnızca karar).
  static Future<bool> isInSakarya(double lat, double lng) async {
    return (await sakaryaCheck(lat, lng)).inSakarya;
  }

  /// Kampüse haversine mesafesi (km).
  static double distanceToCampusKm(double lat, double lng) =>
      haversineKm(lat, lng, campusCenter.latitude, campusCenter.longitude);

  /// Kabe'ye haversine mesafesi (km).
  static double distanceToKaabaKm(double lat, double lng) =>
      haversineKm(lat, lng, kaaba.latitude, kaaba.longitude);

  /// İki koordinat arası haversine mesafesi (km).
  static double haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(a));
  }

  /// İki koordinat arası haversine mesafesi (metre).
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) =>
      haversineKm(lat1, lng1, lat2, lng2) * 1000.0;


  /// Kabe'ye great-circle initial bearing (derece, 0–360).
  ///
  /// Kampüsten Kabe'ye ~154.5° (Türkiye kıblesi ~155° ile uyumlu).
  static double qiblaBearing(double lat, double lng) {
    final phi1 = _rad(lat);
    final phi2 = _rad(kaaba.latitude);
    final dLng = _rad(kaaba.longitude - lng);
    final theta = math.atan2(
      math.sin(dLng) * math.cos(phi2),
      math.cos(phi1) * math.sin(phi2) -
          math.sin(phi1) * math.cos(phi2) * math.cos(dLng),
    );
    return (theta * 180 / math.pi + 360) % 360;
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
