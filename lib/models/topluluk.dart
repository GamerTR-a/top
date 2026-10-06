class Topluluk {
  final int id;
  final String ad;
  final String logoPath;
  final String kategori;
  final double puan;
  final int uyeSayisi;
  final String aciklama;
  final String baskanAdi;
  final String? baskanId;
  final String kisaltma;
  final String iletisimEposta;
  final String iletisimTelefon;

  Topluluk({
    required this.id,
    required this.ad,
    required this.logoPath,
    required this.kategori,
    required this.puan,
    required this.uyeSayisi,
    required this.aciklama,
    required this.baskanAdi,
    this.baskanId,
    this.kisaltma = '',
    this.iletisimEposta = '',
    this.iletisimTelefon = '',
  });

  factory Topluluk.fromApiJson(Map<String, dynamic> json) {
    return Topluluk(
      id: (json['id'] as num).toInt(),
      ad: json['name'] as String? ?? '',
      logoPath: json['logo_path'] as String? ?? '',
      kategori: json['category'] as String? ?? '',
      puan: ((json['score'] as num?) ?? 0).toDouble(),
      uyeSayisi: ((json['member_count'] as num?) ?? 0).toInt(),
      aciklama: json['description'] as String? ?? '',
      baskanAdi: json['chairman_name'] as String? ?? 'Belirtilmedi',
      baskanId: json['chairman_id'] as String?,
      kisaltma: json['short_name'] as String? ?? '',
      iletisimEposta: json['contact_email'] as String? ?? '',
      iletisimTelefon: json['contact_phone'] as String? ?? '',
    );
  }
}
