# 📘 NevGenç — Master Sürüm Günlüğü ve Google Play Console Rehberi

Bu doküman, **NevGenç** Android uygulamasının 1. sürümden itibaren (v1.0.0+1) en son sürüme (v1.0.10+11) kadar geçirdiği tüm mimari değişiklikleri, çökme düzeltmelerini, görsel yenilikleri, profil senkronizasyonunu ve Google Play Console yayımlama adımlarını tüm detaylarıyla içermektedir.

---

## 📌 1. Uygulama ve İmza Kimlik Bilgileri

- **Uygulama Adı**: `NevGenç` *(Eski isim: NewGenç)*
- **Paket Kimliği (Application ID)**: `com.Nevgenc`
- **Play Store Imza Parmak İzi (SHA-1)**: `22:F1:FF:A4:D2:09:95:30:67:8C:82:B6:85:6B:FB:BD:41:53:30:AF`
- **İmza Dosyaları**: `android/upload-keystore.jks` & `android/key.properties`
- **Derleme Çıktı Dosyası**: `app-release.aab` *(Android App Bundle)*

---

## 📜 2. Sürüm Sürüm Detaylı Değişiklik Günlüğü (Changelog)

### 🟢 Sürüm 1 - 5 (İlk Kuruluş, Paket Adı & Sertifika Uyumlaştırması)

1. **Paket İsmi Hatalarının Düzeltilmesi (`com.Nevgenc`)**:
   - **Gereksinim**: Google Play Console uygulamayı `com.Nevgenc` paket adı altında kabul ediyordu.
   - **Yapılan İşlem**: `android/app/build.gradle.kts` ve `AndroidManifest.xml` içindeki paket adları `com.Nevgenc` olarak güncellendi.
2. **SHA-1 Sertifikası ve Keystore İmzası**:
   - **Sorun**: Rastgele üretilen geçici keystore ile imzalanan paketler Google Play tarafından reddedildi.
   - **Çözüm**: Orijinal Play Store imza sertifikasına sahip `upload-keystore.jks` projenin `android/` dizinine eklendi. `key.properties` yapılandırma dosyası ile Gradle release build adımlarına bağlandı.
3. **Uygulama İsim ve Görsel Kimlik Değişimi**:
   - Projenin görünen adı **NevGenç** yapıldı.
   - Yeni amblem logosu (`app_logo.png`) Android `mipmap` simgelerine ve uygulama içi `_Logo` bileşenlerine entegre edildi.

---

### 🟡 Sürüm 6 (Çökme Engelleme & Native İyileştirmeler)

1. **Native Android `FLAG_SECURE` Çökme Düzeltmesi**:
   - **Sorun**: `MainActivity.kt` kodunda `window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)` bayrağı bulunuyordu. Bu bayrak Samsung, Xiaomi, Huawei cihazlarda ekran kaydedici veya erişilebilirlik servisleri aktifken açılışta siyah ekranda kalmaya ve `SecurityException` çökmesine sebep oluyordu.
   - **Çözüm**: Native Kotlin kodundan `FLAG_SECURE` bayrağı tamamen kaldırıldı.
2. **Dart Statik `Supabase.instance.client` İlklendirme Çökmesi**:
   - **Sorun**: `main.dart` dosyasının en üstünde yer alan `final supabase = Supabase.instance.client;` statik tanımı, uygulama henüz `main()` fonksiyonuna girip Supabase'i ilklendirmeden erişildiği için çökmeye yol açıyordu.
   - **Çözüm**: Statik erişim kaldırıldı, `Supabase.initialize()` tamamlandıktan sonra güvenli erişim sağlandı.

---

### 🔵 Sürüm 7 - 8 (Sürüm Kodu Çakışması & Temiz Derleme)

1. **Google Play `6 sürüm kodu kullanıldı` Hatasının Çözümü**:
   - **Sorun**: Google Play Console `versionCode: 6` olan paketlerin daha önce yüklendiğini belirterek yeni AAB yüklemelerini reddetti.
   - **Kök Neden**: `android/local.properties` ve Gradle önbelleklerinde eski sürüm kodu (`6`) takılı kalmıştı.
   - **Çözüm**: `android/app/build.gradle.kts` içerisinde `versionCode = 8` ve `versionName = "1.0.7"` değerleri doğrudan Gradle konfigürasyonuna yazıldı, `gradlew.bat clean bundleRelease` komutu ile önbellekler temizlenerek imzalı paket üretildi.

---

### 🟣 Sürüm 9 (Görsel ve Profil Veri Senkronizasyonu)

1. **Profil Bilgileri ve QR Kod Senkronizasyonu (Görsel #1 Düzeltmesi)**:
   - **Sorun**: "Tek Seferlik Profil Oluşturma" (`Kayıt Ol ve Başla 🚀`) ekranında kullanıcının girdiği Ad Soyad, Bölüm ve Sınıf bilgileri, profil ekranındaki **NevGenç Kimliğim** kartında ve QR kodda varsayılan sabit test verileriyle (Ahmet Safa Zengin) uyuşmuyordu.
   - **Çözüm**: `ProfileScreen` ve `UserProfileModel` veri katmanı güncellendi. Kullanıcının kayıtta girdiği **Ad Soyad, E-posta, Bölüm ve Sınıf** bilgileri;
     - Profil üst başlığında,
     - **NevGenç Kimliğim** kartında,
     - QR Kod içeriğinde %100 birebir uyuşacak şekilde bağlandı.
2. **Giriş Ekranı Sabit Geometrik Teması (Görsel #2 Düzeltmesi)**:
   - **Sorun**: Uygulama içindeki ayarlardan Yıldızlı veya Açık tema seçildiğinde Giriş Ekranı da bu temalardan etkilenip değişiyordu.
   - **Çözüm**: `AnimatedThemeBackground` widget'ına `themeOverride` parametresi eklendi ve `LoginScreen` bileşeninde `themeOverride: AppTheme.geometric` kuralı kilitlendi. Giriş ekranı artık **daima 2 numaralı görseldeki Geometrik temada** kalır.

---

### 🔴 Sürüm 10 - 11 (Öncelikli Giriş Ekranı & Nihai Yayın Paket Derlemesi)

1. **Öncelikli Açılış Ekranı (LoginScreen First)**:
   - **Yapılan Değişiklik**: Uygulama başlatıldığında otomatik olarak doğrudan Anasayfaya geçilmesi engellendi. Uygulama açılışında **önce Giriş Ekranı (`LoginScreen`)** açılacak şekilde `lib/main.dart` dosyası güncellendi.
   - Giriş yapan veya Hızlı Profil oluşturan kullanıcının oturum bilgisi `AuthService` ile saklanır ve çıkış yapana (`_onLogout`) kadar hatırlanır.
2. **Takvim Ekranı Görev Silme Özellikleri**:
   - `CalendarScreen` içerisindeki görevler başlığına **`🧹 Tamamlananları Sil`** butonu ve görev kartlarının sağ tarafına tekil silme ikonları eklendi.
3. **Nihai Sürüm Derlemesi (`versionCode: 11` / `1.0.10+11`)**:
   - Projenin `pubspec.yaml`, `build.gradle.kts` ve `local.properties` dosyalarında sürüm bilgileri **`1.0.10+11`** olarak güncellendi.
### ⚪ Sürüm 12 (`versionCode: 24` / `1.0.23+24`) — Android 15 Edge-to-Edge Uyumlaştırması

1. **Uçtan Uca Ekran (Edge-to-Edge Display) Desteği ve Deprecated API Temizliği**:
   - **Gereksinim / Uyarı**: Google Play Console'da beliren *"Uçtan uca ekran tüm kullanıcılara gösterilmeyebilir"* ve *"Desteği sonlandırılmış API'ler kullanılıyor"* uyarıları çözüldü.
   - **Yapılan İşlem**:
     - `lib/main.dart`: `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` ve şeffaf durum/navigasyon çubuğu konfigürasyonları eklendi.
     - `android/app/src/main/res/values/styles.xml` ve `values-night/styles.xml`: `android:navigationBarColor` ve `android:statusBarColor` alanları `@android:color/transparent` yapıldı.
     - `MainActivity.kt`: `WindowCompat.setDecorFitsSystemWindows(window, false)` ile Android 15 pencere düzeni uyumlu hale getirildi.
2. **Google Play Fotoğraf/Video İzin Politikası Uyumlaştırması (Photo Picker)**:
   - **Gereksinim / Uyarı**: Google Play'in *"Fotoğraflar/videolar için alternatif sistem seçicileri kullanma"* Uyarısı/İhlali giderildi.
   - **Yapılan İşlem**: `AndroidManifest.xml` dosyasından gereksiz `READ_MEDIA_IMAGES` ve `READ_EXTERNAL_STORAGE` izinleri kaldırıldı. Flutter'ın `image_picker` sistemi varsayılan Android Photo Picker mekanizması ile sıfır izin sorunuyla çalışmaktadır.

### 🟢 Sürüm 13 (`versionCode: 25` / `1.0.24+25`) — Admin Topluluk Oluşturma ve Yönetim Modülü

1. **Admin Paneli Topluluklar Sekmesi & Yeni Topluluk Oluşturma**:
   - Admin Paneli (`AdminScreen`) içerisine 5. sekme olarak **`Topluluklar`** paneli eklendi.
   - **Topluluk Oluşturma Dialogu**: Admin kullanıcısı topluluk logosu (galeriden seçme / otomatik Supabase Storage yükleme), topluluk adı, kategori (Teknoloji, Mühendislik, Sosyal vb.) ve topluluk hakkında bilgisi (açıklama) girerek tek tıkla yeni topluluk oluşturabilir.
   - **Başkan Bağlama (Opsiyonel)**: Topluluk oluşturulurken isteğe bağlı olarak sistemdeki mevcut kullanıcılardan birine anında başkanlık tanımlanabilir.
   - **Yönetim İşlemleri**: Tüm toplulukları filtreleme/arama, topluluk düzenleme ve topluluk silme eylemleri Admin paneline eklendi.
2. **`SupabaseDataService` Veri Katmanı Güncellemeleri**:
   - `createCommunity`, `updateCommunityDetails`, `deleteCommunity` metotları Supabase veritabanı ile tam entegre edildi.

---

## 🛠️ 3. Değiştirilen Temel Dosyalar Haritası

| Dosya Yolu | Yapılan İşlemler |
| :--- | :--- |
| **`android/app/build.gradle.kts`** | `applicationId = "com.Nevgenc"`, `versionCode = 11`, `versionName = "1.0.10"` ve Keystore imza ayarları. |
| **`android/app/src/.../MainActivity.kt`** | `FLAG_SECURE` güvenlik kilitlenmesi kaldırıldı. |
| **`lib/main.dart`** | Uygulama açılışında öncelikli `LoginScreen` gösterimi, auth oturum takibi. |
| **`lib/screens/login_screen.dart`** | Tek Seferlik Profil Oluşturma dialogu, kilitli Geometrik tema entegrasyonu. |
| **`lib/screens/profile_screen.dart`** | Kullanıcının Ad, E-posta, Bölüm, Sınıf bilgilerinin NevGenç Kimliğim kartı ve QR kod ile senkronize edilmesi. |
| **`lib/screens/calendar_screen.dart`** | Görevleri tekil silme ve tamamlanan görevleri topluca silme (`Tamamlananları Sil`). |
| **`lib/widgets/animated_theme_background.dart`** | `themeOverride` desteği ile temaların istenilen ekranlarda sabitlenmesi. |

---

## 🚀 4. Google Play Console Yükleme ve İnceleme Rehberi

### 📤 Yükleme Adımları

1. Google Play Console hesabınıza giriş yapın.
2. **Üretim** veya **Test** kanallarından yeni bir sürüm oluşturun.
3. Projenin ana dizininde bulunan **`app-release.aab`** dosyasını yükleyin.

### ⚠️ Console Uyarıları ve Anlamları

Yükleme sonrasında sarı renkli uyarılar çıkabilir:

- **Kod gösterme dosyası (mapping.txt / deobfuscation)**: Supabase/Dio kütüphanelerinin çökmesini önlemek için R8 karartması kapalı tutulmaktadır. Bu nedenle haritalama dosyası gerekmez.
- **Yerel hata ayıklama sembolleri (Native symbols)**: Google Play Console'da çıkan *"Bu App Bundle yerel kod içeriyor ve hata ayıklama sembolleri yüklemediniz"* uyarısı. 
  > 📌 **Sonraki Sürüm Planı:** Bu uyarıyı tamamen kaldırmak için `android/app/build.gradle.kts` dosyasındaki `ndk { debugSymbolLevel = "NONE" }` satırı `debugSymbolLevel = "SYMBOL_TABLE"` (veya `"FULL"`) olarak güncellenecektir.

*(Her iki uyarı da bilgilendirme amaçlıdır, yayına veya incelemeye engel değildir.)*

1. **Kaydet**, **Sürümü İncele** ve **Üretime Yayınlamayı Başlat** butonlarına basarak uygulamanızı yayınlayabilirsiniz!
