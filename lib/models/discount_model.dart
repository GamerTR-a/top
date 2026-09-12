class DiscountModel {
  final int id;
  final String sirketAd;
  final String kuponAdi;
  final String indirimOrani;
  final String logoPath;
  final int renk; // Hex color code
  final double latitude;
  final double longitude;
  final double geofenceRadiusMeters;
  final String merchantCodeChar;
  final String categoryPrefix;
  final String? claimedCode;
  final DateTime? claimedAt;

  DiscountModel({
    required this.id,
    required this.sirketAd,
    required this.kuponAdi,
    required this.indirimOrani,
    required this.logoPath,
    required this.renk,
    this.latitude = 40.7408,
    this.longitude = 30.3333,
    this.geofenceRadiusMeters = 50.0,
    this.merchantCodeChar = 'X',
    this.categoryPrefix = 'AB',
    this.claimedCode,
    this.claimedAt,
  });

  bool get isClaimed => claimedCode != null && claimedCode!.isNotEmpty;

  DiscountModel copyWith({
    int? id,
    String? sirketAd,
    String? kuponAdi,
    String? indirimOrani,
    String? logoPath,
    int? renk,
    double? latitude,
    double? longitude,
    double? geofenceRadiusMeters,
    String? merchantCodeChar,
    String? categoryPrefix,
    String? claimedCode,
    DateTime? claimedAt,
  }) {
    return DiscountModel(
      id: id ?? this.id,
      sirketAd: sirketAd ?? this.sirketAd,
      kuponAdi: kuponAdi ?? this.kuponAdi,
      indirimOrani: indirimOrani ?? this.indirimOrani,
      logoPath: logoPath ?? this.logoPath,
      renk: renk ?? this.renk,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      merchantCodeChar: merchantCodeChar ?? this.merchantCodeChar,
      categoryPrefix: categoryPrefix ?? this.categoryPrefix,
      claimedCode: claimedCode ?? this.claimedCode,
      claimedAt: claimedAt ?? this.claimedAt,
    );
  }

  factory DiscountModel.fromApiJson(Map<String, dynamic> json) {
    int parsedColor;
    try {
      parsedColor = int.parse(
        (json['color'] as String? ?? 'FF6200EE').replaceFirst('#', ''),
        radix: 16,
      );
    } catch (_) {
      parsedColor = 0xFF6200EE;
    }

    DateTime? parsedClaimedAt;
    if (json['claimed_at'] != null) {
      try {
        parsedClaimedAt = DateTime.parse(json['claimed_at'] as String);
      } catch (_) {}
    }

    return DiscountModel(
      id: (json['id'] as num).toInt(),
      sirketAd: json['company_name'] as String? ?? '',
      kuponAdi: json['coupon_name'] as String? ?? '',
      indirimOrani: json['discount_rate'] as String? ?? '',
      logoPath: json['logo_path'] as String? ?? '',
      renk: parsedColor,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 40.7408,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 30.3333,
      geofenceRadiusMeters:
          (json['geofence_radius_meters'] as num?)?.toDouble() ?? 50.0,
      merchantCodeChar: json['merchant_code_char'] as String? ?? 'X',
      categoryPrefix: json['category_prefix'] as String? ?? 'AB',
      claimedCode: json['claimed_code'] as String? ?? json['code'] as String?,
      claimedAt: parsedClaimedAt,
    );
  }
}

