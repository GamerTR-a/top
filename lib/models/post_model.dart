class PostModel {
  final int id;
  final String toplulukAdi;
  final String toplulukLogo;
  final String metin;
  final String? resimUrl;
  final String tarih;
  final int destekPuani;
  final double kalitePuani;
  final double ratingAvg;
  final int ratingCount;
  final int? myRating;
  final bool isSupportedByMe;
  final String? etkinlikGorseli;

  const PostModel({
    required this.id,
    required this.toplulukAdi,
    required this.toplulukLogo,
    required this.metin,
    this.resimUrl,
    this.etkinlikGorseli,
    required this.tarih,
    required this.destekPuani,
    required this.kalitePuani,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.myRating,
    this.isSupportedByMe = false,
  });

  static const Object _unset = Object();

  PostModel copyWith({
    int? destekPuani,
    double? kalitePuani,
    double? ratingAvg,
    int? ratingCount,
    Object? myRating = _unset,
    bool? isSupportedByMe,
  }) {
    return PostModel(
      id: id,
      toplulukAdi: toplulukAdi,
      toplulukLogo: toplulukLogo,
      metin: metin,
      resimUrl: resimUrl,
      etkinlikGorseli: etkinlikGorseli,
      tarih: tarih,
      destekPuani: destekPuani ?? this.destekPuani,
      kalitePuani: kalitePuani ?? this.kalitePuani,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      myRating: identical(myRating, _unset) ? this.myRating : myRating as int?,
      isSupportedByMe: isSupportedByMe ?? this.isSupportedByMe,
    );
  }

  factory PostModel.fromApiJson(Map<String, dynamic> json) {
    return PostModel(
      id: (json['id'] as num).toInt(),
      toplulukAdi: json['community_name'] as String? ?? '',
      toplulukLogo:
          json['community_logo'] as String? ?? 'assets/gem.png',
      metin: json['content'] as String? ?? '',
      resimUrl: json['image_url'] as String?,
      etkinlikGorseli: json['event_image'] as String?,
      tarih: json['created_at'] as String? ?? '',
      destekPuani: (json['support_count'] as num?)?.toInt() ?? 0,
      kalitePuani: (json['quality_score'] as num?)?.toDouble() ?? 0.0,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    );
  }
}
