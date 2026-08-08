class DiscountModel {
  final int id;
  final String sirketAd;
  final String kuponAdi;
  final String indirimOrani;
  final String logoPath;
  final int renk; // Hex color code

  DiscountModel({
    required this.id,
    required this.sirketAd,
    required this.kuponAdi,
    required this.indirimOrani,
    required this.logoPath,
    required this.renk,
  });

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
    return DiscountModel(
      id: (json['id'] as num).toInt(),
      sirketAd: json['company_name'] as String? ?? '',
      kuponAdi: json['coupon_name'] as String? ?? '',
      indirimOrani: json['discount_rate'] as String? ?? '',
      logoPath: json['logo_path'] as String? ?? '',
      renk: parsedColor,
    );
  }
}
