class RozetModel {
  final String rozetAd;
  final String ikon;
  final bool kazanildi;

  RozetModel({
    required this.rozetAd,
    required this.ikon,
    required this.kazanildi,
  });

  Map<String, dynamic> toJson() => {
        'rozetAd': rozetAd,
        'ikon': ikon,
        'kazanildi': kazanildi,
      };

  factory RozetModel.fromJson(Map<String, dynamic> json) => RozetModel(
        rozetAd: json['rozetAd'] as String? ?? '',
        ikon: json['ikon'] as String? ?? '',
        kazanildi: json['kazanildi'] as bool? ?? false,
      );
}

class UserProfileModel {
  final String adSoyad;
  final String email;
  final String birthDate;
  final String bolum;
  final String sinif;
  final String profilFoto;
  final String qrData;
  final List<RozetModel> rozetler;
  final List<String> katilinanEtkinlikler;

  UserProfileModel({
    required this.adSoyad,
    this.email = '23010404022@subu.edu.tr',
    this.birthDate = '15.05.2002',
    required this.bolum,
    required this.sinif,
    required this.profilFoto,
    required this.qrData,
    required this.rozetler,
    required this.katilinanEtkinlikler,
  });

  UserProfileModel copyWith({
    String? adSoyad,
    String? email,
    String? birthDate,
    String? bolum,
    String? sinif,
    String? profilFoto,
    String? qrData,
    List<RozetModel>? rozetler,
    List<String>? katilinanEtkinlikler,
  }) {
    return UserProfileModel(
      adSoyad: adSoyad ?? this.adSoyad,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      bolum: bolum ?? this.bolum,
      sinif: sinif ?? this.sinif,
      profilFoto: profilFoto ?? this.profilFoto,
      qrData: qrData ?? this.qrData,
      rozetler: rozetler ?? this.rozetler,
      katilinanEtkinlikler: katilinanEtkinlikler ?? this.katilinanEtkinlikler,
    );
  }

  /// Yerel önbellek için tam tur (round-trip) serileştirme.
  Map<String, dynamic> toJson() => {
        'adSoyad': adSoyad,
        'email': email,
        'birthDate': birthDate,
        'bolum': bolum,
        'sinif': sinif,
        'profilFoto': profilFoto,
        'qrData': qrData,
        'rozetler': rozetler.map((r) => r.toJson()).toList(),
        'katilinanEtkinlikler': katilinanEtkinlikler,
      };

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      UserProfileModel(
        adSoyad: json['adSoyad'] as String? ?? '',
        email: json['email'] as String? ?? '23010404022@subu.edu.tr',
        birthDate: json['birthDate'] as String? ?? '15.05.2002',
        bolum: json['bolum'] as String? ?? 'Bilişim Sistemleri Mühendisliği',
        sinif: json['sinif'] as String? ?? '3. Sınıf',
        profilFoto: json['profilFoto'] as String? ?? 'assets/gem.png',
        qrData: json['qrData'] as String? ?? '',
        rozetler: (json['rozetler'] as List? ?? [])
            .map((e) => RozetModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        katilinanEtkinlikler: (json['katilinanEtkinlikler'] as List? ?? [])
            .cast<String>(),
      );
}
