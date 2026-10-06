/// Kampüs Bilgi Yarışması sorusu. `options` her zaman 4 şık içerir.
class QuizQuestion {
  /// Sunucudaki kayıt kimliği; uygulamayla gelen sorularda null.
  final int? id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String category;

  const QuizQuestion({
    this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.category = 'Genel Kültür',
  });

  String get correctAnswer => options[correctIndex];

  /// Geçersiz kayıt (şık sayısı 4 değil, doğru şık aralık dışında) için null.
  static QuizQuestion? tryFromApiJson(Map<String, dynamic> json) {
    final raw = json['options'];
    if (raw is! List || raw.length != 4) return null;
    final options = raw.map((e) => e?.toString().trim() ?? '').toList();
    final correct = (json['correct_index'] as num?)?.toInt() ?? -1;
    final question = (json['question'] as String? ?? '').trim();
    if (question.isEmpty ||
        correct < 0 ||
        correct > 3 ||
        options.any((o) => o.isEmpty)) {
      return null;
    }
    return QuizQuestion(
      id: (json['id'] as num?)?.toInt(),
      question: question,
      options: options,
      correctIndex: correct,
      category: (json['category'] as String?)?.trim().isNotEmpty == true
          ? (json['category'] as String).trim()
          : 'Genel Kültür',
    );
  }
}

const quizCategories = ['Sakarya ve Kampüs', 'Genel Kültür', 'Bilim', 'Teknoloji', 'Edebiyat ve Sanat', 'Tarih', 'Spor'];

/// Uygulamayla gelen sorular. Admin panelinden eklenenler bunlara eklenir.
/// Doğru şık her zaman ilk sıradadır; şıklar oyunda karıştırılır.
const List<QuizQuestion> bundledQuizQuestions = [
  // ── Sakarya ve Kampüs ──────────────────────────────────────────────────
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Sakarya\'nın plaka kodu kaçtır?', options: ['54', '41', '34', '14'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Sakarya Üniversitesi hangi yıl kuruldu?', options: ['1992', '1982', '2002', '1975'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Sakarya Uygulamalı Bilimler Üniversitesi hangi yıl kuruldu?', options: ['2018', '2008', '1998', '2012'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Sakarya Üniversitesi Esentepe Kampüsü hangi ilçededir?', options: ['Serdivan', 'Erenler', 'Hendek', 'Akyazı'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Sakarya\'nın şehir merkezini oluşturan ilçe hangisidir?', options: ['Adapazarı', 'Sapanca', 'Karasu', 'Geyve'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Sakarya Nehri hangi denize dökülür?', options: ['Karadeniz', 'Marmara Denizi', 'Ege Denizi', 'Akdeniz'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Aşağıdaki ilçelerden hangisinin Karadeniz\'e kıyısı vardır?', options: ['Karasu', 'Geyve', 'Pamukova', 'Taraklı'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Tarihi Osmanlı evleriyle tanınan ve "sakin şehir" unvanı taşıyan Sakarya ilçesi hangisidir?', options: ['Taraklı', 'Ferizli', 'Söğütlü', 'Arifiye'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Sakarya\'nın en bilinen gölü hangisidir?', options: ['Sapanca Gölü', 'Abant Gölü', 'İznik Gölü', 'Manyas Gölü'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Sakarya Meydan Muharebesi hangi yıl yapıldı?', options: ['1921', '1919', '1923', '1915'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Sakaryaspor\'un renkleri hangileridir?', options: ['Yeşil - Siyah', 'Sarı - Kırmızı', 'Mavi - Beyaz', 'Bordo - Mavi'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Adapazarı mutfağının en tanınan lezzeti hangisidir?', options: ['Islama köfte', 'Cağ kebabı', 'Tantuni', 'Kuymak'], correctIndex: 0),
  QuizQuestion(category: 'Sakarya ve Kampüs', question: 'Sakarya\'yı da etkileyen 1999 Marmara Depremi hangi gün oldu?', options: ['17 Ağustos', '12 Kasım', '6 Şubat', '23 Ekim'], correctIndex: 0),

  // ── Genel Kültür ───────────────────────────────────────────────────────
  QuizQuestion(question: 'Türkiye\'nin en yüksek dağı hangisidir?', options: ['Ağrı Dağı', 'Erciyes Dağı', 'Uludağ', 'Kaçkar Dağı'], correctIndex: 0),
  QuizQuestion(question: 'Türkiye\'nin en büyük gölü hangisidir?', options: ['Van Gölü', 'Tuz Gölü', 'Beyşehir Gölü', 'Eğirdir Gölü'], correctIndex: 0),
  QuizQuestion(question: 'Tamamı Türkiye sınırları içinde olan en uzun nehir hangisidir?', options: ['Kızılırmak', 'Fırat', 'Sakarya', 'Yeşilırmak'], correctIndex: 0),
  QuizQuestion(question: 'Dünyanın en büyük okyanusu hangisidir?', options: ['Büyük Okyanus (Pasifik)', 'Atlas Okyanusu', 'Hint Okyanusu', 'Arktik Okyanusu'], correctIndex: 0),
  QuizQuestion(question: 'Türk alfabesinde kaç harf vardır?', options: ['29', '26', '28', '32'], correctIndex: 0),
  QuizQuestion(question: 'Türkiye\'nin uluslararası telefon kodu kaçtır?', options: ['+90', '+49', '+30', '+44'], correctIndex: 0),
  QuizQuestion(question: 'Yeryüzünde kaç kıta vardır?', options: ['7', '5', '6', '8'], correctIndex: 0),

  // ── Tarih ──────────────────────────────────────────────────────────────
  QuizQuestion(category: 'Tarih', question: 'Türkiye Cumhuriyeti hangi yıl ilan edildi?', options: ['1923', '1920', '1919', '1938'], correctIndex: 0),
  QuizQuestion(category: 'Tarih', question: 'Türkiye Büyük Millet Meclisi hangi tarihte açıldı?', options: ['23 Nisan 1920', '19 Mayıs 1919', '29 Ekim 1923', '30 Ağustos 1922'], correctIndex: 0),
  QuizQuestion(category: 'Tarih', question: 'İstanbul hangi yıl fethedildi?', options: ['1453', '1071', '1299', '1517'], correctIndex: 0),
  QuizQuestion(category: 'Tarih', question: 'Malazgirt Meydan Muharebesi hangi yıl yapıldı?', options: ['1071', '1176', '1243', '1402'], correctIndex: 0),
  QuizQuestion(category: 'Tarih', question: 'İstiklal Marşı\'nın şairi kimdir?', options: ['Mehmet Akif Ersoy', 'Namık Kemal', 'Yahya Kemal Beyatlı', 'Ziya Gökalp'], correctIndex: 0),

  // ── Bilim ──────────────────────────────────────────────────────────────
  QuizQuestion(category: 'Bilim', question: 'Suyun kimyasal formülü nedir?', options: ['H₂O', 'CO₂', 'O₂', 'NaCl'], correctIndex: 0),
  QuizQuestion(category: 'Bilim', question: 'Altının kimyasal simgesi nedir?', options: ['Au', 'Ag', 'Al', 'At'], correctIndex: 0),
  QuizQuestion(category: 'Bilim', question: 'Güneş sistemindeki en büyük gezegen hangisidir?', options: ['Jüpiter', 'Satürn', 'Neptün', 'Dünya'], correctIndex: 0),
  QuizQuestion(category: 'Bilim', question: 'Güneş\'e en yakın gezegen hangisidir?', options: ['Merkür', 'Venüs', 'Mars', 'Dünya'], correctIndex: 0),
  QuizQuestion(category: 'Bilim', question: 'Işığın boşluktaki hızı yaklaşık kaç km/s\'dir?', options: ['300.000', '150.000', '30.000', '1.000.000'], correctIndex: 0),
  QuizQuestion(category: 'Bilim', question: 'Bir üçgenin iç açıları toplamı kaç derecedir?', options: ['180', '90', '270', '360'], correctIndex: 0),
  QuizQuestion(category: 'Bilim', question: 'En küçük asal sayı kaçtır?', options: ['2', '1', '3', '0'], correctIndex: 0),
  QuizQuestion(category: 'Bilim', question: 'Bitkiler fotosentez sırasında havadan hangi gazı alır?', options: ['Karbondioksit', 'Oksijen', 'Azot', 'Hidrojen'], correctIndex: 0),
  QuizQuestion(category: 'Bilim', question: 'İnsan vücudunun en büyük organı hangisidir?', options: ['Deri', 'Karaciğer', 'Akciğer', 'Beyin'], correctIndex: 0),
  QuizQuestion(category: 'Bilim', question: 'Genel görelilik kuramını kim geliştirdi?', options: ['Albert Einstein', 'Isaac Newton', 'Niels Bohr', 'Galileo Galilei'], correctIndex: 0),
  QuizQuestion(category: 'Bilim', question: '2015 Nobel Kimya Ödülü\'nü kazanan Türk bilim insanı kimdir?', options: ['Aziz Sancar', 'Cahit Arf', 'Oktay Sinanoğlu', 'Feza Gürsey'], correctIndex: 0),

  // ── Teknoloji ──────────────────────────────────────────────────────────
  QuizQuestion(category: 'Teknoloji', question: 'Bir bayt kaç bitten oluşur?', options: ['8', '4', '16', '10'], correctIndex: 0),
  QuizQuestion(category: 'Teknoloji', question: 'İkili (binary) sistemdeki 10 sayısı onluk sistemde kaçtır?', options: ['2', '10', '1', '4'], correctIndex: 0),
  QuizQuestion(category: 'Teknoloji', question: 'HTML\'in açılımı hangisidir?', options: ['HyperText Markup Language', 'High Transfer Machine Language', 'Home Tool Markup Language', 'HyperText Main Link'], correctIndex: 0),
  QuizQuestion(category: 'Teknoloji', question: 'Python programlama dilini kim geliştirdi?', options: ['Guido van Rossum', 'Dennis Ritchie', 'James Gosling', 'Linus Torvalds'], correctIndex: 0),
  QuizQuestion(category: 'Teknoloji', question: 'Flutter ile uygulama geliştirirken hangi programlama dili kullanılır?', options: ['Dart', 'Kotlin', 'Swift', 'Go'], correctIndex: 0),

  // ── Edebiyat ve Sanat ──────────────────────────────────────────────────
  QuizQuestion(category: 'Edebiyat ve Sanat', question: '"Suç ve Ceza" romanının yazarı kimdir?', options: ['Fyodor Dostoyevski', 'Lev Tolstoy', 'Anton Çehov', 'Nikolay Gogol'], correctIndex: 0),
  QuizQuestion(category: 'Edebiyat ve Sanat', question: '"Sefiller" romanının yazarı kimdir?', options: ['Victor Hugo', 'Honoré de Balzac', 'Émile Zola', 'Albert Camus'], correctIndex: 0),
  QuizQuestion(category: 'Edebiyat ve Sanat', question: '"Kürk Mantolu Madonna" kimin eseridir?', options: ['Sabahattin Ali', 'Orhan Kemal', 'Yaşar Kemal', 'Reşat Nuri Güntekin'], correctIndex: 0),
  QuizQuestion(category: 'Edebiyat ve Sanat', question: 'Nobel Edebiyat Ödülü kazanan ilk Türk yazar kimdir?', options: ['Orhan Pamuk', 'Yaşar Kemal', 'Elif Şafak', 'Nâzım Hikmet'], correctIndex: 0),
  QuizQuestion(category: 'Edebiyat ve Sanat', question: '"Mona Lisa" tablosunu kim yaptı?', options: ['Leonardo da Vinci', 'Michelangelo', 'Pablo Picasso', 'Vincent van Gogh'], correctIndex: 0),

  // ── Spor ───────────────────────────────────────────────────────────────
  QuizQuestion(category: 'Spor', question: 'FIFA Dünya Kupası kaç yılda bir düzenlenir?', options: ['4', '2', '3', '5'], correctIndex: 0),
  QuizQuestion(category: 'Spor', question: 'Olimpiyat bayrağında kaç halka vardır?', options: ['5', '4', '6', '7'], correctIndex: 0),
  QuizQuestion(category: 'Spor', question: 'Futbolda bir takım sahaya kaç oyuncuyla çıkar?', options: ['11', '10', '9', '12'], correctIndex: 0),
];
