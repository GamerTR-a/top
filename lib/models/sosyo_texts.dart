/// SOSYO ekranındaki metinler. Admin panelinden (Ayarlar → SOSYO Metinleri)
/// `app_settings` tablosuna yazılır; kayıt yoksa buradaki varsayılanlar gösterilir.
class SosyoTexts {
  static const descriptionKey = 'sosyo_description';
  static const aboutKey = 'sosyo_about';

  static const defaultDescription =
      'NevGenç topluluğunun sosyal platformu. Aşağıdaki bağlantılardan bize ulaşabilir, etkinliklerden haberdar olabilirsin!';
  static const defaultAbout =
      'Merhabalar; ben Bilgisayar Mühendisliği Öğrencisi Abdurrahman Turan Özcan; Yazılım Mühendisliği Öğrencisi Deniz Emir Yıldız, Yazılım Mühendisliği Öğrencisi Mehmet Ali Işık\'a teşekkür ederek söze başlamak istiyorum. NevGenç, Sakarya ve Sakarya Uygulamalı Bilimler üniversitesindeki toplulukların ve öğrenci arkadaşlarımızın hayatını kolaylaştırmak ve üniversite hayatını en verimli şekilde geçirmelerini amaçlayarak ortaya çıkmış bir projedir. Sakarya Belediyesi, Serdivan\'daki çeşitli işletmeler, Çekirdekten Girişimci Vakfı, üniversite toplulukları ve üniversite yönetimi arasında köprü olarak kampüsümüzü ve Sakaryamızı geleceğe taşımak için NevGenç projesini hayata geçirdik.';

  static String? cachedDescription;
  static String? cachedAbout;

  static void remember(String description, String about) {
    cachedDescription = description;
    cachedAbout = about;
  }
}
