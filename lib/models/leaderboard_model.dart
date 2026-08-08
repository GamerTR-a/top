class RankingModel {
  final String isim;
  final String gorsel;
  final int puan;
  final int siralama;
  final String trend; // 'up', 'down', 'stable'
  final int? rozetSayisi; // Sadece öğrenciler için

  RankingModel({
    required this.isim,
    required this.gorsel,
    required this.puan,
    required this.siralama,
    required this.trend,
    this.rozetSayisi,
  });
}

class LeaderboardData {
  final List<RankingModel> topluluklar;
  final List<RankingModel> uyeler;

  LeaderboardData({required this.topluluklar, required this.uyeler});
}
