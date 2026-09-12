# 📘 MOBİL UYGULAMA GELİŞTİRİCİ MASAÜSTÜ EL KİTABI & ÜRETİM REHBERİ
> **NevGenç Projesi Deneyimleriyle Baştan Sona Mimari, Güvenlik, Sürüm Hata Çözüm Günlüğü, UI/UX Standartları ve Play Store Yayınlama Kılavuzu**
> 
> *Son Güncelleme: Eylül 2026 | Sürüm: 2.0 (Genişletilmiş Master Baskı)*

---

## 📋 İÇİNDEKİLER

1. [Giriş, Geliştirici Manifestosu & Proje Felsefesi](#1-giriş-geliştirici-manifestosu--proje-felsefesi)
2. [NevGenç Sürüm Döngüsü & Derinlemesine Post-Mortem (v1 ➔ v13 Hata Analizi)](#2-nevgenç-sürüm-döngüsü--derinlemesine-post-mortem-v1-➔-v13-hata-analizi)
3. [Üretime Hazır Bir Mobil Uygulamada Olması Gereken 12 Temel Mimari Unsur](#3-üretime-hazır-bir-mobil-uygulamada-olması-gereken-12-temel-mimari-unsur)
4. [Güvenlik Prosedürleri ve `prosedür.md` 23 Altın Kuralı (Kod & SQL Örnekleriyle)](#4-güvenlik-prosedürleri-ve-prosedürmd-23-altın-kuralı-kod--sql-örnekleriyle)
5. [Tasarım, UI/UX ve Görsel Standartlar (Performans & Edge-to-Edge)](#5-tasarım-uiux-ve-görsel-standartlar-performans--edge-to-edge)
6. [Baştan Sona Google Play Store Yayınlama Yol Haritası & Scriptler](#6-baştan-sona-google-play-store-yayınlama-yol-haritası--scriptler)
7. [Hata Teşhis Tablosu (Troubleshooting Matrix) & Yayın Kontrol Listesi](#7-hata-teşhis-tablosu-troubleshooting-matrix--yayın-kontrol-listesi)

---

## 1. GİRİŞ, GELİŞTİRİCİ MANİFESTOSU & PROJE FELSEFESİ

Bir mobil uygulama geliştirmek sadece ekrana birkaç buton yerleştirip API çağrısı yapmaktan ibaret değildir. Fikir aşamasından Google Play Store / Apple App Store mağaza onayına, üretim ortamındaki (production) anlık çökmeleri engellemekten veritabanı güvenliğine kadar uzanan kapsamlı bir **yazılım mühendisliği disiplinidir**.

Bu el kitabı, **NevGenç** uygulamasının sıfırdan geliştirilmesi, Google Play Store'da yayınlanması ve 13+ sürüm boyunca karşılaşılan tüm teknik krizlerin (açılış çökmeleri, R8/ProGuard hataları, native Android kilitlenmeleri, izin ihlalleri, performans darboğazları) çözülmesiyle elde edilen somut tecrübeler ışığında kaleme alınmıştır.

### 💡 Temel Mühendislik İlkelerimiz:

1. **"Geliştirici Telefonunda Çalışıyor" Demek "Üretime Hazır" Demek Değildir:**
   Uygulamanın `flutter run` (debug mod) altında sorunsuz açılması; release modunda karartılmış (R8/ProGuard), obfuscate edilmiş bir APK/AAB olarak binlerce farklı Android/iOS cihaz mimarisinde çökmeyeceği anlamına gelmez.
2. **Varsayılan Olarak Reddet (Deny-by-Default):**
   Güvenlik arayüzdeki butonları gizleyerek değil; sunucu katmanında, API uçlarında ve veritabanı Row Level Security (RLS) kurallarında sağlanmalıdır.
3. **Kullanıcı Deneyimi (UX) Aynı Zamanda Performanstır:**
   60 FPS veremeyen, GPU'yu `BackdropFilter` gibi offscreen rasterization getiren efektlerle yoran ve kilitlenen bir uygulama görsel olarak ne kadar estetik olursa olsun mühendislik açısından başarısızdır.
4. **Hataları Sistemleştirmek:**
   Yaşanan her hata belgelenmeli, kök nedeni (root cause) izole edilmeli ve bir sonraki projede tekrarlanmayacak standart prosedürlere dönüştürülmelidir.

---

## 2. NEVGENÇ SÜRÜM DÖNGÜSÜ & DERİNLEMESİNE POST-MORTEM (v1 ➔ v13 HATA ANALİZİ)

NevGenç projesinde **v1.0.0+1** sürümünden **v1.0.24+25** sürümüne kadar adım adım karşılaşılan sorunlar, altında yatan kök nedenler ve uygulanan teknik çözümler:

---

### 🟢 Sürüm 1 - 5: Kuruluş, Paket İsmi & Keystore Sertifikasyon Krizleri

#### ❌ Sorun: Google Play Console AAB Paket Reddi ve Sertifika Uyumsuzluğu
* **Semptom:** Hazırlanan Android App Bundle (`.aab`) Play Console'a yüklendiğinde "Paket adı uyuşmuyor" ve "Geçersiz İmza (Keystore Mismatch)" hataları vererek derlemeyi reddediyordu.
* **Kök Neden:** 
  1. `AndroidManifest.xml` ve `build.gradle.kts` içinde varsayılan test paket adlarının kalması (`com.example.nevgenc`).
  2. Release build yapılırken Flutter'ın varsayılan debug keystore imzasını kullanması.
* **🔧 Uygulanan Çözüm:**
  - `android/app/build.gradle.kts` içerisinde `applicationId = "com.Nevgenc"` olarak sabitlendi.
  - Orijinal Google Play imza sertifikası `upload-keystore.jks` projenin `android/app/` dizinine taşındı.
  - `android/key.properties` yapılandırma dosyası oluşturularak Gradle release imzalama bloğuna bağlandı:

```kotlin
// android/app/build.gradle.kts
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
}
```

---

### 🟡 Sürüm 6: Açılış Çökmeleri (White Screen / Instant Crash) & Native Kilitlenmeler

Sürüm 6, projenin en kritik dönüm noktasıydı. Uygulama release modunda derlendiğinde açılışta anında kapanıyordu. Bu aşamada 5 ayrı bağımsız çökme nedeni tespit edilip çözülmüştür:

#### ❌ Sorun 1: R8 / ProGuard Kod Karartma Çökmesi (Reflection Removal)
* **Semptom:** `flutter run --release` çıktısı telefona yüklendiğinde uygulama logosuna tıklandığı an saliseler içinde kapanıyordu. Logcat üzerinde `ClassNotFoundException` ve `NoSuchMethodError` alınıyordu.
* **Kök Neden:** Android R8 derleyicisi (`isMinifyEnabled = true`), Supabase, Dio, Socket.IO ve Flutter Engine'in çalışma zamanı yansıma (reflection) ve JSON serileştirme sınıflarını "kullanılmayan ölü kod" sanarak derleme sırasında siliyordu.
* **🔧 Uygulanan Çözüm:** `android/app/build.gradle.kts` içerisinde karartma geçici olarak devreden çıkarıldı ve kararlı hale getirildi:

```kotlin
buildTypes {
    release {
        isMinifyEnabled = false
        isShrinkResources = false
        signingConfig = signingConfigs.getByName("release")
    }
}
```
*(İleride karartma açılmak istenirse `proguard-rules.pro` içerisine `-keep class com.supabase.** { *; }` kuralları eklenmelidir).*

#### ❌ Sorun 2: Native Kotlin `FLAG_SECURE` Ekran Çizim Kilitlenmesi
* **Semptom:** Samsung, Xiaomi ve Huawei gibi özelleştirilmiş Android arayüzüne (EMUI, MIUI, OneUI) sahip cihazlarda uygulama açılışta siyah ekranda kalıyor veya `SecurityException: Surface is locked` fırlatıyordu.
* **Kök Neden:** `MainActivity.kt` içerisine eklenmiş olan `WindowManager.LayoutParams.FLAG_SECURE` bayrağı, ekran görüntüsü almayı engellerken bazı cihazların donanımsal arayüz oluşturucusunu kilitliyordu.
* **🔧 Uygulanan Çözüm:** `MainActivity.kt` içerisinden `FLAG_SECURE` bayrağı tamamen temizlendi:

```kotlin
// MainActivity.kt - DÜZELTİLMİŞ KOD
package com.Nevgenc

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    // FLAG_SECURE kaldırıldı, pencere çizimi serbest bırakıldı
}
```

#### ❌ Sorun 3: Dart Statik `Supabase.instance.client` İlklendirme Hatası (`StateError`)
* **Semptom:** Uygulama başlatılırken `Uncaught Error: Bad state: Supabase instance has not been initialized` hatası vererek çökmekteydi.
* **Kök Neden:** `main.dart` dosyasının en üst seviyesinde (top-level) tanımlanan `final supabase = Supabase.instance.client;` ifadesi, henüz `main()` fonksiyonu çalışıp `Supabase.initialize(...)` tamamlanmadan önce Dart sanal makinesi (VM) tarafından belleğe yüklenmeye çalışıyordu.
* **🔧 Uygulanan Çözüm:** Statik `final` değişken tanımı silindi, Supabase ilklendirmesi bittikten sonra erişilen lazy-getter yapısına geçildi:

```dart
// YANLIŞ: main() öncesi devreye girer ve patlar
// final supabase = Supabase.instance.client;

// DOĞRU: Çağrıldığı anda geçerli istemciyi döner
SupabaseClient get supabase => Supabase.instance.client;
```

#### ❌ Sorun 4: AuthGate Sonsuz Yükleme Ekranı Kilitlenmesi (Infinite Spinner)
* **Semptom:** Cihazın interneti zayıf olduğunda veya yerel hafızadan token okunurken bir istisna oluştuğunda uygulama sonsuz dönen `CircularProgressIndicator` ekranında takılı kalıyordu.
* **Kök Neden:** Oturum kontrol fonksiyonunda hata oluştuğunda `_checking = false` yapacak bir `finally` veya `catch` bloğunun bulunmaması.
* **🔧 Uygulanan Çözüm:** Oturum sorgusu `try-catch-finally` bloğu ile sarmalandı. Hata oluşsa dahi yükleme durumu kapatılarak kullanıcı güvenli şekilde `LoginScreen`'e düşürüldü:

```dart
Future<void> _checkAuthStatus() async {
  try {
    final session = supabase.auth.currentSession;
    if (session != null) {
      _isAuthenticated = true;
    }
  } catch (e) {
    debugPrint('Auth kontrol hatası: $e');
    _isAuthenticated = false;
  } finally {
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }
}
```

#### ❌ Sorun 5: `FlutterSecureStorage` Android KeyStore Hatası (`GeneralSecurityException`)
* **Semptom:** Android işletim sistemi güncellendiğinde veya cihaz kilit şifresi değiştirildiğinde uygulamanın secure storage okurken çökmesi.
* **Kök Neden:** Android KeyStore donanımsal şifreleme anahtarlarının geçersiz kalması (corrupted keystore entry).
* **🔧 Uygulanan Çözüm:** `token_service.dart` içerisinde `AndroidOptions` yapılandırmasına `resetOnError: true` parametresi eklendi:

```dart
final _storage = const FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true, // KeyStore bozulursa güvenli sıfırla, çökme!
  ),
);
```

---

### 🔵 Sürüm 7 - 8: Sürüm Kodu Çakışması & Gradle Önbellek Temizliği

#### ❌ Sorun: Google Play Console "versionCode 6 Zaten Kullanıldı" Reddi
* **Semptom:** `pubspec.yaml` dosyasında `version: 1.0.7+8` yazılmasına rağmen Play Store yüklenen paketin `versionCode` değerini hâlâ `6` olarak görüp reddediyordu.
* **Kök Neden:** `android/local.properties` ve Gradle önbelleklerinde (cache) eski sürüm kodu olan `6` değerinin takılı kalması.
* **🔧 Uygulanan Çözüm:** `android/app/build.gradle.kts` içerisinde `versionCode` ve `versionName` doğrudan Gradle yapılandırmasına yazıldı ve önbellekler temizlenerek paket derlendi:

```bash
cd android
./gradlew clean
cd ..
flutter build appbundle --release
```

---

### 🟣 Sürüm 9 - 11: Profil Veri Senkronizasyonu & Öncelikli Açılış Ekranı

#### ❌ Sorun 1: Profil ve QR Kodda Sabit Test Verilerinin Kalması
* **Semptom:** Kullanıcı kayıt olurken kendi adını girmesine rağmen Profil ekranındaki **NevGenç Kimliğim** kartında ve QR kodda varsayılan sabit test verilerinin ("Ahmet Safa Zengin") görünmesi.
* **Kök Neden:** `ProfileScreen` widget'ının `AuthService`'ten dönen dynamic user verisini modelleyememesi ve varsayılan mock string'leri göstermesi.
* **🔧 Uygulanan Çözüm:** `UserProfileModel` veri katmanı güncellendi. Kullanıcının kayıtta girdiği Ad, Soyad, E-posta, Bölüm ve Sınıf bilgileri hem kimlik kartına hem de QR kod içeriğine birebir dinamik bağlandı.

#### ❌ Sorun 2: Giriş Ekranının Dinamik Temadan Etkilenip Görünümünün Bozulması
* **Semptom:** Kullanıcı uygulama içindeki ayarlardan Yıldızlı veya Açık tema seçtiğinde Giriş Ekranı (`LoginScreen`) da etkilenip markanın geometrik tasarım dilini bozuyordu.
* **🔧 Uygulanan Çözüm:** `AnimatedThemeBackground` bileşenine `themeOverride` parametresi eklendi ve `LoginScreen` bileşeninde `themeOverride: AppTheme.geometric` kuralı kilitlendi.

---

### ⚪ Sürüm 12: Android 15 Edge-to-Edge Uyumlaştırması & Medya İzin İhlalleri

#### ❌ Sorun 1: Google Play Console "Uçtan Uca Ekran (Edge-to-Edge)" Uyarısı
* **Semptom:** Google Play Console üzerinde Android 15 (API level 35) target SDK zorunlulukları uyarısı belirmesi.
* **🔧 Uygulanan Çözüm:**
  1. `lib/main.dart` içerisine uçtan uca ekran yapılandırması eklendi:
     ```dart
     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
     SystemChrome.setSystemUIOverlayStyle(
       const SystemUiOverlayStyle(
         statusBarColor: Colors.transparent,
         navigationBarColor: Colors.transparent,
       ),
     );
     ```
  2. `android/app/src/main/res/values/styles.xml` içinde navigasyon ve durum çubuğu renkleri şeffaf yapıldı:
     ```xml
     <item name="android:navigationBarColor">@android:color/transparent</item>
     <item name="android:statusBarColor">@android:color/transparent</item>
     ```
  3. `MainActivity.kt` içerisine `WindowCompat.setDecorFitsSystemWindows(window, false)` eklendi.

#### ❌ Sorun 2: Google Play Fotoğraf/Video İzin Politikası İhlali
* **Semptom:** Google Play Console'dan "Gereksiz geniş medya depolama izinleri kullanımı (`READ_MEDIA_IMAGES`)" uyarısı/ihlali.
* **Kök Neden:** `AndroidManifest.xml` içinde eski izin deklarasyonlarının kalması.
* **🔧 Uygulanan Çözüm:** Manifest dosyasından tüm geniş depolama izinleri silindi. Android 13+ ile gelen ve izin almadan güvenli dosya seçimi sağlayan native Android **Photo Picker** mimarisine (`image_picker` paketi üzerinden) geçildi.

---

### 🟢 Sürüm 13: Admin Topluluk Yönetimi Entegrasyonu
* **Geliştirme:** Admin Paneli (`AdminScreen`) içerisine Topluluk Oluşturma, Düzenleme, Silme ve Supabase Storage entegrasyonu ile logo yükleme modülü eklendi.

---

## 3. ÜRETİME HAZIR BİR MOBİL UYGULAMADA OLMASI GEREKEN 12 TEMEL MİMARİ UNSUR

```
┌────────────────────────────────────────────────────────────────────────┐
│                   ÜRETİME HAZIR MOBİL UYGULAMA MİMARİSİ               │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Katmanlı Temiz Mimari (UI ➔ Notifier ➔ Service ➔ Data Model)       │
│ 2. Güvenli Oturum & Token Yönetimi (Auto-Refresh & Expire Handlers)     │
│ 3. Çevrimdışı (Offline) Önbellekleme (Cache-First / Sync Engine)       │
│ 4. Yapılandırılmış Global Hata Yönetimi (runZonedGuarded)              │
│ 5. GDPR / KVKK Uyumlu Hesap & Veri Silme Akışı (Cascade Delete)        │
│ 6. Dynamic Theme & Edge-to-Edge Uyumlu Responsive UI                   │
│ 7. Anlık Bildirim (Push Notification) Altyapısı (FCM Entegrasyonu)     │
│ 8. Otomatik Uygulama İçi Güncelleme (Force Update / Min Version)       │
│ 9. İzole Edilebilir Test Kapsamı (Unit & Mocking)                       │
│ 10. Canlı Analiz ve Çökme Takibi (Crashlytics & Log Management)         │
│ 11. Medya ve Görsel Optimizasyonu (WebP & Dynamic Caching)              │
│ 12. Ölü Kod & Bağımlılık Temizliği (Pubspec & Gradle Hygiene)          │
└────────────────────────────────────────────────────────────────────────┘
```

### 1. Katmanlı Temiz Mimari (Clean Architecture)
* **Kural:** UI dosyaları (Screen/Widget) asla doğrudan SQL/API sorgusu çalıştırmamalıdır.
* **Klasör Yapısı:**
  - `lib/models/`: JSON serileştirme ve veri yapıları (`fromMap`, `toMap`).
  - `lib/services/`: HTTP, Supabase, Firebase, Secure Storage çağrıları.
  - `lib/notifiers/` veya `lib/providers/`: Ekran durumunu saklayan state sınıfları.
  - `lib/screens/`: Sadece UI düzenini çizen ekranlar.
  - `lib/widgets/`: Yeniden kullanılabilir atomik bileşenler (Button, Card vb.).

### 2. Güvenli Oturum Saklama & Yenileme (Session Lifecycle)
* Token'lar ham `SharedPreferences` yerine `FlutterSecureStorage` (Android Keystore / iOS Keychain) içinde saklanmalıdır.
* Kullanıcı uygulamayı açtığında Access Token süresi dolmuşsa uygulama çökmemeli; Refresh Token ile arka planda sessizce yeni token alınmalıdır.

### 3. Çevrimdışı (Offline) Önbellekleme ve Ağ Yönetimi
* İnternet kesildiğinde uygulamanın beyaz ekran vermesi kabul edilemez.
* `connectivity_plus` paketi ile ağ durumu dinlenmeli; internet yoksa veriler yerel önbellekten (SharedPreferences / Hive) sunulmalı ve ekrana "Çevrimdışı Modadasınız" bildirimi verilmelidir.

### 4. Yapılandırılmış Global Hata Yönetimi (Crash Prevention)
* Uygulama genelinde yakalanmayan tüm istisnalar `runZonedGuarded` ile yakalanmalıdır:

```dart
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(url: '...', anonKey: '...');
    
    // Flutter çerçevsel hatalarını yakala
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // Crashlytics'e logla
    };

    runApp(const NevGencApp());
  }, (Object error, StackTrace stackTrace) {
    debugPrint('ZonedGuard Yakalanmayan Hata: $error');
    // Servis hatasını kaydet
  });
}
```

### 5. Yasal Uyumlu Hesap Silme Akışı (Account Deletion)
* **Google Play & App Store Zorunluluğu:** Kullanıcı girişi içeren her uygulamada, kullanıcının hesabını ve tüm verilerini uygulama içinden tek tıkla silebileceği bir buton bulunmak **zorundadır**.

---

## 4. GÜVENLİK PROSEDÜRLERİ VE `prosedür.md` 23 ALTIN KURALI

`prosedür.md` dokümanımız, bir uygulamanın canlıya çıkmadan önce geçmesi gereken **23 aşamalı güvenlik denetimini** tanımlar:

### 🛡️ 23 Altın Güvenlik Maddesi, Riskler ve Uygulama Kodları:

#### 1. İstemci Kodunda Gizli Değer Saklamama
* **Risk:** Mobil APK/AAB dosyaları kolayca decompile edilebilir. Koda yazılan `stripe_secret_key`, `firebase_admin_key` veya `database_password` anında çalınır.
* **Kural:** İstemcide sadece herkese açık (public/anon) anahtarlar durabilir. Gizli işlemler Edge Function veya sunucu üzerinden geçmelidir.

#### 2. Git Geçmişindeki Sızıntıların Temizlenmesi
* **Risk:** `.env` veya `serviceAccount.json` dosyasını `.gitignore`'a eklemek geçmiş commit'lerdeki verileri silmez.
* **Kural:** Sızan anahtar derhal **İPTAL EDİLMELİ (Revoked)** ve yenisi üretilmelidir. Git geçmişi `git filter-repo` ile temizlenmelidir.

#### 3. Veritabanı Erişim Kuralları (Row Level Security - RLS)
* **Risk:** RLS açık değilse kötü niyetli bir kullanıcı Supabase REST API'sine istek atarak tüm veritabanını silebilir veya okuyabilir.
* **Kural:** Varsayılan kural **REDDET (Deny All)** olmalıdır. 

```sql
-- Supabase RLS Altın Şablonu
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Herkes profil okuyabilir
CREATE POLICY "Public profiles are viewable by everyone" 
ON public.user_profiles FOR SELECT USING (true);

-- Sadece profil sahibi kendi verisini güncelleyebilir
CREATE POLICY "Users can update own profile" 
ON public.user_profiles FOR UPDATE 
USING (auth.uid() = user_id);
```

#### 4. Sunucu Taraflı Yetki Kontrolü (Role-Based Access Control)
* **Risk:** Admin butonunun Flutter UI'da `if (user.isAdmin)` ile gizlenmesi güvenlik değildir. Saldırgan API'ye direkt cURL isteği atabilir.
* **Kural:** Sunucu / Edge Function veya SQL RLS politikası isteği atan kullanıcının rolünü doğrulamalıdır.

#### 5. Rate Limiting (Hız Sınırı)
* **Risk:** Giriş, kayıt ve SMS/AI uçlarına sınır konulmazsa kaba kuvvet (brute-force) saldırısı ile hesaplar ele geçirilir veya bulut faturası şişer.
* **Kural:** Giriş için 15 dakikada maks 5 deneme; SMS/AI için saatte maks 3 deneme sınırı getirilmelidir.

#### 6. Sunucu Taraflı Girdi Doğrulaması (Input Validation)
* **Risk:** Fiyat, miktar, rol veya bakiye gibi kritik alanlar istemciden gelen değere güvenilerek veritabanına yazılmamalıdır.
* **Kural:** İstemci veriyi talep eder, hesaplama ve tip/uzunluk kontrolü sunucuda yapılır.

#### 7. Güvenli Dosya Yükleme
* **Risk:** Kullanıcının resim yerine `.php` veya `.html` yükleyip sunucuda çalıştırması veya 500 MB dosya yükleyip depolamayı doldurması.
* **Kural:** Sunucu tarafında maks boyut sınırı (ör. 5 MB), MIME türü kontrolü yapılmalı ve dosya adı rastgele `UUID` ile değiştirilmelidir.

#### 8. CORS Yapılandırması
* **Risk:** `Access-Control-Allow-Origin: *` olarak bırakılırsa herhangi bir web sitesi kullanıcının tarayıcısı üzerinden sizin API'nize yetkili istek atabilir.
* **Kural:** İzin verilen domainler sadece kendi mobil/web adreslerinizle sınırlandırılmalıdır.

#### 9. HTTP Güvenlik Başlıkları
* **Kural:** Web/API yanıtlarında `Strict-Transport-Security`, `Content-Security-Policy`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff` başlıkları bulunmalıdır.

#### 10. HTTPS ve SSL Pinning Zorunluluğu
* **Kural:** Tüm API uçları `https://` olmalı, HTTP istekleri kalıcı 301 ile HTTPS'e yönlendirilmeli ve çerezler `Secure` bayrağı taşımalıdır.

#### 11. Güçlü Şlifre Hashing Standartları
* **Risk:** Şlifrelerin düz metin veya MD5/SHA1 ile saklanması.
* **Kural:** Şlifreler `bcrypt`, `Argon2` veya hazır OAuth/Supabase Auth sağlayıcıları ile tuzlanarak (salt) saklanmalıdır.

#### 12. Güvenli Oturum Yönetimi (Session Cookies)
* **Kural:** Web tarafında token'lar `localStorage` yerine `HttpOnly`, `Secure`, `SameSite=Strict` çerezlerde tutulmalıdır.

#### 13. Hata Mesajlarında Detay Sızdırmama
* **Risk:** `Internal Server Error: Table public.users does not have column xyz` gibi hataların kullanıcıya gösterilmesi sistem mimarisini ifşa eder.
* **Kural:** Kullanıcıya "Bir hata oluştu (Kod: ERR-502)" gösterilmeli, detaylar sunucu loguna yazılmalıdır.

#### 14. Log Maskeleme (Sensitive Log Sanitization)
* **Risk:** `debugPrint('User data: $response')` yazıldığında şifre veya kart bilgilerinin terminal loglarına düşmesi.
* **Kural:** Hassas veriler maskelenmelidir:

```dart
String maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2) return '***';
  final name = parts[0];
  return '${name[0]}***@${parts[1]}';
}
```

#### 15. SQL Injection Koruması
* **Kural:** Sorgular asla string birleştirme (`"SELECT * FROM users WHERE id = '" + id + "'"` ) ile kurulmamalı, daima ORM veya parametreli sorgu kullanılmalıdır.

#### 16. XSS (Cross-Site Scripting) Koruması
* **Kural:** Kullanıcıdan gelen metinler (ör. yorumlar, isimler) doğrudan HTML/Webview içine basılmamalı, sanitize edilmelidir.

#### 17. Webhook İmza Doğrulaması
* **Kural:** Ödeme veya bildirim webhook uçlarına gelen isteklerin ham gövdesi (raw body) HMAC SHA-256 imzası ile doğrulanmalıdır.

#### 18. Admin Yollarının Kilitlenmesi
* **Kural:** `/admin` paneli ve debug uçları sadece yetkili admin rolüne açık olmalı, test amaçlı açılan dummy uçlar release derlemesinde silinmelidir.

#### 19. Bağımlılık Güvenlik Taraması (Dependency Audit)
* **Kural:** Bilinen güvenlik açığı bulunan paketler (`npm audit` / `flutter pub audit`) güncellenmeli, bakımsız paketler projeden atılmalıdır.

#### 20. Otomatik Veri Yedekleme
* **Kural:** Veritabanı günlük otomatik yedeklemeleri açık olmalı ve geri yükleme (restore) testleri önceden denenmelidir.

#### 21. Gerçek Hesap Silme Akışı (Cascade Delete)
* **Kural:** Kullanıcı hesabını sildiğinde `users` tablosundaki kaydı silinirken ilişkili fotoğrafları (storage) ve diğer tablodaki verileri de silinmelidir (`ON DELETE CASCADE`).

#### 22. Maliyet ve Bütçe Limiti Koruması
* **Risk:** Sonsuz döngüye giren bir Cloud Function veya bot saldırısı yüzünden binlerce dolarlık bulut faturası çıkması.
* **Kural:** Firebase/Supabase/AWS üzerinde %50, %80 ve %100 bütçe uyarıları (Budget Alerts) kurulmalıdır.

#### 23. Penetrasyon ve IDOR (Insecure Direct Object Reference) Testleri
* **Kural:** Test hesabıyla oturum açıp başkasına ait bir `user_id` ile profil güncelleme veya veri okuma isteği atılarak sistemin engelleyip engellemediği doğrulanmalıdır.

---

## 5. TASARIM, UI/UX VE GÖRSEL STANDARTLAR (PERFORMANS & EDGE-TO-EDGE)

Uygulamanın görsel estetiği kullanıcıda kalite algısını oluştururken, yazılımsal performansı uygulamanın akıcılığını belirler.

### 🎨 Renk Paleti ve Temalama İlkeleri
* Generic renkler (`Colors.red`, `Colors.blue`) yerine projenize özel HSL/HEX renk paletleri tanımlayın.
* **Sabit Tema Kilitleri:** Giriş/Kayıt gibi marka kimliğini yansıtan ekranlarda kullanıcının cihaz temasına göre görünümün bozulmaması için `themeOverride` kullanın:

```dart
// LoginScreen örneği
AnimatedThemeBackground(
  themeOverride: AppTheme.geometric, // Tema değişikliklerinden etkilenmez
  child: LoginBody(),
);
```

---

### ⚡ Performans Düşmanı UI Tuzakları: `BackdropFilter` (Glassmorphic)

Glassmorphism (cam efekti) mobil uygulamalarda son derece estetik görünür ancak **mobil performansın en büyük tuzaklarından biridir**.

#### Neden Performans Katilidir?
`BackdropFilter`, Flutter render motorunun (Impeller/Skia) her karede (frame) ekrandaki alt katmanları yakalayıp GPU üzerinde bulanıklaştırma (blur) işlemi yapmasını zorunlu kılar (**Offscreen Rasterization**). Özellikle animasyonlu veya kaydırılabilir listelerde (ListView/GridView) FPS'in 60'tan 15-20 seviyelerine düşmesine ve cihazın ısınmasına sebep olur.

#### 🔧 Doğru ve Performanslı Cam Efekti Çözümü:
`BackdropFilter` kullanmak yerine saydam renkli `Container` + hafif border (sınır) ve yumuşak gölge kombinasyonu kullanın:

```dart
// YANLIŞ & PERFORMANSSIZ (GPU YORAN YÖNTEM)
ClipRRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(color: Colors.white.withOpacity(0.2), child: content),
  ),
);

// DOĞRU & PERFORMANSLI (60 FPS AKICI YÖNTEM)
Container(
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ],
  ),
  child: content,
);
```

---

### 📱 Uçtan Uca Ekran (Edge-to-Edge) Uyum Standartları
Android 15 ve iOS 17+ cihazlarda uygulamanın içeriği ekranın en üst ve en alt çubuklarının arkasına kadar uzanmalıdır.
* Ekran tasarımlarınızda içeriğin çentik (notch) veya navigasyon çubuğu altında kalmaması için daima `SafeArea` kullanın.
* Sistem çubuklarını transparan yaparak uygulamanızın ekran alanını maksimuma çıkarın.

---

## 6. BAŞTAN SONA GOOGLE PLAY STORE YAYINLAMA YOL HARİTASI & SCRİPTLER

Ham bir Flutter projesini Google Play Store'da yayınlama süreci 5 ana adımdan oluşur:

```
┌─────────────┐     ┌────────────────┐     ┌──────────────────┐     ┌──────────────────┐     ┌──────────────┐
│ GitHub Repo │ ➔ │  Yerel Test &  │ ➔ │ Keystore Release │ ➔ │ Android App      │ ➔ │ Play Console │
│   Klonlama  │     │   Çökme Fix    │     │   İmzalama       │     │ Bundle (.aab)    │     │  Yayınlama   │
└─────────────┘     └────────────────┘     └──────────────────┘     └──────────────────┘     └──────────────┘
```

### Adım 1: Release Keystore İmza Anahtarı Üretimi
Terminal üzerinden aşağıdaki komut çalıştırılarak `upload-keystore.jks` dosyası üretilir:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Adım 2: `key.properties` Yapılandırması
`android/key.properties` dosyası oluşturulur:
```properties
storePassword=KEYSTORE_SIFRENIZ
keyPassword=KEY_SIFRENIZ
keyAlias=upload
storeFile=../upload-keystore.jks
```

### Adım 3: Sürüm Kodu Artırımı (`pubspec.yaml`)
Her yeni paket yüklemesinde `versionCode` (artı işaretinden sonraki rakam) mutlaka artırılmalıdır:
```yaml
version: 1.0.24+25 # 1.0.24 versionName, 25 ise versionCode'dur
```

### Adım 4: Otomatik Paket Derleme Scripti (`build_aab.ps1`)
Projenizin kök dizininde temiz derleme yapan PowerShell scripti:

```powershell
# build_aab.ps1
Write-Host "🧹 Önbellekler temizleniyor..." -ForegroundColor Yellow
flutter clean
flutter pub get

Write-Host "📦 Release Android App Bundle (.aab) derleniyor..." -ForegroundColor Green
flutter build appbundle --release --no-tree-shake-icons

Write-Host "✅ Derleme Tamamlandı!" -ForegroundColor Green
Write-Host "📍 Çıktı Konumu: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Cyan
```

### Adım 5: Google Play Console Yükleme ve İnceleme Formları
1. **Play Console** ➔ Uygulamanızı seçin ➔ **Üretim** veya **Dahili Test** sekmesine girin.
2. Derlenen `app-release.aab` dosyasını sürükleyip yükleyin.
3. **Veri Güvenliği Formu (Data Safety):** Hangi verileri topladığınızı (E-posta, İsim vb.) eksiksiz beyan edin.
4. **Gizlilik Politikası URL'i:** Geçerli bir `https://` gizlilik politikası bağlantısı ekleyin.
5. **Sürümü İncelemeye Gönder:** İnceleme genellikle 1-24 saat sürer ve uygulamanız mağazada canlıya geçer! 🚀

---

## 7. HATA TEŞHİS TABLOSU (TROUBLESHOOTING MATRIX) & YAYIN KONTROL LİSTESİ

### 🔍 Karşılaşılan Hatalar Teşhis Tablosu

| Hata / Semptom | Olası Kök Neden | Hızlı Çözüm Adımı |
| :--- | :--- | :--- |
| **Release'de Açılışta Çökme** | R8/ProGuard reflection silinmesi | `build.gradle.kts` içinde `isMinifyEnabled = false` yapın. |
| **Siyah Ekran / Surface Error** | Native `FLAG_SECURE` kısıtlaması | `MainActivity.kt`'den `FLAG_SECURE` satırını silin. |
| **StateError: Client not init** | Statik init sırası hatası | `final supabase = ...` tanımını lazy-getter yapın. |
| **Sonsuz Yükleme Simgesi** | Auth kontrolünde `catch` eksikliği | Oturum sorgusunu `try-catch-finally` bloğuna alın. |
| **SecureStorage Exception** | Keystore bozulması | `AndroidOptions(resetOnError: true)` ekleyin. |
| **Console versionCode Reddi** | Önbellekte eski sürüm kalması | `android/` klasöründe `./gradlew clean` çalıştırın. |
| **FPS Düşüşü / Isınma** | Yoğun `BackdropFilter` kullanımı | Cam efektini saydam `Container` + `Border` yapın. |
| **Medya İzni İhlal Reddi** | Manifest'te gereksiz izin kalması | `READ_MEDIA_IMAGES` iznini kaldırıp Photo Picker kullanın. |

---

### 📋 Geliştiricinin Yayına Çıkış Kontrol Listesi (Pre-Release Checklist)

- [ ] **Paket Kimliği:** `applicationId` ("com.Nevgenc") doğru mu?
- [ ] **Sürüm Kodu:** `versionCode` bir önceki sürümden yüksek mi?
- [ ] **Keystore Imzası:** Release derlemesi `upload-keystore.jks` ile imzalandı mı?
- [ ] **Açılış Testi:** Real cihazda release APK/AAB açılışı test edildi mi?
- [ ] **Veritabanı RLS:** Tüm tablolarda RLS kapıları kapalı mı?
- [ ] **Gizli Anahtarlar:** Koda gömülü secret/token kaldırıldı mı?
- [ ] **Hesap Silme:** KVKK/GDPR uyumlu hesap silme butonu aktif mi?
- [ ] **Edge-to-Edge:** Durum çubuğu transparan ve `SafeArea` koruması var mı?
- [ ] **Gereksiz İzinler:** Manifest'ten gereksiz medya izinleri silindi mi?
- [ ] **UI Performansı:** Sayfalardaki ağır `BackdropFilter` widget'ları temizlendi mi?

---
*Bu el kitabı, mobil yazılım geliştirme süreçlerinde kalite standartlarını korumak, üretilen uygulamaları sistemleştirmek ve geçmiş hatalardan ders çıkararak kusursuz projeler inşa etmek için referans başucu rehberi olarak hazırlanmıştır.* 🌟
