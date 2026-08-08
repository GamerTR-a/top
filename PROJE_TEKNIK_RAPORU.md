# NevGenç — Teknik Değişiklik Raporu & GitHub'dan Play Store'a Yayınlama Rehberi

Bu doküman, **NevGenç** uygulamasında yapılan tüm teknik iyileştirmeleri, telefonda çökme/açılmama sorunlarının çözümlerini ve ham bir GitHub Reposundan Google Play Store'da Çalışan Bir Uygulamaya Uzanan Yol Haritasını detaylandırır.

---

## 🛠️ BÖLÜM 1: Projede Yapılan Tüm Değişikliklerin Detaylı Listesi

Uygulamanın hem telefonda sorunsuz açılmasını sağlamak hem de Google Play Store standartlarına uyum sağlamak için 7 ana alanda teknik müdahale yapılmıştır:

### 1. Uygulama Görünür Adı Güncellendi (`NewGenç` ➔ `NevGenç`)
- **`AndroidManifest.xml`**: `android:label="NevGenç"` olarak güncellendi.
- **`Info.plist`**: `CFBundleDisplayName` ➔ `NevGenç` olarak değiştirildi.
- **`main.dart`**: `MaterialApp` başlığı `title: 'NevGenç'` yapıldı.
- **Arayüz Ekranları**: Login, Register, Profile, Admin ve Sosyal ekranlardaki tüm başlık metinleri **NevGenç** olarak güncellendi.

### 2. R8 / ProGuard Kod Karartma Kapatıldı (Açılış Çökmesi Çözüldü)
- **`build.gradle.kts`**: `isMinifyEnabled = false` ve `isShrinkResources = false` yapıldı.
- **Nedeni**: Release modunda R8 derleyicisi Supabase, Dio, Socket.IO ve Flutter Engine yansıma (reflection) sınıflarını "kullanılmıyor" zannederek siliyor ve uygulama telefonda tıklandığı an anında çöküyordu.

### 3. Native Android `FLAG_SECURE` Kısıtlaması Kaldırıldı
- **`MainActivity.kt`**: `window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)` bayrağı silindi.
- **Nedeni**: `FLAG_SECURE` bayrağı ekran görüntüsü ve kayıt almayı kısıtlar; ancak Samsung, Xiaomi, Huawei gibi bazı cihazlarda Android pencere yüzeyi oluşturulmasını kitleyerek siyah ekranda kalmaya veya `SecurityException` çökmesine yol açıyordu.

### 4. Supabase Statik İlklendirme Çökmesi Düzeltildi
- **`main.dart`**: Global `final supabase = Supabase.instance.client;` tanımı lazy getter yapısına çevrildi (`SupabaseClient get supabase => Supabase.instance.client;`).
- **Nedeni**: Global `final` değişkenler `main()` çalışmadan önce devreye girer. `Supabase.initialize()` çağrılmadan erişildiği için Dart motoru açılışta `StateError` veriyordu.

### 5. AuthGate Yükleme Ekranı Kilitlenmesi Önledi
- **`main.dart` ve `auth_service.dart`**: Yerel oturum okuma fonksiyonu `try-catch` bloğu ile korumaya alındı.
- **Nedeni**: Cihazdaki veri okuma hatasında `_checking = false` yapılamadığı için uygulama sonsuz dönen yükleme simgesinde takılıyordu. Artık hata olsa dahi Login ekranına geçmektedir.

### 6. `FlutterSecureStorage` Android KeyStore Hatası Düzeltildi
- **`token_service.dart` ve `calendar_screen.dart`**: `AndroidOptions` içerisine `resetOnError: true` eklendi.
- **Nedeni**: Android şifreleme anahtarları silindiğinde veya güncellendiğinde ortaya çıkan `GeneralSecurityException` çökmesi engellendi.

### 7. Google Play Sürüm Kodu Yükseltildi & İzinler Ayarlandı
- **`pubspec.yaml`**: `version: 1.0.5+6` (`versionCode = 6`) olarak güncellendi.
- **`AndroidManifest.xml`**: `android:usesCleartextTraffic="true"` eklenerek HTTP ağ engeli kaldırıldı.

---

## 🚀 BÖLÜM 2: GitHub Reposundan Play Store'da Çalışan Bir Uygulamaya Uzanan Yol

Ham bir kaynak kod reposunun Google Play Store'da canlıya çıkma serüveni **5 Temel Adımdan** oluşur:

1. **GitHub Reposunu Klonlama & Bağımlılıklar**
2. **Yerel Test & Çökme Analizleri (Debug/Release)**
3. **İmzalar & Yapılandırma (Keystore & versionCode)**
4. **Android App Bundle (AAB) Paket Derlemesi**
5. **Google Play Console Yayınlama & Dahili Test**

### Adım 1: GitHub Reposunu İndirme ve Bağımlılıkları Hazırlama
- **Repoyu Klonlama**:
  ```bash
  git clone https://github.com/Turan16-k/nevgenc.git
  cd nevgenc
  ```
- **Kütüphaneleri Yükleme**:
  ```bash
  flutter pub get
  ```

### Adım 2: Yerel Hata Ayıklama ve Çökme Analizleri (Debugging)
Uygulamanın açılmasını engelleyen hatalar tespit edilir ve çözülür:
- **Statik Başlatmalar**: `main()` çalışmadan önce erişilen servisler (Supabase, Firebase vb.) lazy-getter veya `main()` içinde `try-catch`'e alınır.
- **Native Engeller**: `FLAG_SECURE` gibi ekran çizmeyi önleyen bayraklar silinir.
- **Kod Karartma (ProGuard)**: Karartma kaynaklı çökmeleri engellemek için `isMinifyEnabled = false` çekilir.

### Adım 3: İmza (Keystore) ve Sürüm Yapılandırması
Play Store paket kabul ederken benzersiz bir İmza (Keystore) ve her yüklemede artan Sürüm Kodu (`versionCode`) şart koşar.

- **`pubspec.yaml` Sürüm Kodu Artırımı**:
  ```yaml
  version: 1.0.5+6 # +6 ifadesi Google Play'deki versionCode = 6 karşılığıdır
  ```
- **Paket İmzası (Keystore)**: `android/app/key.properties` dosyası üzerinden release imzası tanımlanır.

### Adım 4: Android App Bundle (.aab) Paketinin Derlenmesi
Google Play Store artık düz APK kabul etmez, AAB (`.aab`) formatını zorunlu kılar.

```bash
flutter build appbundle --no-tree-shake-icons --dart-define=API_BASE_URL=https://api.nevgenc.app/v1
```
- **Derlenen dosya konumu**: `build/app/outputs/bundle/release/app-release.aab`
- *(Not: Cihazda doğrudan yükleyip test etmek için `flutter build apk` komutu ile `app-release.apk` üretilir).*

### Adım 5: Google Play Console'a Yükleme ve Yayınlama
1. **Google Play Console**'a giriş yapılır.
2. **Dahili Test (Internal Testing)** veya **Üretim (Production)** kanalı seçilir.
3. Derlenen `app-release.aab` dosyası yüklenir.
4. Çıkan uyarılara bakılır:
   - ⚠️ *"Kod gösterme dosyası (mapping.txt) yok"* ➔ Karartma kapalı olduğu için çıkan tavsiye uyarısıdır, yayınlamayı engellemez.
   - ⚠️ *"1 cihaz desteklenmiyor"* ➔ Eski emülatörler içindir, yayınlamayı engellemez.
5. **"Sürümü İncelemeye Gönder"** butonuna basılır. Google incelemesinin ardından (genellikle 1-24 saat) uygulamanız mağazada canlıya çıkar! 🌟
