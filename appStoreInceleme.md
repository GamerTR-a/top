# NevGenç — App Store Uygunluk Raporu ve Düzeltme Planı

**Tarih:** 2026-09-27 · **İncelenen sürüm:** 1.0.28+29 · **Bundle ID:** `com.newgenc.app`

Bu rapor, iOS sürümünün App Store incelemesinden (App Review) geçip geçemeyeceğini
değerlendirir. Önce Apple'ın kabul şartları ve en sık ret nedenleri listelenir. Ardından
uygulamanın kaynak kodu bu kurallara göre tek tek kontrol edilir ve her bulgu için
somut düzeltme önerilir.

---

## 0. Yönetici özeti

**Sonuç:** Şu hâliyle gönderilirse **reddedilme olasılığı yüksek.** 4 bulgu doğrudan ret
nedeni. 1 bulgu (CI/imzalama) derlemenin App Store Connect'e hiç ulaşmamasına yol
açabilir. Düzeltmelerin çoğu küçük; toplam iş yükü tahminen 1–2 gün.

| # | Bulgu | Kural | Önem | Tahmini iş |
|---|---|---|---|---|
| B1 | Kampüs Cepte, Sakarya dışında kilitleniyor | 2.1 | 🔴 Ret | 1–2 saat |
| B2 | "Yakında geliyor" menü öğeleri | 2.2 / 2.1 | 🔴 Ret | 15 dk |
| B3 | "Tetris" markasının kullanımı | 4.1 / 5.2.1 | 🔴 Ret | 15 dk |
| B4 | Kullanıcı engelleme ve kullanım şartları onayı yok | 1.2 | 🔴 Ret | 3–5 saat |
| B5 | Codemagic'te imzalama ve gizli dosyalar tanımsız | Teknik | 🔴 Derleme yok | 1 saat |
| B6 | Demo hesap gerekli (.edu kaydı) | 2.1 | 🟠 Ret (verilmezse) | 15 dk |
| B7 | Doğum tarihi zorunlu | 5.1.1(ii) | 🟠 Olası ret | 10 dk |
| B8 | iPad desteği açık | 2.3.3 / 4.0 | 🟠 Olası ret | 10 dk |
| B9 | Gizlilik etiketleri ve gizlilik bildirimi | 5.1.2 | 🟠 Olası ret | 30 dk |
| B10 | Canlı veritabanında bekleyen SQL'ler | 5.1.1(v) / 2.1 | 🟠 Olası ret | 10 dk |
| B11 | GitHub Actions iOS iş akışı | Teknik | 🟡 CI hatası | 30 dk |
| B12 | iOS SDK sürüm şartı | Teknik | 🟡 Yükleme reddi | CI ayarı |
| B13 | Yatay ekran desteği | 4.0 | 🟡 Görsel hata | 5 dk |
| B14 | Bildirim izninin açılışta istenmesi | 4.5.4 / UX | 🟡 Öneri | 30 dk |
| B15 | Arka plan bildirim modu | 2.5.4 | 🟡 Öneri | 5 dk |

---

## 1. App Store kabul şartları ve sık ret nedenleri

Apple'ın *App Review Guidelines* belgesi beş ana bölümden oluşur. Aşağıda bölüm bölüm,
pratikte en çok ret sebebi olan maddeler listelenmiştir.

### 1.1 Güvenlik (Safety — Bölüm 1)
- **1.1 Uygunsuz içerik:** Nefret söylemi, şiddet, müstehcenlik, yanıltıcı bilgi yasak.
- **1.2 Kullanıcı tarafından üretilen içerik (UGC):** Kullanıcıların içerik paylaşabildiği
  her uygulamada **dört şey zorunlu:**
  1. Uygunsuz içeriği filtreleme yöntemi,
  2. İçeriği şikayet etme mekanizması ve şikayetlere zamanında (pratikte 24 saat) müdahale,
  3. Kötüye kullanan kullanıcıları **engelleme** imkânı,
  4. Yayımlanmış iletişim bilgisi.

  Ayrıca kullanıcılar, uygunsuz içeriğe "sıfır tolerans" olduğunu belirten kullanım
  şartlarını (EULA) kabul etmelidir.
- **1.4 Fiziksel zarar:** Sağlık, ilaç veya tehlikeli aktivite içerikleri özel dikkat ister.
- **1.5 Geliştirici bilgisi:** Uygulama ve destek sayfasında kolay ulaşılan iletişim bilgisi.
- **1.6 Veri güvenliği:** Kullanıcı verisi uygun şekilde korunmalı.

### 1.2 Performans (Performance — Bölüm 2)
- **2.1 Uygulamanın eksiksiz olması:** Ret nedenlerinin yaklaşık %40'ı buradan gelir.
  - Çökme, donma, boş ekran, çalışmayan buton veya bağlantı,
  - Sunucu kapalı olduğu için içeriksiz ekranlar,
  - Giriş gerektiren uygulamada **çalışan demo hesap verilmemesi**,
  - Konum, donanım veya bölge nedeniyle incelenemeyen özellikler için açıklama
    ya da demo videosu eklenmemesi.
- **2.2 Beta, demo, deneme:** "Yakında", "test", "beta" veya yer tutucu içerik barındıran
  özellikler kabul edilmez. Beta testler TestFlight'tan yapılmalıdır.
- **2.3 Doğru meta veriler:**
  - 2.3.1: Gizli veya açıklanmamış özellik olmamalı.
  - 2.3.3: Ekran görüntüleri gerçek uygulamayı göstermeli. **iPad destekleniyorsa iPad
    ekran görüntüleri zorunlu.**
  - 2.3.7: Uygulama adı en fazla 30 karakter olmalı. Anahtar kelimelerde rakip veya
    marka adı kullanılmamalı.
  - 2.3.8: İkon ve görseller tüm yaş gruplarına uygun olmalı.
  - 2.3.10: Başka platformlardan (Android, Google Play) söz edilmemeli.
- **2.4 Donanım uyumluluğu:** iPhone uygulaması iPad'de de çalışabilmelidir (2.4.1).
- **2.5 Yazılım gereksinimleri:**
  - 2.5.1: Yalnızca herkese açık API'ler kullanılmalı.
  - 2.5.2: Uygulama sonradan kod indirip çalıştırmamalı.
  - 2.5.4: Arka plan modları yalnızca amacına uygun kullanılmalı.
  - 2.5.6: Web içeriği WebKit ile gösterilmeli.

### 1.3 İş modeli (Business — Bölüm 3)
- **3.1.1:** Dijital içerik, abonelik veya özellik kilidi açma yalnızca uygulama içi
  satın alma (IAP) ile satılabilir. Harici ödeme sayfasına yönlendirme yasaktır.
- **3.1.3(e) / 3.1.5:** Fiziksel ürünler, gerçek dünya hizmetleri ve kuponlar IAP dışında
  kalır.
- **3.2.2:** Kullanıcıyı başka uygulamaları indirmeye veya puan vermeye teşvik karşılığında
  ödül vermek yasaktır.

### 1.4 Tasarım (Design — Bölüm 4)
- **4.0:** Arayüz, desteklenen tüm cihaz ve yönlendirmelerde düzgün görünmeli.
- **4.1 Taklit:** Başka uygulamaların adı, ikonu veya markası kullanılamaz. Bilinen oyun
  klonlarında marka adı kullanmak (**Tetris**, Flappy Bird, Candy Crush vb.) sık ret
  nedenidir.
- **4.2 Asgari işlevsellik:** Web sitesini sarmalayan veya çok basit uygulamalar reddedilir.
- **4.3 Spam:** Aynı uygulamanın birden fazla kopyası yayımlanamaz.
- **4.5.4 Anlık bildirimler:** Bildirimler uygulamanın çalışması için zorunlu olmamalı.
  Reklam bildirimleri için ayrıca açık onay gerekir.
- **4.8 Apple ile Giriş:** Google, Facebook gibi üçüncü taraf giriş sunuluyorsa, eşdeğer
  gizlilik sunan bir seçenek (pratikte Apple ile Giriş) de sunulmalıdır. Yalnızca kendi
  e-posta ve şifre sistemi varsa zorunlu değildir.

### 1.5 Yasal (Legal — Bölüm 5)
- **5.1.1 Veri toplama ve saklama:**
  - (i) Gizlilik politikası bağlantısı hem App Store Connect'te hem de uygulama içinde
    kolayca erişilebilir olmalı.
  - (ii) Uygulamanın çalışması için gerekmeyen kişisel veriler (doğum tarihi, cinsiyet,
    telefon vb.) **zorunlu tutulamaz.**
  - (iv) İzin istemlerinden önce gösterilen özel pencerede "Vazgeç", "Şimdi değil" gibi
    izin istemini atlatan butonlar olmamalıdır. Yalnızca "Devam" butonu olmalıdır.
  - (v) Hesap oluşturulabilen uygulamada **uygulama içinden hesap silme** zorunludur.
- **5.1.2 Veri kullanımı ve paylaşımı:** App Store Connect'teki gizlilik etiketleri
  (App Privacy) gerçek veri toplamayla birebir tutarlı olmalıdır.
- **Gizlilik bildirim dosyası (PrivacyInfo.xcprivacy):** "Gerekçe gerektiren API"
  (UserDefaults, dosya zaman damgası, disk alanı, sistem açılış süresi) kullanımları beyan
  edilmelidir. Eksikse yükleme sırasında ITMS-91053 uyarısı veya reddi gelir.
- **İzin açıklamaları:** Kullanılan her izin için Info.plist'te amacı açıkça anlatan bir
  `NS…UsageDescription` metni bulunmalı. Muğlak metinler ("uygulama için gerekli")
  reddedilir.
- **5.2 Fikrî mülkiyet:** Üçüncü taraf marka, logo ve telifli içerik yalnızca izinle
  kullanılabilir.
- **5.3 Kumar ve çekilişler:** Çekiliş ve yarışmaların resmî kuralları olmalı ve Apple'ın
  sponsor olmadığı belirtilmelidir.

### 1.6 Teknik ve gönderim şartları
- Güncel Xcode ve iOS SDK ile derleme (bkz. B12).
- Dağıtım sertifikası ve App Store provisioning profile ile imzalama.
- Her yüklemede `CFBundleVersion` (build numarası) öncekinden büyük olmalı.
- `aps-environment` yetkisi (push) doğru olmalı.
- Şifreleme beyanı `ITSAppUsesNonExemptEncryption` yapılmalı.
- 1024×1024 App Store ikonu **şeffaflık (alfa kanalı) içermemeli.**
- İlk açılışta çökme olmamalı. Firebase yapılandırmasının veya ortam dosyalarının eksik
  olması en sık nedendir.
- Yaş derecelendirme anketi güncel sorularla doldurulmalı. Kullanıcı içeriği, sohbet ve
  harici bağlantı soruları dürüstçe yanıtlanmalı.

---

## 2. Bulgular ve düzeltme önerileri

Her bulgu şu yapıdadır: **Kural → Kanıt → Neden sorun → Düzeltme.**

### 🔴 B1 — Kampüs Cepte, Sakarya dışında kilitleniyor

- **Kural:** 2.1 (eksiksiz uygulama)
- **Kanıt:** [lib/screens/campus_map_screen.dart:157-165](lib/screens/campus_map_screen.dart#L157)
  konum Sakarya dışındaysa `_GateStatus.outsideSakarya` durumuna geçip haritayı kilit
  ekranıyla değiştiriyor. Metin: *"Kampüs Cepte özelliği Sakarya sınırları içindeyken
  kullanılabilir."* (satır 418).
- **Neden sorun:** Apple inceleme ekibi büyük olasılıkla ABD'de (Cupertino). Özelliği hiç
  göremeyecek ve "incelenemeyen/çalışmayan özellik" gerekçesiyle ret verebilir.
- **Düzeltme (önerilen):** Kilidi kaldırıp **bilgilendirme bandı** gösterin; harita kampüs
  merkezinde açılsın. İlgili POI'ler her yerden görüntülenebilir olmalı.

  ```dart
  // campus_map_screen.dart — _initLocation içinde
  if (!check.inSakarya) {
    setState(() {
      _adminArea = check.placemark?.administrativeArea;
      _distanceToCampus = LocationService.distanceToCampusKm(pos.latitude, pos.longitude);
      _isOutsideSakarya = true;          // yeni alan
      // _status = _GateStatus.outsideSakarya;   ← kaldırın
    });
  }
  ```

  Harita gövdesinin üstüne, `_isOutsideSakarya` doğruysa şu metni gösteren kapatılabilir
  bir bant ekleyin: *"Kampüsten X km uzaktasın. Harita kampüs merkezinde gösteriliyor."*
  Kamera kampüs koordinatına ortalanabilir.
- **Alternatif:** Kilit kalacaksa inceleme notuna (Review Notes) açıklama yazın ve
  Sakarya'da çekilmiş 30 saniyelik bir ekran kaydı bağlantısı ekleyin (bkz. Bölüm 4). Bu
  yol daha risklidir; ret gelirse bir tur kaybedilir.

### 🔴 B2 — "Yakında geliyor" menü öğeleri

- **Kural:** 2.2 (beta/yer tutucu içerik), 2.1
- **Kanıt:**
  - [lib/widgets/options_sheet.dart:350](lib/widgets/options_sheet.dart#L350) — "Kitap Okuma Kulübü"
  - [lib/widgets/options_sheet.dart:357](lib/widgets/options_sheet.dart#L357) — "Topluluk Haberleri"
  - [lib/screens/nev_plus_screen.dart:198](lib/screens/nev_plus_screen.dart#L198) — "Kitap Okuma Kulübü"
- **Neden sorun:** Tıklanınca yalnızca "yakında geliyor! 🚀" mesajı veren öğeler, Apple'ın
  en tutarlı uyguladığı ret nedenlerinden biri.
- **Düzeltme:** Bu `ListTile`/menü öğelerini kaldırın. İleride açmak için bir özellik
  bayrağının arkasına koyabilirsiniz:

  ```dart
  // lib/config/feature_flags.dart
  class FeatureFlags {
    static const bool bookClub = false;
    static const bool communityNews = false;
  }

  // options_sheet.dart / nev_plus_screen.dart
  if (FeatureFlags.bookClub) _buildMenuItem(...),
  ```

  Kullanılmayan `_showComingSoon` fonksiyonlarını da silin.

### 🔴 B3 — "Tetris" markasının kullanımı

- **Kural:** 4.1 (taklit), 5.2.1 (fikrî mülkiyet)
- **Kanıt:** [lib/screens/games/game_room_screen.dart:21](lib/screens/games/game_room_screen.dart#L21),
  [lib/screens/games/tetris_game.dart:292](lib/screens/games/tetris_game.dart#L292) ve
  [tetris_game.dart:334](lib/screens/games/tetris_game.dart#L334).
- **Neden sorun:** "Tetris" The Tetris Company'nin tescilli markasıdır. Apple bu adı
  kullanan klonları düzenli olarak reddeder; ayrıca marka sahibinden kaldırma talebi
  gelebilir.
- **Düzeltme:** Kullanıcıya görünen tüm metinlerde adı değiştirin: "Blok Yığ", "Düşen
  Bloklar" veya "NevBlok" gibi. Sınıf adları (`TetrisGame`) kullanıcıya görünmediği için
  sorun değildir, ama tutarlılık için `BlockGame` olarak yeniden adlandırılabilir.
  "Sudoku" ve "Baloncuk Patlatma" genel oyun türü adları olduğu için sorun yoktur.
  App Store açıklamasında ve anahtar kelimelerde de "Tetris" geçmemeli.

### 🔴 B4 — Kullanıcı engelleme ve kullanım şartları onayı yok

- **Kural:** 1.2 (kullanıcı içeriği)
- **Mevcut durum:**
  - ✅ Şikayet etme var: [lib/widgets/post_card.dart:208](lib/widgets/post_card.dart#L208),
    [lib/screens/home_screen.dart:393](lib/screens/home_screen.dart#L393).
  - ✅ Yönetici şikayet paneli var: [lib/screens/admin_screen.dart:1553](lib/screens/admin_screen.dart#L1553).
  - ❌ **Engelleme yok.** Kullanıcı, rahatsız olduğu bir gönderi sahibini veya topluluğu
    akışından kaldıramıyor.
  - ❌ **Kullanım şartları onayı yok.** [lib/screens/privacy_policy_screen.dart](lib/screens/privacy_policy_screen.dart)
    içinde `isFirstTime` / `onAccepted` ile bir kabul akışı yazılmış, ama hiçbir yerden
    çağrılmıyor. Kayıt ekranında onay kutusu da yok.
  - ⚠️ Otomatik içerik filtresi yok. Gönderileri yalnızca başkan/yetkili rollerin
    oluşturabilmesi (`canPost`) riski azaltıyor, ama Apple yine de bir filtre bekleyebilir.
- **Düzeltme 1 — Engelleme (sunucu):**

  ```sql
  -- supabase/migrations/20261003_user_blocks.sql
  CREATE TABLE IF NOT EXISTS public.user_blocks (
    blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id),
    CHECK (blocker_id <> blocked_id)
  );
  ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS user_blocks_own ON public.user_blocks;
  CREATE POLICY user_blocks_own ON public.user_blocks
    FOR ALL USING (blocker_id = auth.uid()) WITH CHECK (blocker_id = auth.uid());

  NOTIFY pgrst, 'reload schema';
  ```

- **Düzeltme 2 — Engelleme (uygulama):**
  - `post_card.dart` içindeki üç nokta menüsüne **"Bu kullanıcıyı engelle"** öğesi ekleyin.
    Onaydan sonra `user_blocks` tablosuna ekleme yapıp gönderiyi listeden anında kaldırın.
  - `SupabaseDataService` içinde gönderi listesini çekerken engellenenleri hariç tutun:

    ```dart
    final blocked = await _db.from('user_blocks')
        .select('blocked_id').eq('blocker_id', uid);
    final ids = (blocked as List).map((r) => r['blocked_id'] as String).toList();
    var q = _db.from('posts').select(...);
    if (ids.isNotEmpty) q = q.not('author_id', 'in', '(${ids.join(',')})');
    ```

  - Profil/ayarlar altına "Engellenen kullanıcılar" listesi ve engel kaldırma ekleyin.
  - Engelleme yapıldığında yöneticiye bildirim de düşülebilir (Apple bunu önerir).
- **Düzeltme 3 — Kullanım şartları onayı:**
  - `privacy_policy_screen.dart` metnine açık bir madde ekleyin: *"NevGenç'te uygunsuz,
    nefret içeren, taciz edici veya yasa dışı içeriğe tolerans gösterilmez. Bu tür içerik
    kaldırılır ve paylaşan hesap kapatılır."*
  - `register_screen.dart` içinde, "Kayıt Ol" butonunun üstüne onay kutusu ekleyin ve
    işaretlenmeden kaydı engelleyin:

    ```dart
    bool _termsAccepted = false;
    // ...
    CheckboxListTile(
      value: _termsAccepted,
      onChanged: (v) => setState(() => _termsAccepted = v ?? false),
      title: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const PrivacyPolicyScreen())),
        child: const Text('Kullanım Şartları ve Gizlilik Politikası\'nı okudum, kabul ediyorum.'),
      ),
    ),
    // _register() içinde:
    if (!_termsAccepted) {
      setState(() => _errorMsg = 'Devam etmek için kullanım şartlarını kabul edin.');
      return;
    }
    ```

  - Mevcut kullanıcılar için: oturum açıkken `isPrivacyPolicyAccepted == false` ise
    `PrivacyPolicyScreen(isFirstTime: true, onAccepted: ...)` bir kez gösterilsin.
- **Düzeltme 4 — Şikayet süresi:** Yöneticiye şikayet geldiğinde push bildirimi gitsin
  ve şikayetler 24 saat içinde işlensin. Bu taahhüdü inceleme notuna da yazın.

### 🔴 B5 — Codemagic'te imzalama ve gizli dosyalar tanımsız

- **Kural:** Teknik (derleme ve yükleme)
- **Kanıt:** [codemagic.yaml](codemagic.yaml)
  - `ios_signing` bölümü ve `xcode-project use-profiles` adımı yok. `flutter build ipa`
    CI makinesinde imzalama kimliği bulamaz.
  - `lib/config/app_config.dart` ve `ios/Runner/GoogleService-Info.plist` git'te yok
    (`.gitignore` satır 58 ve 76). İş akışı bu dosyaları oluşturmuyor. `main.dart`
    birincisini içe aktardığı için Dart derlemesi durur. Xcode projesi ikincisini kaynak
    olarak beklediği için Xcode derlemesi de durur.
- **Düzeltme:** Codemagic'te `nevgenc_secrets` adlı bir ortam değişkeni grubu oluşturun:
  - `SUPABASE_URL`, `SUPABASE_ANON_KEY`
  - `GOOGLE_SERVICE_INFO_PLIST_B64` (dosyanın base64 hâli:
    `[Convert]::ToBase64String([IO.File]::ReadAllBytes("ios\Runner\GoogleService-Info.plist"))`)

  Ardından `codemagic.yaml` dosyasını şöyle güncelleyin:

  ```yaml
  workflows:
    ios-release:
      name: NevGenç iOS App Store Release
      instance_type: mac_mini_m2
      max_build_duration: 60
      integrations:
        app_store_connect: <Codemagic'teki API anahtarı adı>
      environment:
        flutter: stable
        xcode: latest
        groups:
          - nevgenc_secrets
        ios_signing:
          distribution_type: app_store
          bundle_identifier: com.newgenc.app
      scripts:
        - name: Gizli yapılandırma dosyalarını oluştur
          script: |
            cat > lib/config/app_config.dart <<EOF
            class AppConfig {
              static const String supabaseUrl = '$SUPABASE_URL';
              static const String supabaseAnonKey = '$SUPABASE_ANON_KEY';
            }
            EOF
            echo "$GOOGLE_SERVICE_INFO_PLIST_B64" | base64 --decode > ios/Runner/GoogleService-Info.plist
        - name: Get Flutter packages
          script: flutter pub get
        - name: Kod imzalamayı kur
          script: xcode-project use-profiles
        - name: Build iOS IPA
          script: |
            flutter build ipa --release --obfuscate --split-debug-info=build/debug-info \
              --export-options-plist=/Users/builder/export_options.plist
        # (dSYM yükleme adımı aynı kalır)
      artifacts:
        - build/ios/ipa/*.ipa
        - /tmp/xcodebuild_logs/*.log
      publishing:
        app_store_connect:
          auth: integration
          submit_to_testflight: true
  ```

  > Gerçek `app_config.dart` dosyanızda `--dart-define` desteği varsa, yukarıdaki şablon
  > yerine onun içeriğini koruyun ve yalnızca varsayılan değerleri ortam değişkeninden
  > doldurun.

  Ek notlar:
  - Codemagic'te *Team settings → Code signing identities* altında App Store dağıtım
    sertifikası ve `com.newgenc.app` için App Store provisioning profile tanımlı olmalı
    (veya API anahtarıyla otomatik oluşturulmalı).
  - Build numarası (29), App Store Connect'e daha önce yüklenen iOS build'lerinden büyük
    olmalı. Android ile aynı numara kullanılıyorsa sorun yok, ancak iOS'a daha yüksek bir
    numara yüklendiyse `pubspec.yaml`'daki `+29` artırılmalı.

### 🟠 B6 — Demo hesap gerekli

- **Kural:** 2.1
- **Kanıt:** [lib/services/supabase_auth_service.dart:20-31](lib/services/supabase_auth_service.dart#L20)
  kayıt ve girişte yalnızca `.edu` / `.edu.tr` adreslerine izin veriyor ve e-posta
  doğrulaması istiyor.
- **Neden sorun:** İnceleme ekibinin öğrenci e-postası yok; kendi hesabını açamaz.
- **Düzeltme:**
  1. Supabase'de `.edu.tr` uzantılı, **doğrulanmış** bir test hesabı oluşturun
     (ör. `appreview@<okul>.edu.tr`). Supabase Auth panelinden "Confirm email" ile
     doğrulayabilirsiniz.
  2. Hesabı en az bir topluluğa üye yapın; takvimde etkinlik ve akışta gönderi olsun.
  3. Mümkünse bu hesaba başkan rolü verin ki gönderi oluşturma ve başkan paneli de
     incelenebilsin (bu durumu notta belirtin).
  4. App Store Connect → App Review Information → **Sign-In Required** alanına e-posta ve
     şifreyi girin.
  5. İnceleme süresince bu hesabın şifresini değiştirmeyin ve silmeyin.

### 🟠 B7 — Doğum tarihi zorunlu

- **Kural:** 5.1.1(ii) (veri minimizasyonu)
- **Kanıt:** [lib/screens/register_screen.dart:150-153](lib/screens/register_screen.dart#L150)
  doğum tarihi boşsa kaydı engelliyor.
- **Neden sorun:** Uygulamanın temel işlevi doğum tarihine bağlı değil. Apple, gerekmeyen
  kişisel verinin zorunlu tutulmasını ret nedeni sayar.
- **Düzeltme:** Kontrolü kaldırın ve etiketi "Doğum Tarihi (isteğe bağlı)" yapın. Doğum
  günü kutlaması gibi bir kullanım varsa, alanın yanında kısa bir gerekçe yazın.

  ```dart
  // register_screen.dart — bu bloğu silin:
  if (_birthDateCtrl.text.trim().isEmpty) {
    setState(() => _errorMsg = 'Lütfen doğum tarihinizi girin.');
    return;
  }
  ```

### 🟠 B8 — iPad desteği açık

- **Kural:** 2.3.3 (iPad ekran görüntüleri), 4.0 ve 2.4.1 (iPad'de düzgün çalışma)
- **Kanıt:** `ios/Runner.xcodeproj/project.pbxproj` satır 365, 492 ve 545:
  `TARGETED_DEVICE_FAMILY = "1,2"`.
- **Neden sorun:** iPad ekran görüntüsü yüklenmezse gönderim yapılamaz. İnceleme iPad'de
  yapılırsa bozuk görünen ekranlar ret nedeni olur.
- **Düzeltme (önerilen):** Arayüz iPad için ayrıca test edilmediyse yalnızca iPhone'a
  sınırlayın. Üç satırın hepsini şöyle değiştirin:

  ```
  TARGETED_DEVICE_FAMILY = 1;
  ```

  Not: Uygulama yine de iPad'lerde "iPhone uyumluluk modunda" çalışabilir. Apple bu modda
  da test edebilir; bu nedenle en azından iPad simülatöründe bir kez açıp çökme
  olmadığını doğrulayın.

### 🟠 B9 — Gizlilik etiketleri ve gizlilik bildirimi

- **Kural:** 5.1.1(i), 5.1.2
- **Kanıt:** [ios/Runner/PrivacyInfo.xcprivacy](ios/Runner/PrivacyInfo.xcprivacy)
  içinde `NSPrivacyCollectedDataTypes` boş dizi. Ancak uygulama şu verileri topluyor:

  | Veri | Kaynak | App Store Connect kategorisi | Kimlikle ilişkili | İzleme |
  |---|---|---|---|---|
  | E-posta | Kayıt | Contact Info → Email Address | Evet | Hayır |
  | Ad soyad | Kayıt/profil | Contact Info → Name | Evet | Hayır |
  | Doğum tarihi, bölüm, sınıf | Kayıt | Other User Content (veya Other Data) | Evet | Hayır |
  | Profil fotoğrafı, gönderi görselleri | Galeri/kamera | User Content → Photos | Evet | Hayır |
  | Gönderi, şikayet, talep metinleri | Uygulama içi | User Content → Other User Content | Evet | Hayır |
  | Kullanıcı kimliği | Supabase | Identifiers → User ID | Evet | Hayır |
  | Push token | FCM | Identifiers → Device ID | Evet | Hayır |
  | Çökme kayıtları | Crashlytics | Diagnostics → Crash Data | Hayır | Hayır |
  | Performans verisi | Firebase Performance | Diagnostics → Performance Data | Hayır | Hayır |
  | Konum | Harita/kıble | *Yalnızca cihazda işleniyorsa beyan gerekmez* | — | — |

  > Konum sunucuya gönderilmiyorsa (kodda öyle görünüyor; rationale metni de bunu
  > söylüyor) "toplanan veri" sayılmaz. Ancak ters jeokodlama Apple'ın sunucusuna gider;
  > bu, Apple API'si olduğu için beyan gerektirmez.

- **Düzeltme:**
  1. App Store Connect → App Privacy formunu yukarıdaki tabloya göre doldurun.
  2. Gizlilik politikası URL'si olarak [GIZLILIK_POLITIKASI.md](GIZLILIK_POLITIKASI.md)
     içeriğini **herkese açık bir web sayfasında** yayımlayın (GitHub Pages, Telegraph,
     Notion vb.) ve bu URL'yi App Store Connect'e girin. Politikada Firebase (Google),
     Supabase ve Telegraph'ın veri işleyici olarak geçtiğinden emin olun.
  3. (Önerilen) `PrivacyInfo.xcprivacy` içindeki `NSPrivacyCollectedDataTypes` dizisini
     de doldurun. Örnek bir kayıt:

     ```xml
     <dict>
       <key>NSPrivacyCollectedDataType</key>
       <string>NSPrivacyCollectedDataTypeEmailAddress</string>
       <key>NSPrivacyCollectedDataTypeLinked</key><true/>
       <key>NSPrivacyCollectedDataTypeTracking</key><false/>
       <key>NSPrivacyCollectedDataTypePurposes</key>
       <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
     </dict>
     ```

     Aynı yapıyı Name, PhotosorVideos, OtherUserContent, UserID, DeviceID, CrashData ve
     PerformanceData için tekrarlayın.
  4. Giriş ve kayıt ekranlarına da gizlilik politikası bağlantısı ekleyin (şu an yalnızca
     ayarlar menüsünden açılıyor: [options_sheet.dart:249](lib/widgets/options_sheet.dart#L249)).

### 🟠 B10 — Canlı veritabanında bekleyen SQL'ler

- **Kural:** 5.1.1(v) (hesap silme), 2.1 (hata)
- **Kanıt:**
  - Hesap silme [supabase_auth_service.dart:315](lib/services/supabase_auth_service.dart#L315)
    `delete_account` fonksiyonunu çağırıyor; tanımı [supabase/delete_account.sql](supabase/delete_account.sql).
  - [supabase/migrations/20261002_fix_communities_rls_recursion.sql](supabase/migrations/20261002_fix_communities_rls_recursion.sql)
    çalıştırılmadıysa topluluklar üzerindeki her güncelleme `42P17 infinite recursion`
    hatasıyla düşüyor.
- **Neden sorun:** İnceleme ekibi hesap silmeyi mutlaka dener. Hata verirse doğrudan ret
  gelir. Topluluk güncelleme hatası da 2.1 kapsamında hata sayılır.
- **Düzeltme:**
  1. Supabase SQL Editor'da (aktif proje `vvfdcxeewqcgbcpeabac`) şunu çalıştırıp
     fonksiyonun varlığını doğrulayın:

     ```sql
     SELECT proname FROM pg_proc WHERE proname IN ('delete_account', 'communities_lock_chairman_fields');
     ```

  2. Eksik olanlar için ilgili SQL dosyalarını çalıştırın.
  3. Gönderimden önce **ayrı bir test hesabıyla** (demo hesabı değil!) uygulamadan hesap
     silmeyi uçtan uca deneyin.

### 🟡 B11 — GitHub Actions iOS iş akışı

- **Kanıt:** [.github/workflows/build_ios_ipa.yml](.github/workflows/build_ios_ipa.yml)
  - B5'teki gizli dosya sorunu burada da var; derleme büyük olasılıkla başarısız oluyor.
  - İmzasız IPA üretiyor (`CODE_SIGNING_ALLOWED=NO`). Bu dosya App Store'a veya
    TestFlight'a yüklenemez; yalnızca derlenebilirlik kontrolü işe yarar.
  - `pod install ... || true` pod hatalarını gizliyor.
- **Düzeltme:** Bu iş akışını yalnızca "derleniyor mu?" kontrolü olarak tutun ve yayını
  Codemagic'e bırakın. GitHub → Settings → Secrets altına `SUPABASE_URL`,
  `SUPABASE_ANON_KEY`, `GOOGLE_SERVICE_INFO_PLIST_B64` ekleyip `flutter pub get`
  adımından önce şu adımı koyun:

  ```yaml
  - name: Gizli yapılandırma dosyalarını oluştur
    env:
      SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
      SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
      GSP_B64: ${{ secrets.GOOGLE_SERVICE_INFO_PLIST_B64 }}
    run: |
      cat > lib/config/app_config.dart <<EOF
      class AppConfig {
        static const String supabaseUrl = '$SUPABASE_URL';
        static const String supabaseAnonKey = '$SUPABASE_ANON_KEY';
      }
      EOF
      echo "$GSP_B64" | base64 --decode > ios/Runner/GoogleService-Info.plist
  ```

  `|| true` ifadesini de kaldırın ki pod hataları görünür olsun.

### 🟡 B12 — iOS SDK sürüm şartı

- **Kural:** Apple yükleme şartı. Apple, Nisan 2026'dan itibaren App Store Connect'e
  yüklenen uygulamaların **Xcode 26 ve iOS 26 SDK** ile derlenmesini şart koşuyor.
  Eski SDK ile yüklemede ITMS-90725 türü bir hata alınır.
- **Kanıt:** GitHub iş akışı `macos-15` kullanıyor; bu imajın varsayılan Xcode'u 16.x.
  Codemagic tarafında `xcode: latest` olduğu için sorun yok.
- **Düzeltme:** Yayın Codemagic'ten yapılacaksa ek iş gerekmez. GitHub iş akışında da
  Xcode 26'yı seçin (`macos-26` imajı ya da `sudo xcode-select -s /Applications/Xcode_26*.app`).
  Güncel şartı App Store Connect "Upcoming Requirements" sayfasından doğrulayın.

### 🟡 B13 — Yatay ekran desteği

- **Kanıt:** [ios/Runner/Info.plist:68-73](ios/Runner/Info.plist#L68) iPhone'da yatay
  yönlendirmeye izin veriyor.
- **Neden sorun:** Oyun, harita ve form ekranları yatayda taşarsa (sarı-siyah taşma
  şeridi, kesik butonlar) inceleme ekibi bunu hata olarak raporlayabilir.
- **Düzeltme:** Yatay kullanım tasarlanmadıysa yalnızca dikey bırakın:

  ```xml
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
  </array>
  ```

  Ek güvenlik için `main.dart` içinde
  `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);` çağrılabilir.

### 🟡 B14 — Bildirim izninin açılışta istenmesi

- **Kanıt:** `main.dart` satır 146'da `fcmService.initialize()` açılışta çağrılıyor ve
  [lib/services/fcm_service.dart:48](lib/services/fcm_service.dart#L48)
  `requestPermission` ile sistem penceresini hemen açıyor.
- **Neden sorun:** Doğrudan ret nedeni değil, ancak Apple ve kullanıcı deneyimi açısından
  izin, bağlam oluştuğunda (ör. ilk topluluğa katılırken veya bildirim merkezini
  açarken) istenmeli. Açılışta istenen izinlerin kabul oranı düşüktür.
- **Düzeltme:** Açılışta yalnızca FCM'i hazırlayın; `requestPermission` çağrısını ilk
  topluluğa katılma veya bildirim merkezi ekranına taşıyın (bildirim merkezinde zaten
  bir çağrı var: [notification_center_screen.dart:59](lib/screens/notification_center_screen.dart#L59)).
  Bildirimler reddedilse bile uygulama tam çalışmaya devam etmeli (şu an öyle).

### 🟡 B15 — Arka plan bildirim modu

- **Kanıt:** Info.plist'te `UIBackgroundModes` yok.
- **Neden sorun:** Normal (görünür) bildirimler çalışır. Ancak sessiz (`content-available`)
  bildirimler ve bazı FCM veri mesajları arka planda işlenmez.
- **Düzeltme:** Sessiz bildirim kullanılıyorsa ekleyin; kullanılmıyorsa eklemeyin (Apple
  kullanılmayan arka plan modunu 2.5.4 kapsamında sorgulayabilir).

  ```xml
  <key>UIBackgroundModes</key>
  <array>
    <string>remote-notification</string>
  </array>
  ```

---

## 3. Uygun bulunan noktalar

| Konu | Durum | Kanıt |
|---|---|---|
| Uygulama içi hesap silme (5.1.1(v)) | ✅ Var | [options_sheet.dart:142](lib/widgets/options_sheet.dart#L142) |
| Gönderi şikayet etme (1.2) | ✅ Var | [post_card.dart:208](lib/widgets/post_card.dart#L208) |
| Yönetici moderasyon paneli | ✅ Var | [admin_screen.dart:1553](lib/screens/admin_screen.dart#L1553) |
| Talep/şikayet (iletişim kanalı) | ✅ Var | [ticket_create_screen.dart](lib/screens/ticket_create_screen.dart) |
| İzin açıklama metinleri | ✅ Açık ve amaca özel | [Info.plist:31-40](ios/Runner/Info.plist#L31) |
| Konum izninden önceki açıklama penceresi | ✅ Yalnızca "Anladım" butonu var; 5.1.1(iv) uyumlu | [campus_map_screen.dart:78](lib/screens/campus_map_screen.dart#L78) |
| Gizlilik bildirim dosyası ve API gerekçeleri | ✅ Projeye ekli | [PrivacyInfo.xcprivacy](ios/Runner/PrivacyInfo.xcprivacy) |
| İzleme (ATT) | ✅ Yok, `NSPrivacyTracking=false` | — |
| Şifreleme beyanı | ✅ `false` (yalnızca HTTPS; muafiyet kapsamında) | [Info.plist:7](ios/Runner/Info.plist#L7) |
| Push yetkisi | ✅ `aps-environment = production` | [Runner.entitlements](ios/Runner/Runner.entitlements) |
| 1024×1024 ikon | ✅ Alfa kanalı yok (RGB) | `AppIcon.appiconset` |
| Apple ile Giriş (4.8) | ✅ Gerekmez; yalnızca e-posta/şifre girişi var | [supabase_auth_service.dart](lib/services/supabase_auth_service.dart) |
| Uygulama içi satış (3.1.1) | ✅ Yok; kuponlar fiziksel hizmet kapsamında | — |
| Sohbet için Telegram/Discord yönlendirmesi | ✅ Kurallara uygun | [community_chat_screen.dart](lib/screens/community_chat_screen.dart) |
| Gönderi oluşturma yetkisi | ✅ Yalnızca yetkili roller (`canPost`); UGC riski düşük | [home_screen.dart:539](lib/screens/home_screen.dart#L539) |
| Minimum iOS sürümü | ✅ 13.0 (Firebase ve Flutter ile uyumlu) | [Podfile](ios/Podfile) |
| Zorunlu güncelleme | ✅ Ağ hatasında açılışı engellemiyor | [force_update_service.dart](lib/services/force_update_service.dart) |

> ⚠️ **Hatırlatma:** Google ile giriş ileride geri eklenirse (daha önce projede vardı),
> Kural 4.8 gereği **Apple ile Giriş de eklenmelidir.**

> ⚠️ **Zorunlu güncelleme:** Uygulama onaylandıktan sonra `app_settings` tablosuna
> `ios_store_url` değerini (`https://apps.apple.com/app/id<APP_ID>`) girin. Aksi hâlde
> `min_supported_ios_build` yükseltildiğinde "Şimdi Güncelle" butonu devre dışı kalır ve
> kullanıcı uygulamada kilitli kalır.

---

## 4. App Store Connect gönderim kontrol listesi

**Uygulama bilgileri**
- [ ] Ad (≤30 karakter): "NevGenç" · Alt başlık (≤30 karakter) · Kategori: Education
      veya Social Networking
- [ ] Açıklama ve anahtar kelimelerde "Tetris", "Android", "Google Play" geçmiyor
- [ ] Destek URL'si (çalışan bir sayfa) ve pazarlama URL'si (isteğe bağlı)
- [ ] Gizlilik politikası URL'si (herkese açık web sayfası)
- [ ] Telif hakkı satırı: "2026 NevGenç"

**Ekran görüntüleri**
- [ ] 6.9" iPhone (1320×2868 veya 1290×2796) — en az 3 adet
- [ ] 6.5" iPhone (1284×2778 veya 1242×2688) — gerekirse
- [ ] iPad 13" — **yalnızca iPad desteği açık kalırsa** (bkz. B8)
- [ ] Görüntüler gerçek uygulamadan alınmış; "yakında" öğeleri görünmüyor

**Yaş derecelendirmesi**
- [ ] Güncel anket soruları yanıtlandı: kullanıcı içeriği **evet**, kullanıcılar arası
      iletişim (harici sohbet bağlantıları) **evet**, kumar/şiddet **hayır**.
      Beklenen sonuç 13+ civarı.

**Gizlilik**
- [ ] App Privacy formu B9'daki tabloya göre dolduruldu
- [ ] Veri silme talebi yolu gizlilik politikasında yazılı

**İnceleme bilgileri**
- [ ] Demo hesap e-postası ve şifresi (B6)
- [ ] İletişim adı, telefon, e-posta
- [ ] İnceleme notu (aşağıdaki şablon)
- [ ] Gerekirse demo videosu bağlantısı (Sakarya içi harita için)

**Build**
- [ ] Build Xcode 26 / iOS 26 SDK ile Codemagic'ten yüklendi
- [ ] Build numarası öncekinden büyük
- [ ] TestFlight'ta gerçek cihazda duman testi yapıldı: giriş, akış, topluluğa katılma,
      takvim, harita, oyunlar, şikayet, engelleme, hesap silme (test hesabıyla)
- [ ] Export compliance: "Yalnızca muaf şifreleme (HTTPS)" seçildi

---

## 5. İnceleme notu şablonu (Review Notes — İngilizce)

İnceleme ekibi notları İngilizce okur. Aşağıdaki metni App Store Connect → App Review
Information → Notes alanına uyarlayarak yapıştırın.

```
NevGenç is a campus community app for university students in Sakarya, Türkiye.
The interface is in Turkish.

DEMO ACCOUNT
Registration is restricted to verified university e-mail addresses (.edu / .edu.tr),
so please use the pre-verified demo account below:
  E-mail:   appreview@<school>.edu.tr
  Password: <password>
This account is a member of several communities and has community-chairman
privileges, so you can also test post creation and the chairman panel
(Home > "+" button, Profile > "Başkan Paneli").

LOCATION-BASED FEATURE
"Kampüs Cepte" (campus map) shows campus points of interest in Sakarya. Outside
Sakarya the map still opens centered on the campus with an information banner.
Location is processed on-device only and is never sent to our servers.
[If the lock is kept: A demo video recorded in Sakarya: <video link>]

USER-GENERATED CONTENT & MODERATION
- Only verified students can join; only community chairmen/admins can publish posts.
- All users must accept the Terms of Use (zero tolerance for objectionable content)
  during registration.
- Every post has a "..." menu with "Şikayet Et" (Report) and
  "Bu kullanıcıyı engelle" (Block user). Blocked users' posts are removed from the feed
  immediately.
- Admins receive a notification for each report and act on reports within 24 hours.
- In-app contact: Profile menu > "Talep ve Şikayetler".

ACCOUNT DELETION
Profile menu (top right) > "Hesabı Sil". This permanently deletes the account and
all associated data.

EXTERNAL LINKS
Community chat opens the community's own Telegram/Discord group in the external app.
No purchases or subscriptions are offered in the app.
```

---

## 6. Önerilen uygulama sırası

1. **Kod (yarım gün):** B2 → B3 → B7 → B13 → B8 → B1
2. **Moderasyon (yarım gün):** B4 (SQL + engelleme arayüzü + şartlar onayı)
3. **Sunucu (15 dk):** B10 SQL'lerini canlıda çalıştır ve doğrula; engelleme SQL'ini çalıştır
4. **CI (1 saat):** B5 Codemagic gizli değişkenleri ve imzalama; B11 isteğe bağlı
5. **Hazırlık:** B6 demo hesabı, B9 gizlilik formu ve politika URL'si, Bölüm 4 kontrol listesi
6. **TestFlight:** Gerçek cihazda duman testi → İncelemeye gönder

Ret gelirse: Resolution Center'daki mesajı dikkatle okuyun, yalnızca belirtilen maddeyi
düzeltin ve yanıt kutusuna ne değiştiğini kısaca (İngilizce) yazın. Kararın hatalı
olduğunu düşünüyorsanız aynı ekrandan itiraz edebilirsiniz.
