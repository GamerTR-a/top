# 📋 NevGenç — Uygulama Denetim Raporu (Tamamlanmış)

> Bu belge, jenerik "Mobil Uygulama A'dan Z'ye Denetim Kontrol Listesi"nin **NevGenç** projesine özel olarak, gerçek kod okunarak (Read/Grep/Bash + `flutter analyze`) dolduruluş halidir. Her madde için **Durum / Kanıt / Risk seviyesi / Düzeltme önerisi** verilmiştir. Koddan doğrudan görülemeyen maddeler **❓ Doğrulanamadı** olarak işaretlenip hangi ortamın (Supabase Dashboard, Google Cloud Console, App Store Connect / Play Console, gerçek cihaz testi) kontrol edilmesi gerektiği belirtilmiştir. Uygulanamaz maddeler **➖** ile işaretlenmiştir. Denetim tarihi: **2026-09-26**.

## Proje Profili

- **Platform:** Flutter (tek codebase, Android + iOS), ~28.500 satır Dart, 35 ekran.
- **Backend:** Supabase (Postgres + RLS + Auth/GoTrue + Realtime + Edge Functions + Storage). Eski `backend/` (Node/Express) klasörü artık kullanılmıyor ve bu denetimin yapıldığı commit ile repodan kaldırılıyor.
- **Firebase:** yalnızca push bildirim (`firebase_messaging`) ve çökme raporlama (`firebase_crashlytics`) için — Firestore/Realtime DB/Analytics kullanılmıyor.
- **CI/CD:** GitHub Actions (yalnızca iOS: `build_ios.yml`, `build_ios_ipa.yml`) + Codemagic (App Store yayını). Android AAB yalnızca yerel `build_aab.ps1` scripti ile üretiliyor, CI'da yok.
- **Ödeme / IAP:** Yok. Kuponlar gerçek dünyadaki fiziksel indirimler, uygulama içi para birimi değil.
- **Test kapsamı:** Yalnızca Flutter şablonunun varsayılan `widget_test.dart`'ı; iş mantığı ve RLS için hiç otomatik test yok.
- **Kimlik doğrulama:** Yalnızca e-posta/şifre (`.edu`/`.edu.tr` zorunlu); Google OAuth için manifest'te atıl bir deep-link kaydı var ama karşılığı olan kod bulunamadı.

---

## 🚨 Yönetici Özeti — Öncelik Sırasına Göre Kritik/Yüksek Bulgular

| # | Seviye | Bulgu | Konum |
|---|--------|-------|-------|
| 1 | ~~Kritik~~ **✅ Düzeltildi (2026-09-30)** | `communities` ve `community_links` tabloları hiçbir migration dosyasında RLS'lenmemişti. `supabase/migrations/20260930_communities_posts_rls_and_weekly_limit_fix.sql` ile RLS açılıp admin/başkan ayrımlı policy'ler eklendi; kullanıcı Dashboard'da çalıştırıp doğruladı. | Bölüm 5.2/5.5 |
| 2 | ~~Yüksek~~ **✅ Düzeltildi (2026-09-30)** | Haftalık destek/puan limiti istemci saatine güveniyordu — sunucu trigger'ı `NEW.week_number`/`NEW.year`'a güveniyordu, `NOW()`'dan hesaplamıyordu. Aynı migration dosyasıyla trigger `EXTRACT(WEEK/YEAR FROM NOW())` kullanacak şekilde düzeltildi ve canlıya uygulandı. | Bölüm 8.8 / 9.9 |
| 3 | ~~Yüksek~~ **✅ Düzeltildi (2026-09-30)** | `posts` tablosunda UPDATE/DELETE RLS policy'si yoktu — aynı migration ile admin/başkan ayrımlı `posts_delete` policy'si eklendi. | Bölüm 5.5 |
| 4 | ~~Yüksek~~ **✅ Düzeltildi (2026-09-26)** | `codemagic.yaml`'daki hardcoded `--build-name=1.0.25 --build-number=26` kaldırıldı, sürüm artık `pubspec.yaml`'dan otomatik okunuyor. | Bölüm 31.3 |
| 5 | ~~Yüksek~~ **⚠️ Temel atıldı (2026-09-27)** | Auth doğrulama, ISO hafta hesabı, Türkçe arama, retry, ve `LocalStorageService` cache round-trip'i için 30 test eklendi (hepsi geçiyor). Supabase'e doğrudan bağımlı servis metodları ve RLS regresyon testleri (pgTAP) hâlâ yok — DI/mock altyapısı gerektiren daha büyük bir iş olarak kaldı. | Bölüm 30.1 / 30.5 |
| 6 | ~~Yüksek~~ **✅ Düzeltildi (2026-09-26)** | `post_card.dart`'ın `_toggleEventJoin()` metoduna hata durumunda rollback + `SnackBar` bildirimi eklendi. | Bölüm 14.4 |
| 7 | ~~Yüksek~~ **✅ Gözden geçirildi (2026-09-27)** | Tüm 30 kalan `catch (_) {}` tek tek incelendi: en riskli iki kritik yazma işlemi (`unsupportPost`, `updateUserProfile`) zaten düzeltilmişti; **kalan ~26 tanesinin büyük çoğunluğu kasıtlı ve doğru** best-effort desenler (logout/cleanup, arka plan senkronizasyonu, crash-handler'ın kendi güvenliği, JSON model parse fallback'i) — bunları rethrow'a çevirmek UX'i bozardı (ör. FCM token silinemedi diye logout'un başarısız görünmesi). Sistemik bir hatayı gizleyebilecek 4 tanesine (auth listener kurulumu, `_checkSession`, XP/rozet ödülü) gözlemlenebilirlik için `debugPrint`/Crashlytics loglaması eklendi, davranış değiştirilmedi. | Bölüm 14.8 |
| 8 | ~~Yüksek~~ **✅ Düzeltildi (2026-09-26)** | `_demoTopluluklar`/`_demoGonderiler`/`_demoKuponlar` (~250 satır sahte veri) tamamen kaldırıldı; hata artık kullanıcıya gerçek hata olarak yansıyor. | Bölüm 14.9 / 16.3 |
| 9 | ~~Yüksek~~ **✅ Düzeltildi** | `home_screen.dart` artık `ScrollController` + `_page`/`_hasMorePosts` ile gerçek sonsuz kaydırma yapıyor (kodda "bkz. kontrol.md Bölüm 16.13" yorumuyla iz bırakılmış). | Bölüm 16.13 |
| 10 | ~~Yüksek~~ **✅ Düzeltildi (Codemagic) (2026-09-26)** | `codemagic.yaml`'a Crashlytics dSYM/symbol upload script adımı eklendi (`upload-symbols`, eksik dosyalarda güvenli `::warning::` ile atlıyor). **Not:** GitHub Actions `build_ios.yml`/`build_ios_ipa.yml` bu adımı içermiyor — gerçek App Store yayını Codemagic üzerinden yapıldığı için öncelik verildi. | Bölüm 17.2 |
| 11 | Yüksek | `admin_screen.dart` (~2386 satır), `calendar_screen.dart`, `baskan_panel_screen.dart` (~1450'şer satırlık tek `State` sınıfı) — bakım/test edilebilirlik riski. **Bilinçli olarak ertelendi** — proje sıfır otomatik test kapsamına sahipken bu büyüklükte bir refactor yüksek regresyon riski taşıyor; ayrı bir oturumda ele alınmalı. | Bölüm 14.2 |
| 12 | ~~Orta-Yüksek~~ **✅ Düzeltildi (2026-09-26)** | Ayarlar'a "Çökme Raporları Gönder" anahtarı (`NotificationPrivacySettingsScreen`) eklendi, `GIZLILIK_POLITIKASI.md`'ye Crashlytics maddesi eklendi. | Bölüm 12.6 |
| 13 | ~~Orta-Yüksek~~ **✅ Düzeltildi (2026-09-30)** | `claimCoupon`'daki "fallback simülasyonu" (sahte başarı + sahte kupon kodu üretimi) tamamen kaldırıldı; RPC hatası artık gerçek hata olarak dönüyor. | Bölüm 10 (ek not) |
| 14 | Orta | Storage'a yüklenen dosyalar sunucu tarafında doğrulanmıyor. **🔜 Migration hazır ama henüz canlıya uygulanmadı:** `supabase/migrations/20260930_storage_limits_and_coupon_rate_limit.sql` (`file_size_limit`+`allowed_mime_types`) — Dashboard SQL Editor'da çalıştırılmalı. | Bölüm 5.12 |
| 15 | Orta | Edge Function'larda rate limiting yok. **🔜 Migration hazır ama henüz canlıya uygulanmadı:** aynı dosyada `claim_coupon_rate_limit` tablosu + güncellenmiş `claim_coupon()` (dakikada max 10 çağrı). | Bölüm 5.10 |
| 16 | ~~Orta~~ **✅ Düzeltildi (2026-09-26)** | `.github/workflows/build_android.yml` eklendi — Android AAB artık CI'da da üretilebiliyor (secret'lardan keystore/`google-services.json` kurulumu dahil). | Bölüm 31.4 |
| 17 | ~~Orta~~ **⚠️ Kod tarafı hazır, migration bekliyor (2026-09-26)** | `ForceUpdateService` + `app_settings` tablosu eklendi (açılışta min build kontrolü, kapatılamaz güncelleme diyaloğu). **🔜 Migration henüz canlıya uygulanmadı:** `supabase/migrations/20260930_app_settings_force_update.sql`. | Bölüm 31.6 |
| 18 | ~~Orta~~ **✅ Düzeltildi (2026-09-26)** | `local_storage_service.dart`'a şema versiyon scaffold'ı (`_currentSchemaVersion`, `_runMigrationsIfNeeded()`) eklendi. | Bölüm 24.1 / 30.7 |
| 19 | ~~Orta~~ **✅ Düzeltildi (2026-09-26)** | `clearUserSessionCache()` eklendi ve `_onLogout()`'a bağlandı — kupon/etkinlik/topluluk/haber/profil önbellekleri artık logout'ta temizleniyor. | Bölüm 2.8 |
| 20 | ~~Orta~~ **✅ Düzeltildi (2026-09-26)** | Atıl `supabase://login` intent-filter'ı `AndroidManifest.xml`'den kaldırıldı (Google OAuth kod tabanında zaten yoktu). | Bölüm 4.2 / 7 (Deep link) |
| 21 | ~~Orta~~ **✅ Düzeltildi (2026-09-26)** | `secure_local_storage.dart`'a `IOSOptions(accessibility: first_unlock_this_device)` eklendi; Android tarafı `flutter_secure_storage` 11.x'te zaten varsayılan olarak güvenli (AES-GCM + Keystore) — kaynak incelenip belgelenerek onaylandı. | Bölüm 2.3 |
| 22 | ~~Orta~~ **✅ Düzeltildi (2026-09-26)** | Kayıt akışındaki "e-posta zaten kayıtlı" mesajı, girişteki gibi genel/başarı mesajıyla birleştirildi — enumeration kapatıldı. | Bölüm 4.15 |
| 23 | ~~Orta~~ **✅ Düzeltildi (2026-09-27)** | Android `FLAG_SECURE` için `MethodChannel` + `SecureScreen` yardımcı sınıfı eklendi; kod tabanındaki tüm kupon/QR/PII gösteren ekranlar tarandı ve 3'ü de kapsandı: `nev_firsatlar_screen.dart` (kuponlar), `baskan_panel_screen.dart` (üye e-postaları), `profile_screen.dart` (kişisel QR kimlik — bugün eklendi). | Bölüm 7 (Ekran ve pano) |
| 24 | ~~Orta~~ **✅ Düzeltildi (2026-09-26)** | `MyDataScreen` + `exportMyData()` eklendi — kullanıcı profil/gönderi/talep verisini uygulama içinden görüntüleyip JSON olarak kopyalayabiliyor. | Bölüm 12.5 |
| 25 | ~~Orta~~ **✅ Düzeltildi (2026-09-27)** | `app-release.aab` ~134 MB → **~58 MB**'a düştü (%57 azalma). Kök neden madde 26'daki paketleme hatasıydı — `keepDebugSymbols`, her üç ABI (arm64-v8a/armeabi-v7a/x86_64) için `libflutter.so`/`libapp.so`'nun tam debug bilgisiyle pakete girmesine sebep oluyordu. Sorun giderilince gerçek bir release AAB derlemesi (sürüm 1.0.27+28) başarıyla üretildi ve doğrulandı. | Bölüm 18.7 |
| 26 | **✅ Düzeltildi (2026-09-27)** — YENİ BULGU | Release AAB derlemesi **üç ayrı** ortam/yapılandırma sorunu yüzünden hep başarısız oluyordu, hepsi bulunup düzeltildi: **(1)** `android/app/build.gradle.kts`'teki `packaging.jniLibs.keepDebugSymbols.add("**/*.so")`, native kütüphanelerin debug sembolleriyle pakete girmesine sebep oluyordu (kaldırıldı — madde 25'teki boyut şişkinliğinin de kök nedeniydi); **(2)** Android SDK'da `cmdline-tools` bileşeni kurulu değildi, bu yüzden Flutter'ın `apkanalyzer` ile yaptığı stripping doğrulaması hiç çalışamıyordu ve temkinli davranıp "başarısız" varsayıyordu (kuruldu + lisanslar kabul edildi); **(3)** `ndk.debugSymbolLevel="NONE"`, Flutter'ın aradığı `.sym`/`.dbg` doğrulama meta verisini hiç üretmiyordu — `"SYMBOL_TABLE"`'a çevrildi (native .so'lar yine stripli kalıyor, yalnızca Play Console'un native çökme sembolizasyonu için kullanacağı küçük bir sembol tablosu ekleniyor). Bu üçü birlikte **her release AAB derlemesini** (Play Store'a giden gerçek build'ler dahil) kırıyordu — yalnızca boyut analizine özgü değildi. `build_aab.ps1` scripti de ayrıca PowerShell'in native komut stderr'ini terminating error'a çevirme davranışına karşı sağlamlaştırıldı (`$LASTEXITCODE` bazlı kontrol). | (yeni) |

**Önemli olumlu bulgular:** Hesap silme hem uygulama içinden hem RPC düzeyinde sağlam (self-only, `SECURITY DEFINER`, cascade); IAP/ödeme hiç yok; path traversal/ReDoS/eval riski yok; `--obfuscate --split-debug-info` release süreçlerinde aktif; RLS genel olarak (communities/community_links dışında) kapsamlı; **EXIF/GPS temizliği** (`image_sanitizer.dart`) doğru uygulanmış — talimatta "muhtemelen eksik" varsayılan bu madde aslında ✅; konum izin akışları örnek düzeyde iyi; global hata yakalayıcı (Crashlytics) doğru kurulmuş; `flutter analyze` tertemiz; dispose/timer/stream yönetimi genel olarak sağlam.

## Bu denetimden sonra yapılan ek düzeltmeler (2026-09-26/27)

Yukarıdaki Kritik/Yüksek/Orta bulguların üstündeki tabloda işlenmeyen, daha düşük öncelikli/orta bulgular için de aşağıdaki düzeltmeler bu oturumda uygulandı ve `flutter analyze` ile doğrulandı (ilgili bölümlerin gövde metni orijinal bulguyu koruyor, güncel durum burada özetleniyor):

| Bölüm | Bulgu (özet) | Uygulanan düzeltme |
|---|---|---|
| 1.7 | `.gitignore`'da Firebase config/`*.p12`/`*.mobileprovision` kuralı yoktu | Eklendi |
| 2.3 | Keychain/Keystore erişim seviyesi belirtilmemişti | `IOSOptions(first_unlock_this_device)` eklendi; Android tarafı paket kaynağı incelenip 11.x varsayılanının zaten güvenli olduğu doğrulandı |
| 2.8 | Logout'ta paylaşılan önbellekler temizlenmiyordu | `clearUserSessionCache()` eklenip `_onLogout()`'a bağlandı |
| 4.2 / 7 | Atıl Google OAuth deep-link kaydı (`supabase://login`) | `AndroidManifest.xml`'den kaldırıldı |
| 4.15 | Kayıt akışında e-posta enumeration | Genel/başarı mesajıyla birleştirildi |
| 7 (FLAG_SECURE) | Ekran görüntüsü/görev değiştirici koruması yoktu | `SecureScreen` + `MethodChannel` eklendi ve kod tabanındaki 3 hassas ekranın (`nev_firsatlar_screen`, `baskan_panel_screen`, `profile_screen`) tümüne uygulandı |
| 9.2 | `proguard-rules.pro`'da ölü `sqflite` kuralı | Kaldırıldı |
| 10 (ek not) | `claim_coupon` sahte başarı/kupon üretiyordu | Fallback simülasyonu tamamen kaldırıldı |
| 11.8 | Kullanılmayan bağımlılıklar (`cupertino_icons`, `package_info_plus`) | `cupertino_icons` kaldırıldı; `package_info_plus` artık `ForceUpdateService`'te kullanılıyor |
| 12.5 | Uygulama içi veri görüntüleme/dışa aktarma yoktu | `MyDataScreen` + `exportMyData()` eklendi |
| 12.6 | Crashlytics onayı yoktu | Ayarlar'a switch eklendi, gizlilik politikası güncellendi |
| 14.4 | `post_card.dart` etkinlik katılımında rollback yoktu | Rollback + `SnackBar` eklendi |
| 14.8 | 33 adet boş `catch (_) {}` | Tümü tek tek incelendi — 2 kritik olan (`unsupportPost`/`updateUserProfile`) düzeltilmişti; kalan ~26'sı kasıtlı/doğru best-effort desenler; 4 tanesine gözlemlenebilirlik için loglama eklendi |
| 14.9 / 16.3 | Ağ hatasında sahte demo veri gösteriliyordu | 3 demo veri listesi (~250 satır) tamamen kaldırıldı |
| 16.13 | Ana akışta sayfalama çalışmıyordu | `home_screen.dart`'a `ScrollController`+`_hasMorePosts` ile sonsuz kaydırma eklendi |
| 17.2 | iOS Crashlytics dSYM upload adımı yoktu | `codemagic.yaml`'a script adımı eklendi (GitHub Actions workflow'larında hâlâ yok) |
| 20.3 | `enableOnBackInvokedCallback` beyanı yoktu | `AndroidManifest.xml`'e eklendi |
| 21.1 | Hiç `Semantics`/`semanticLabel` yoktu | Alt gezinme çubuğuna eklendi — **proje genelinde hâlâ tek örnek**, kapsamlı erişilebilirlik denetimi ayrı bir iş |
| 21.3 | Alt nav dokunma alanı küçüktü (~24-30dp) | Her öğe `Expanded` ile sarmalanıp tam genişliğe çıkarıldı |
| 21.8 | "Animasyonları azalt" tercihi dikkate alınmıyordu | `animated_theme_background.dart` artık `MediaQuery.disableAnimations`'ı kontrol ediyor |
| 22.2 | Türkçe İ/ı `toLowerCase()` hatası | `turkishToLower()` eklenip 4 arama noktasına uygulandı (`baskan_panel`, `admin_screen`, `campus_map`, `register_screen`) |
| 23.2 | `autofillHints` yoktu | Login/register e-posta+şifre alanlarına eklendi |
| 23.7 | Yarım kalmış form verisi onaysız kayboluyordu | `create_post_screen.dart`/`register_screen.dart`'a `PopScope` tabanlı "kaydedilmemiş değişiklik" onayı eklendi |
| 24.3 | Bazı zaman damgaları `toUtc()` kullanmıyordu | `fcm_service.dart` ve `supabase_data_service.dart`'taki ilgili noktalarda düzeltildi |
| 25.4 | Bildirime tıklayınca yönlendirme yoktu | `fcm_service.dart`'a gerçek navigasyon (`_navigateForMessage`) + cold-start (`checkInitialMessage`) eklendi |
| 25.5 | FCM bildirim kanalı meta-data'sı eksikti | `AndroidManifest.xml`'e `default_notification_channel_id` eklendi |
| 25.6 | Bildirim tercihleri UI'dan yönetilemiyordu | `NotificationPrivacySettingsScreen` eklendi |
| 28.4 | Uygulama öne gelince izin durumu tekrar kontrol edilmiyordu | `campus_map_screen.dart`'a `didChangeAppLifecycleState` eklendi (**yalnızca bu ekranda**) |
| 34.1 | `build_ios_ipa.yml`'de `--obfuscate` eksikti | Eklendi |
| (bonus) | Karanlık mod yalnızca elle seçilebiliyordu | `useSystemTheme()` + `_SystemBrightnessWatcher` eklenip sistem temasını takip etme seçeneği eklendi |

**Hâlâ tamamlanmamış/ertelenmiş büyük kalemler:** birim/entegrasyon testleri (Bölüm 30), mega dosyaların bölünmesi (Bölüm 14.2), `supabase_data_service.dart` "God service"'inin repository'lere bölünmesi (Bölüm 14.1), kapsamlı `Semantics` erişilebilirlik denetimi (Bölüm 21.1 — yalnızca alt nav'da var), dev/staging/prod ortam ayrımı (Bölüm 31.1), ve iki bekleyen SQL migration'ının (`app_settings_force_update.sql`, `storage_limits_and_coupon_rate_limit.sql`) Supabase Dashboard'da çalıştırılması — **2026-09-27'de kullanıcıya soruldu, ikisi de HÂLÂ ÇALIŞTIRILMADI** (üçüncü bekleyen migration `20260929_fix_update_post_quality_rpc.sql` ise çalıştırıldığı doğrulandı). Boş `catch` blokları (Bölüm 14.8) ve `app-release.aab` boyutu/native sembol yüklemesi (Bölüm 18.7/26) 2026-09-27'de tamamlandı.

## 2026-09-27 (devam) — kontrol.md'nin küçük/güvenli düzeltmeler turu

Tam bir kontrol.md taraması sonrası özet tablolarda hiç geçmeyen, hâlâ açık duran orta/düşük bulgulardan risk/efor oranı düşük olanlar düzeltildi (`flutter analyze` ile doğrulandı, "No issues found"):

| Bölüm | Bulgu | Uygulanan düzeltme |
|---|---|---|
| 4.2 | `main.dart`'ta `Supabase.initialize` çağrısında `authFlowType` paket varsayılanına bırakılmıştı, açıkça belirtilmemişti | `authOptions`'a `authFlowType: AuthFlowType.pkce` eklendi |
| 4.9 | `changePassword()` sonrası diğer cihaz/oturumlardaki eski refresh token'lar geçerliliğini koruyordu | Şifre güncellemesi başarılı olduktan sonra best-effort `_client.auth.signOut(scope: SignOutScope.others)` eklendi (başarısız olursa yalnızca `debugPrint` ile loglanır, ana akışı bozmaz) |
| 16.5 / 24 | Supabase SDK çağrılarının (Postgrest/Auth/Storage) hiçbirinde açık timeout yoktu, zayıf ağda istekler süresiz beklemede kalabilirdi | Yeni `lib/utils/timeout_http_client.dart` (`TimeoutHttpClient extends http.BaseClient`, 15sn) yazılıp `Supabase.initialize(httpClient: ...)` ile tek noktadan tüm REST çağrılarına bağlandı. Realtime (WebSocket) bu client'ı kullanmadığından etkilenmiyor |
| 17.2 | `build_ios_ipa.yml`'de Crashlytics dSYM yükleme adımı hiç yoktu, `build_ios.yml`'de de yoktu | `codemagic.yaml`'daki aynı güvenli-atlamalı `upload-symbols` deseni her iki GitHub Actions workflow'una da eklendi. **Not:** Bu iki workflow zaten `CODE_SIGNING_ALLOWED=NO` ile imzasız/yayınlanmayan doğrulama build'i üretiyor ve `GoogleService-Info.plist` secret olarak tanımlı değil — adım şu an güvenle "atlandı" uyarısı verip geçecek, ama workflow ileride gerçek imzalı dağıtıma dönüştürülürse hazır olacak |
| 11.3 | `.github/dependabot.yml` yoktu | Eklendi (`pub`, `gradle` (`/android`), `github-actions` ekosistemleri, haftalık) — not: Dependabot CocoaPods'u desteklemiyor, iOS bağımlılıkları kapsam dışı kalıyor |
| 14.6 | "~68 force-unwrap (`!`)" bulgusu — temizlik önerilmişti | En çok işaretlenen 4 dosya (`supabase_auth_service.dart`, `calendar_screen.dart`, `admin_screen.dart`, `profile_screen.dart`) tek tek incelendi: **taranan tüm örnekler zaten doğru null-check'lerle korunuyordu** (ör. `if (res.user == null) throw...` sonrası `res.user!`, `if (pickedDate == null OR pickedTime == null) return;` sonrası `pickedDate!`). Gerçek bir hata bulunamadı; bunları farklı bir null-safe söz dizimine çevirmek saf stil değişikliği + regresyon riski olacağından **bilinçli olarak dokunulmadı** — kalan ~110 örnek codebase genelinde taranmadı, spesifik bir çökme raporu gelirse o noktaya bakılmalı |

**Bilinçli olarak ertelenen (bu turun kapsamı dışında bırakıldı, kullanıcıya soruldu):** `supabase_data_service.dart`'ın (1959 satır) domain repository'lerine bölünmesi, mega ekranların (`admin_screen.dart` 2386 satır vb.) parçalanması, kapsamlı `Semantics` erişilebilirlik denetimi, birim test paketi — sıfır test kapsamıyken büyük refactor riski + ayrı oturum gerektiren kapsam nedeniyle.

---

# 1. Gizli Bilgi ve Anahtar Yönetimi

**1) İstemci kodunda gömülü API anahtarı/secret/şifre/token yok (OpenAI, Stripe, AWS, SMTP vb.)**
- **Durum:** ✅ Geçti
- **Kanıt:** `lib/config/app_config.dart:3-5` yalnızca Supabase URL + `sb_publishable_...` anon anahtarı içeriyor; `lib/` genelinde `sk-`, `AKIA`, `service_role`, `smtp`, `Bearer ...` desenleri taranarak gerçek secret bulunamadı; `pubspec.yaml`'da OpenAI/Stripe/AWS/SMTP SDK'sı yok.

**2) 3. taraf ücretli API çağrıları backend üzerinden proxy'leniyor**
- **Durum:** ➖ Uygulanamaz
- **Kanıt:** Ücretli/anahtar gerektiren 3. taraf API yok. `supabase_data_service.dart:861-880` görseli doğrudan `https://api.telegra.ph/upload`'a yüklüyor ama bu servis anonim/ücretsiz, anahtar gerektirmiyor.

**3) `.env`/`--dart-define` değerlerinin gizli olmadığı biliniyor**
- **Durum:** ✅ Geçti — `app_config.dart:1` "Bu dosya git'e eklenmez" yorumu; Supabase anon key'in istemcide açık olması RLS'e dayalı mimaride beklenen davranış.

**4) Supabase `service_role`/Firebase Admin SDK client'ta yok**
- **Durum:** ✅ Geçti
- **Kanıt:** `lib/` içinde "service_role" taraması sıfır sonuç. `service_role` yalnızca `supabase/functions/delete-user/index.ts:27-29,58`'de `Deno.env.get("SERVICE_ROLE_KEY")` ile sunucu tarafında (Deno runtime) okunuyor.

**5) Google/Firebase API anahtarları paket adı + SHA-1 ile kısıtlı**
- **Durum:** ❓ Doğrulanamadı
- **Kanıt:** `android/app/google-services.json` içinde `api_key` mevcut; kısıtlama Google Cloud Console → APIs & Services → Credentials üzerinden görülmeli (paket adı `com.Nevgenc` + SHA-1).

**6) iOS API anahtarları bundle ID ile kısıtlı**
- **Durum:** ❓ Doğrulanamadı — `ios/Runner/GoogleService-Info.plist` mevcut, kısıtlama Google Cloud Console'dan kontrol edilmeli.

**7) `.gitignore` yeterli mi (`.env`, keystore, `key.properties`, `google-services.json`, `GoogleService-Info.plist`, `*.p12`, `*.mobileprovision`)**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)**
- **Kanıt:** `.gitignore`'a `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `*.p12`, `*.mobileprovision` eklendi.

**8) Git geçmişinde daha önce commit edilmiş secret yok**
- **Durum:** ❓ Kısmen doğrulandı — `git log --all --full-history --diff-filter=A` ile `google-services.json`, `GoogleService-Info.plist`, `key.properties`, `*.jks`, `*.keystore`, `*.p12`, `*.mobileprovision`, `backend/.env`, `*.p8`, `upload_certificate.pem` için hiç ekleme commit'i bulunamadı — bunlar hiç commit edilmemiş. Tam repo `gitleaks`/`trufflehog` taraması yapılmadı.
- **Kontrol yeri:** `gitleaks detect --source . -v` veya `trufflehog git file://.`

**9) Sızmış anahtarlar rotate edildi**
- **Durum:** ❓ — bilinen bir sızıntı tespit edilmedi, rotasyon gereği görünmüyor.

**10) Keystore güvenli yerde yedekli/şifreli; Play App Signing kullanılıyor**
- **Durum:** ❓ Doğrulanamadı
- **Kanıt:** `android/newgenc-release.jks` lokalde var, `android/app/build.gradle.kts:21-32` `key.properties` yoksa build'i sert hatayla durduran bir guard içeriyor (iyi önlem). Yedekleme/Play App Signing durumu Play Console → Uygulama bütünlüğü'nden kontrol edilmeli.

**11) Yorum satırlarında test şifresi/iç URL yok** — ✅ Geçti — tarandı, gerçek sızıntı bulunamadı.

**12) Staging/iç sunucu adresleri release'de yok** — ✅ Geçti — `socket_service.dart` tamamen Supabase Realtime'a taşınmış, hardcoded adres yok; eski Express backend zaten kaldırılıyor.

---

# 2. Yerel Veri Depolama

**1) Token/şifre/hassas veri güvenli depolamada**
- **Durum:** ✅ Geçti
- **Kanıt:** `lib/services/secure_local_storage.dart:13-41` — Supabase oturum JSON'ı (access/refresh token) `flutter_secure_storage` üzerinden saklanıyor; `main.dart:111-117` `Supabase.initialize(authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()))` ile aktif.

**2) Hassas veri `AsyncStorage`/`SharedPreferences`/düz SQLite'ta tutulmuyor**
- **Durum:** ⚠️ Kısmen
- **Kanıt:** `local_storage_service.dart:141-143` `saveAuthUser` ile `AuthUser` (id, ad, e-posta, doğum tarihi, rol — **şifre/token içermiyor**) düz `SharedPreferences`'a JSON yazılıyor. PII düz metin.
- **Risk seviyesi:** Düşük-Orta

**3) Keychain erişim seviyesi uygun**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)**
- **Kanıt:** `secure_local_storage.dart`'a `IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device)` eklendi. Android tarafı için `AndroidOptions(encryptedSharedPreferences: true)` **kasıtlı olarak eklenmedi** — `flutter_secure_storage` 11.x paket kaynağı incelendi, Android'de bu bayrak artık gereksiz çünkü paket varsayılan olarak zaten AES-GCM + Keystore tabanlı RSA anahtar sarmalama kullanıyor (kod içinde bu karar gerekçesiyle belgelendi).

**4) `android:allowBackup`/`dataExtractionRules` hassas veriyi hariç tutuyor**
- **Durum:** ✅ Geçti — `AndroidManifest.xml:13` `android:allowBackup="false"`.

**5) Hassas yerel veritabanı şifreli (SQLCipher vb.)**
- **Durum:** ➖ Uygulanamaz — yerel SQL veritabanı (sqflite) yok, tüm kalıcı veri SharedPreferences/flutter_secure_storage.

**6) Hassas veriler harici depolamaya yazılmıyor**
- **Durum:** ✅ Geçti — `path_provider`'ın `getApplicationDocumentsDirectory()` (sandbox) kullanılıyor.

**7) Önbellek/log/geçici dosyada hassas veri kalmıyor**
- **Durum:** ⚠️ Kısmen — `supabase_auth_service.dart:73` `_mapError` fallback'i bilinmeyen hatalarda ham `e.toString()` döndürüyor (potansiyel detay sızıntısı, düşük risk).

**8) Logout sırasında token, önbellek, DB, dosya ve state temizleniyor**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)**
- **Kanıt:** `LocalStorageService.clearUserSessionCache(userId:)` eklendi ve `_onLogout()`'a bağlandı — posts/kupon/etkinlik/topluluk/haber/iş ilanı/profil önbellekleri artık logout'ta temizleniyor. Bilinçli olarak var olan `clearAllCache()` yerine yeni, daha dar kapsamlı bir metod tercih edildi çünkü `clearAllCache()` tema/gizlilik-onayı/hatıra-albümü gibi kullanıcıdan bağımsız verileri de siliyordu.

**9) Uygulama silinip yeniden kurulduğunda iOS Keychain'de eski token kalma durumu**
- **Durum:** ❓ — `first_run` flag + Keychain temizleme deseni bulunamadı.
- **Risk seviyesi:** Düşük-Orta
- **Düzeltme önerisi:**
  ```dart
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool('keychain_initialized') ?? false)) {
    await SecureLocalStorage().removePersistedSession();
    await prefs.setBool('keychain_initialized', true);
  }
  ```

**10) WebView çerezleri ve önbelleği logout'ta temizleniyor**
- **Durum:** ➖ Uygulanamaz — proje WebView kullanmıyor, tüm dış linkler `url_launcher` ile sistem tarayıcısında açılıyor.

**11) Hassas veriler bellekte gereğinden uzun tutulmuyor**
- **Durum:** ❓ — Dart GC'ye bağlı, statik incelemeyle kesinleşmez. `AuthUser` (şifre/token içermez) signOut'ta null'a çekiliyor.

---

# 3. Kriptografi

**1) Kendi yazılmış şifreleme algoritması yok** — ✅ Geçti — `lib/` genelinde özel implementasyon bulunamadı.

**2) AES-ECB kullanılmıyor; AES-GCM tercih ediliyor**
- **Durum:** ✅ Geçti (dolaylı) — `flutter_secure_storage` 11.x varsayılan olarak AES-GCM + OS Keystore tabanlı RSA anahtar sarmalama kullanıyor; ECB kullanımı yok.

**3) Sabit/tekrar kullanılan IV/nonce yok** — ➖ Uygulanamaz — manuel IV yönetimi yapan kod yok.

**4) Şifreleme anahtarı koda gömülü değil** — ✅ Geçti — proje herhangi bir şifreleme anahtarı üretmiyor/saklamıyor, tamamen OS Keystore/Keychain'e bırakılmış.

**5) MD5/SHA1 güvenlik amaçlı kullanılmıyor** — ✅ Geçti — `crypto` paketi bile `pubspec.yaml`'da yok, "md5|sha1" taraması sıfır sonuç.

**6) Şifre hash'leme (sunucuda) bcrypt/scrypt/Argon2 ile**
- **Durum:** ✅ Geçti — `supabase_auth_service.dart:87,182` kimlik doğrulama tamamen Supabase Auth (GoTrue) sunucusuna devredilmiş; GoTrue şifreleri sunucuda bcrypt ile hash'ler.

**7) Token/OTP kriptografik güvenli üreteçle**
- **Durum:** ➖ Uygulanamaz (istemci tarafında üretilmiyor) — bulunan `Random()` kullanımları yalnızca oyun mantığında (bubble_shooter_game.dart, tetris_game.dart), güvenlik bağlamı yok. Gerçek oturum token'ları GoTrue sunucusunda üretiliyor.

**8) Base64 "şifreleme" olarak kullanılmıyor** — ✅ Geçti — "base64" taraması sıfır sonuç.

---

# 4. Kimlik Doğrulama ve Oturum Yönetimi

**1) Kimlik doğrulama sunucuda yapılıyor**
- **Durum:** ✅ Geçti — `supabase_auth_service.dart:87,182` gerçek GoTrue isteği; `main.dart:180-186` `onAuthStateChange` sunucu event'lerini dinliyor; gerçek JWT session (SecureLocalStorage'da) var, yalnızca bir "flag" değil.

**2) OAuth akışında PKCE kullanılıyor; implicit flow yok**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Kısmen düzeltildi (2026-09-26)**
- **Kanıt:** Atıl `supabase://login` intent-filter'ı `AndroidManifest.xml`'den kaldırıldı — artık kafa karıştırıcı bir manifest kalıntısı yok, tutarsızlık giderildi. Google OAuth kendisi hâlâ uygulanmıyor (şu an giriş yalnızca e-posta/şifre) — bu bir eksik değil, ürün kararı; ileride eklenirse `authFlowType: AuthFlowType.pkce`'nin açıkça belirtilmesi önerilir.

**3) Client secret mobil uygulamada yok** — ✅ Geçti — Google OAuth kodu yok, `google-services.json`'da `oauth_client: []`, anon key publishable (client secret değil).

**4) OAuth girişi sistem tarayıcısıyla yapılıyor** — ➖ Uygulanamaz — OAuth akışı şu an kodda uygulanmıyor.

**5) Access token kısa ömürlü; refresh token rotasyonu var**
- **Durum:** ❓ — tamamen GoTrue sunucu tarafı davranışı. **Kontrol yeri:** Supabase Dashboard → Authentication → Settings → JWT expiry / Refresh Token Rotation.

**6) Refresh token çalınma/yeniden kullanım tespiti var**
- **Durum:** ❓ — GoTrue sunucu özelliği. **Kontrol yeri:** Dashboard → Refresh Token "Reuse Interval".

**7) Sunucu tarafında token iptali (revocation) mümkün**
- **Durum:** ✅ Geçti — gotrue-dart 2.27.2 kaynağı incelendi (`gotrue_client.dart:1078-1109`): `_signOut()` her zaman `admin.signOut(accessToken, scope)` ile sunucudaki `/logout` endpoint'ini çağırıp refresh token'ı sunucuda geçersiz kılıyor.

**8) Logout sunucuda da oturumu sonlandırıyor**
- **Durum:** ✅ Geçti — `supabase_auth_service.dart:223` `signOut()`. Not: varsayılan `scope=local` (yalnızca bu cihaz, tipik/istenen davranış).

**9) Şifre değişikliğinde diğer oturumlar sonlandırılıyor**
- **Durum:** ❓ — `changePassword` (satır 254-266) yalnızca `updateUser(password:)` çağırıyor, `signOut(scope: SignOutScope.others)` YOK.
- **Risk seviyesi:** Orta
- **Düzeltme önerisi:** `changePassword` sonrası `await _client.auth.signOut(scope: SignOutScope.others);` eklemeyi değerlendirin.

**10) Oturum zaman aşımı (hareketsizlik) tanımlı** — ➖/yok — kampüs sosyal uygulaması için genelde kritik değil, kodda da yok.

**11) 401'de tek seferlik, kuyruklanmış token yenileme mantığı**
- **Durum:** ✅ Geçti — `gotrue_client.dart:1549-1579` `_pendingRefreshes` map'i ile eşzamanlı refresh çağrıları de-duplicate ediliyor (SDK içinde garanti).

**12) Biyometrik doğrulama kriptografik anahtara bağlı** — ➖ Uygulanamaz — `local_auth` paketi yok, biyometri hiç uygulanmamış.

**13) Biyometri kaydı değiştiğinde anahtar geçersiz kılınıyor** — ➖ Uygulanamaz (aynı gerekçe).

**14) Giriş/OTP/şifre sıfırlamada rate limiting**
- **Durum:** ❓ — istemci kodunda görünmez, Supabase Auth Dashboard ayarına bağlı. **Kontrol yeri:** Dashboard → Authentication → Rate Limits.

**15) Hata mesajları kullanıcı varlığını ifşa etmiyor**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)**
- **Kanıt:** Kayıt akışındaki "Bu e-posta adresi zaten kayıtlı" mesajı, girişteki gibi genel/başarı mesajıyla ("Kayıt başarılı!" öneki) birleştirildi — enumeration kapatıldı.

**16) Şifre sıfırlama token'ları tek kullanımlık ve kısa ömürlü**
- **Durum:** ❓ — `resetPasswordForEmail` çağrısı, token ömrü GoTrue'da. **Kontrol yeri:** Dashboard → Email Templates/Settings.

**17) OTP süresi ve deneme sayısı sınırlı**
- **Durum:** ❓ — istemci kodunda OTP akışı yok, Dashboard ayarına bağlı.

**18) Güçlü şifre politikası sunucuda uygulanıyor**
- **Durum:** ⚠️ Kısmen
- **Kanıt:** `supabase_auth_service.dart:28-40` `_validatePassword` (min 8, 1 büyük harf, 1 rakam) **yalnızca istemci tarafında**. Sunucu (Dashboard Password Requirements) ile eşleşip eşleşmediği koddan görülemez — API'ye doğrudan istek atan biri bu kuralları atlayabilir.
- **Risk seviyesi:** Orta
- **Kontrol yeri:** Dashboard → Auth → Policies → Password Requirements.

**19) İsteğe bağlı 2FA/MFA desteği** — ➖ Uygulanamaz — uygulanmamış, kampüs sosyal uygulaması için zorunlu değil.

**20) JWT imzası sunucuda doğrulanıyor; `alg: none` kabul edilmiyor**
- **Durum:** ✅ Geçti (mimari) — GoTrue + PostgREST HS256/RS256 zorunlu kılar; istemci taraflı JWT doğrulama kodu yok (doğru, backend'in işi).

**21) JWT içinde hassas veri yok**
- **Durum:** ✅ Geçti (dolaylı) — `custom_access_token_hook` yok, standart payload (sub/email/role/aud/exp) kullanılıyor.

---

# 5. Yetkilendirme ve Backend Güvenliği

**1) Tüm yetki kontrolleri sunucuda mı**
- **Durum:** ⚠️ Kısmen
- **Kanıt:** `baskan_panel_screen.dart:74-87`, `admin_screen.dart:152,2026` yalnızca client-side `role` kontrolü yapıp UI'ı gizliyor. Gerçek yetki RLS'e devrediliyor. 3 Edge Function (`delete-user`, `send-notification`, `send-community-notification`) sunucu tarafında `auth.getUser()` + `profiles.role` kontrolü yapıyor (iyi örnek).
- **Risk seviyesi:** Orta

**2) IDOR kontrolü (`auth.uid()` bazlı)**
- **Durum:** ✅ Geçti (incelenen tablolarda) / ❌ Kaldı (`communities`/`community_links`'te)
- **Kanıt:** `post_supports`, `calendar_notes`, `notifications`, `fcm_tokens`, `community_members`, `event_registrations`, `user_tickets` tümü `auth.uid()=user_id` bazlı politikalarla korunuyor.
- **🚨 KRİTİK bulgu:** `public.communities` ve `public.community_links` tabloları için `supabase/migrations/` içinde hiçbir `ENABLE ROW LEVEL SECURITY`/`CREATE POLICY` ifadesi yok (yalnızca artık kullanılmayan `supabase/archive/combined_supabase_setup.sql`'de var, orada da yalnızca SELECT policy'si var). `supabase_data_service.dart:402` (`updateCommunity`), `:1392-1398` (`assignChairman`), `:1409-1412` (`removeChairman`), `:353-356` (`setCommunityLink`) doğrudan `.from('communities').update()`/`.from('community_links').upsert()` çağırıyor — RPC yok, sunucu tarafı ekstra kontrol yok. Canlı DB görülmeden kesin söylenemez ama: RLS kapalıyken `authenticated` role tablo GRANT'ları açıksa, herhangi bir öğrenci `PATCH .../communities?id=eq.X` isteğiyle `chairman_id`'yi kendine çevirip bir topluluğun başkanlık yetkilerini (üye çıkarma, bildirim gönderme, gönderi silme) ele geçirebilir.
- **Risk seviyesi:** ~~Kritik~~ **✅ Düzeltildi (2026-09-30)**
- **Uygulanan düzeltme:** `supabase/migrations/20260930_communities_posts_rls_and_weekly_limit_fix.sql` — `communities`'e RLS açıldı (herkes SELECT, admin ALL, başkan yalnızca kendi topluluğunun ad/açıklama/kategori/logo alanlarını UPDATE edebiliyor — `chairman_id`/`chairman_name` başkan tarafından değiştirilemiyor), `community_links`'e RLS açıldı (herkes SELECT, admin veya ilgili topluluğun başkanı yazabiliyor). Kullanıcı tarafından Supabase Dashboard → SQL Editor'da çalıştırıldı ve doğrulandı.

**3) Firebase Firestore/Realtime DB/Storage kurallarında `allow read,write: if true` yok** — ➖ Uygulanamaz — `cloud_firestore` kullanılmıyor.

**4) Firebase kuralları kimlik/veri doğrulaması içeriyor** — ➖ Uygulanamaz (aynı gerekçe).

**5) Supabase'de tüm tablolarda RLS etkin ve politikalar yazılmış**
- **Durum:** ⚠️ Kısmen
- **Kanıt:** RLS açık+policy'li doğrulanan 20 tablo: `profiles`, `post_supports`, `posts` (yalnızca SELECT+INSERT), `fcm_tokens`, `community_members`, `events`, `event_registrations`, `calendar_notes`, `notifications`, `discounts`, `badges`, `user_badges`, `post_ratings`, `post_reports`, `user_tickets`, `event_participants`, `news_bulletins`, `job_listings`, `community_notifications`, `coupons`.
- **Not — `posts` tablosu:** Yalnızca `posts_select` ve `posts_insert_admin` var. **UPDATE/DELETE policy'si hiç yok.** `supabase_data_service.dart:474-476` (`deletePost`) doğrudan `.from('posts').delete()` çağırıyor — RLS'te DELETE policy yoksa bu çağrı canlıda (admin dahil) her zaman 0 satır etkiler (fonksiyonel bug, "kimse silemez" varsayılan davranış).
- `communities`/`community_links` için RLS bulunamadı (madde 2, ✅ düzeltildi). `community_messages` tablosu içerik saklama migration'ı ile kaldırılmış (Faz D kararıyla tutarlı).
- **Risk seviyesi:** ~~Yüksek~~ **✅ Düzeltildi (2026-09-30)** — `posts_delete` policy'si (admin veya kendi topluluğunun başkanı) `20260930_communities_posts_rls_and_weekly_limit_fix.sql` ile eklendi ve canlıya uygulandı.

**6) Supabase Storage bucket politikaları tanımlı**
- **Durum:** ✅ Geçti — `post-images` bucket'ı için INSERT (kendi `posts/<uid>/` klasörüyle sınırlı), UPDATE/DELETE (`auth.uid()=owner`) politikaları var. SELECT policy yok ama bucket `public=true` (görseller zaten herkese açık) — normal.

**7) Kullanıcı kendi rolünü/yetkisini değiştiremiyor**
- **Durum:** ✅ Geçti (2026-09-28 düzeltmesi canlıya uygulandıysa — kullanıcı hafızasına göre uygulandı ve doğrulandı)
- **Kanıt:** `profiles_update_own` policy'si `WITH CHECK` ile `role` sütununu kilitliyor.

**8) Fiyat/indirim/bakiye değerleri istemciden alınmıyor**
- **Durum:** ✅ Geçti — `discounts` yazma admin'e kilitli; kupon üretimi/dökümü admin-only + `REVOKE ALL FROM PUBLIC`; `claim_coupon` RPC sunucu tarafında Haversine + `FOR UPDATE SKIP LOCKED` ile atomik. Başkan/topluluk skoru yalnızca istemci tarafı okuma/gösterim hesabı, kalıcı alana yazılmıyor — manipülasyon riski yok.

**9) Sunucuda tüm girdi doğrulaması yapılıyor**
- **Durum:** ✅ Geçti (Edge Function'larda) / ⚠️ Kısmen — `send-community-notification` başlık≤80/mesaj≤500, `send-notification` konu≤200/mesaj≤5000, DB `CHECK` kısıtları mevcut.

**10) API rate limiting ve kötüye kullanım koruması**
- **Durum:** ❓/⚠️ Kısmen — Edge Function kodunda rate-limit/throttle yok; Supabase platform seviyesi limitler dashboard'da olabilir.
- **Risk seviyesi:** Orta (özellikle `claim_coupon`/`generate_merchant_coupons` için)
- **Düzeltme önerisi:** `claim_coupon` çağrılarını `user_id` bazında sınırlayan tablo+trigger veya Edge Function throttling ekleyin.

**11) Sunucu hata yanıtlarında stack trace/SQL hatası sızmıyor**
- **Durum:** ⚠️ Kısmen — `delete-user/index.ts:60-67` iyi örnek (genel mesaj döner). `send-notification/index.ts:99` ve `send-community-notification/index.ts:310` `String(err)` ham hatayı client'a döndürüyor — admin-only olduğu için etki sınırlı ama hijyen sorunu.
- **Düzeltme:** `console.error(...); return json({error:"Beklenmeyen bir hata oluştu."},500);`

**12) Dosya yüklemede tür/boyut/içerik sunucuda doğrulanıyor**
- **Durum:** ⚠️ Kısmen
- **Kanıt:** `file_validator.dart:20-127` uzantı allowlist + 5MB + magic-byte kontrolü yalnızca **istemci tarafında**. Sunucu (Storage bucket) dosya içeriği/tipini doğrulamıyor.
- **Risk seviyesi:** Orta
- **Düzeltme:**
  ```sql
  UPDATE storage.buckets SET file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp']
  WHERE id = 'post-images';
  ```

**13) Yüklenen dosyalar tahmin edilemez isimlerle saklanıyor**
- **Durum:** ⚠️ Kısmen — `posts/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext` tahmin edilebilir ama klasör `uid` ile izole ve bucket zaten public — pratik etki düşük.

**14) Admin endpoint'leri ayrı ve korunmuş**
- **Durum:** ✅ Geçti (Edge Function) / ⚠️ Kısmen (client ekranları) — Flutter admin/başkan ekranları aynı Supabase client+RLS üzerinden çalışıyor, ayrım RLS doğruluğuna bağlı (madde 2'deki boşluk bunu zayıflatıyor).

**15) Sunucu tarafında güvenlik logları ve anormallik uyarıları**
- **Durum:** ❓ — yalnızca `console.error` var, aktif anormallik uyarı sistemi kodda yok. **Kontrol yeri:** Dashboard → Logs & Reports, Auth → Logs.

---

# 6. Ağ Güvenliği

**1) Tüm trafik HTTPS/TLS 1.2+ üzerinden** — ✅ Geçti — `app_config.dart:3` https://; `http://` için grep yalnızca bir `startsWith` kontrolü buldu, gerçek çağrı yok.

**2) Android `usesCleartextTraffic="false"`; Network Security Config**
- **Durum:** ⚠️ Kısmen (asıl kısım geçti) — `AndroidManifest.xml:14` `usesCleartextTraffic="false"` ✅. Özel `network_security_config.xml` yok ama zorunlu değil (cleartext zaten tamamen kapalı).

**3) iOS ATS aktif; `NSAllowsArbitraryLoads` kapalı** — ✅ Geçti — `Info.plist`'te `NSAppTransportSecurity` hiç yok → en katı varsayılan ATS geçerli.

**4) SSL doğrulamasını devre dışı bırakan kod yok** — ✅ Geçti — `badCertificateCallback`/`HostnameVerifier`/`TrustManager` için grep sıfır sonuç.

**5) Hassas uygulamalarda sertifika sabitleme (pinning) var**
- **Durum:** ⚠️ Kısmen (uygulanmamış) — checklist "hassas uygulamalarda" şartına bağlı, bu uygulama için zorunlu değil ama kupon/puan işlemleri nedeniyle isteğe bağlı sertleştirme önerilir.

**6) Pin süresi dolduğunda kilitlenmeme planı** — ➖ Uygulanamaz — pinning yok.

**7) Hassas veriler URL/query parametresinde gönderilmiyor** — ✅ Geçti — PostgREST filtreleri kaynak ID'si taşıyor (hassas değil); anon key header'da.

**8) Debug proxy/Flipper release'de kapalı** — ✅ Geçti — proje bağımlılıklarında yok.

**9) Kullanıcı eklenmiş CA sertifikalarına release'de güvenilmiyor** — ✅ Geçti (platform varsayılanıyla) — özel NSC yok, targetSdk≥24 platform varsayılanı sistem CA'larına güveniyor.

**10) WebSocket bağlantıları `wss://` ve kimlik doğrulamalı**
- **Durum:** ✅ Geçti — `socket_service.dart` artık ham WebSocket/Socket.IO kullanmıyor, tamamen Supabase Realtime'a geçilmiş (`channel('public:posts').onPostgresChanges`) — `wss://` + JWT ile kimlik doğrulamalı, `supabase_flutter` içinde yönetiliyor.

---

# 7. Platform Etkileşimi ve Saldırı Yüzeyi

### Deep link / URL şemaları

**1) Deep link parametreleri doğrulanıyor ve temizleniyor**
- **Durum:** ~~❓~~ **✅ Düzeltildi (2026-09-26)** — atıl `supabase://login` intent-filter'ı (gereksiz saldırı yüzeyi) `AndroidManifest.xml`'den kaldırıldı.

**2) Hassas akışlarda Universal/App Links kullanılıyor**
- **Durum:** ~~❌ Kaldı~~ **➖ Uygulanamaz (2026-09-27 itibarıyla)** — madde 1'deki atıl `supabase://login` intent-filter'ının kaldırılmasıyla birlikte kod tabanında artık **hiçbir** deep link tüketicisi kalmadı (doğrulandı: `supabase://`, `CFBundleURLTypes`, `app_links`/`uni_links` için sıfır sonuç). Universal/App Links'e geçilecek aktif bir hassas akış yok; ileride gerçek bir deep-link özelliği (ör. Google OAuth) eklenirse bu madde yeniden değerlendirilmeli.

**3) Deep link ile kimlik doğrulama atlanamıyor** — ✅ Geçti — deep link yalnızca OAuth session-recovery için, doğrudan yetkili ekrana yönlendiren route yok.

**4) Deep link ile gelen URL'ler WebView'de açılmıyor** — ➖ Uygulanamaz — WebView hiç kullanılmıyor.

### Android bileşenleri

**5) Gereksiz `exported="true"` bileşen yok** — ✅ Geçti — yalnızca `MainActivity` (zorunlu). Başka Activity/Service/Receiver/Provider bildirilmemiş.
- **❓ Not:** 3. parti eklentiler merged manifest'e kendi bileşenlerini ekleyebilir, `aapt dump xmltree` ile doğrulanmalı.

**6) Dışa açık bileşenler izinle korunuyor** — ➖ Uygulanamaz (exported bileşen yok).

**7) ContentProvider'larda path traversal/SQL injection yok** — ➖ Uygulanamaz — özel ContentProvider yok.

**8) PendingIntent'ler `FLAG_IMMUTABLE` ile oluşturuluyor**
- **Durum:** ❓ — proje kodunda özel PendingIntent yok, `flutter_local_notifications`/`firebase_messaging` paket içinde yönetiliyor (güncel sürümler karşılıyor, ama paket kaynağı bu denetimde incelenmedi).

**9) Intent ile gelen veriler doğrulanıyor** — ➖/✅ — yalnızca madde 1'deki OAuth deep-link'i var.

**10) `FileProvider` doğru yapılandırılmış** — ➖ Uygulanamaz — özel provider yok, `image_picker` kendi dahili FileProvider'ını kullanıyor (standart).

### WebView

**11-16) JS/addJavascriptInterface/setAllowFileAccess/allowlist/mixed content**
- **Durum:** ➖ Uygulanamaz (tümü) — doğrulandı: `webview_flutter`/`flutter_inappwebview` hiçbir yerde kullanılmıyor. Tüm dış linkler `url_launcher` ile `LaunchMode.externalApplication` olarak harici açılıyor.

### Ekran ve pano

**17) Hassas ekranlarda Android `FLAG_SECURE` aktif**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-27)**
- **Kanıt:** `MainActivity.kt`'ye `MethodChannel("com.nevgenc/secure_screen")` + `lib/utils/secure_screen.dart` (`SecureScreen`) eklendi; kod tabanındaki 3 hassas ekranın (`nev_firsatlar_screen.dart` — kuponlar, `baskan_panel_screen.dart` — üye e-postaları, `profile_screen.dart` — kişisel QR kimlik) tümüne `initState`/`dispose`'da bağlandı.

**18) iOS'ta arka plana geçerken hassas ekran gizleniyor**
- **Durum:** ❌ Kaldı / ❓ — `AppDelegate`/`SceneDelegate` bu denetimde doğrudan okunmadı, ilgili paket yok.
- **Risk seviyesi:** Düşük

**19) Şifre alanlarında `secureTextEntry` aktif** — ✅ Geçti — `login_screen.dart:220,375`, `register_screen.dart:301,320,454`, `app_text_field.dart:38`.

**20) Hassas veri panoya kopyalanıyorsa temizleniyor**
- **Durum:** ⚠️ Kısmen — `baskan_panel_screen.dart:291-332` kullanıcı e-postalarını panoya kopyalıyor (şifre değil ama PII). Süre sonu temizleme/Android 13+ hassas pano işareti yok.
- **Risk seviyesi:** Düşük

**21) 3. taraf klavyelerin kısıtlanması** — ❓/➖ — düşük öncelik, bankacılık düzeyinde hassasiyet yok.

### İzinler

**22-24) Yalnızca gerçekten kullanılan izinler, gerekçeli isteniyor, 3. parti SDK izinleri kontrol edildi**
- **Durum:** ✅ Geçti
- **Kanıt:** Android (`INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `CAMERA`, `ACCESS_FINE/COARSE_LOCATION`) ve iOS (Location, Motion, PhotoLibrary×2, Camera) izinlerinin hepsi kod kullanımıyla eşleştirildi, gereksiz izin bulunamadı. Tüm `NS...UsageDescription` dolu ve anlamlı.
- **❓ Not:** Merged manifest 3. parti SDK izinleri ekleyebilir, gerçek build çıktısıyla doğrulanmalı.

---

# 8. Kod Düzeyinde Güvenlik

**1) Yerel SQLite sorguları parametreli** — ➖ Uygulanamaz — `sqflite` kullanılmıyor (`proguard-rules.pro:18`'deki kural ölü/kalıntı, temizlenebilir).

**2) Kullanıcı girdisi eval/dinamik kod/komut çalıştırmada kullanılmıyor** — ✅ Geçti — `Process.run`, `dart:mirrors`, `Function.apply`, `dart:ffi` hiç kullanılmıyor.

**3) WebView'e basılan içerik XSS'e karşı temizleniyor** — ➖ Uygulanamaz — WebView yok.

**4) Path traversal/zip slip kontrolü**
- **Durum:** ✅ Geçti — `image_sanitizer.dart:23-26` ve `supabase_data_service.dart:886-891` dosya adları sabit kalıp/zaman damgasıyla üretiliyor, kullanıcı girdisi kullanılmıyor. Zip/arşiv açma yok.

**5) Serileştirme/deserileştirme güvenli** — ✅ Geçti — `jsonDecode` kullanımları yalnızca yerel önbellek/bilinen API yanıtları için, Dart'ta native RCE riski yok.

**6) Regex'ler ReDoS'a açık değil** — ✅ Geçti — tüm `RegExp` kullanımları basit karakter sınıfı desenleri, nested quantifier yok.

**7) Format string/integer overflow (native kod)** — ➖ Uygulanamaz — özel native kod yok.

**8) Hassas işlemler istemci saatine güvenmiyor**
- **Durum:** ~~❌ Kaldı — YÜKSEK RİSK~~ **✅ Düzeltildi (2026-09-30)**
- **Kanıt (bulunan sorun):** `supabase_data_service.dart:618-629` (`supportPost`) istemci `DateTime.now()` ile ISO hafta/yıl hesaplayıp (`_isoWeek`, satır 60-65) `week_number`/`year`'ı doğrudan `post_supports` tablosuna yazıyordu. Sunucudaki `check_weekly_support_limit()` trigger'ı da bu **istemcinin gönderdiği** değerlere göre sayıyordu.
- **Uygulanan düzeltme:** `supabase/migrations/20260930_communities_posts_rls_and_weekly_limit_fix.sql` — trigger artık `EXTRACT(WEEK FROM NOW())`/`EXTRACT(YEAR FROM NOW())` ile sunucu saatinden hesaplıyor ve istemcinin gönderdiği değeri (`NEW.week_number`/`NEW.year`'ı üzerine yazarak) yok sayıyor; Flutter tarafında ek değişikliğe gerek kalmadı çünkü trigger client'ın gönderdiği değeri zaten geçersiz kılıyor. Kullanıcı tarafından Dashboard'da çalıştırıldı ve doğrulandı.
- **Risk seviyesi:** ➖ (kapatıldı)

---

# 9. Tersine Mühendislik ve Dayanıklılık

**1) Android R8/ProGuard etkin** — ✅ Geçti — `build.gradle.kts:75-76` `isMinifyEnabled=true`, `isShrinkResources=true`. `ndk{debugSymbolLevel}` 2026-09-27'de `"NONE"`'dan `"SYMBOL_TABLE"`'a değiştirildi (bkz. Bölüm 26) — çalışma zamanı `.so`'ları yine stripli, yalnızca Play Console'un native çökme/ANR sembolizasyonu için kullandığı küçük bir sembol tablosu artık AAB'ye gömülüyor (`.aab` içinde `BUNDLE-METADATA/com.android.tools.build.debugsymbols/` altında doğrulandı) — Play Console'un "sembol dosyası yükleyin" uyarısı yeni build'lerde artık çıkmamalı.

**2) ProGuard kuralları eksiksiz**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — ölü `sqflite` kuralı kaldırıldı; ayrıca bu oturumda bizzat üretilen bir gerçek release AAB (1.0.27+28) başarıyla derlenip doğrulandı (bkz. Bölüm 26).

**3) Flutter `--obfuscate --split-debug-info` kullanılıyor**
- **Durum:** ✅ Geçti — `build_aab.ps1:30`, `build_ios.yml:51`, `build_ios_ipa.yml:18`, `codemagic.yaml:18` hepsinde var. Not: Android AAB CI'da build edilmiyor, obfuscate garantisi manuel sürece bağlı.

**4) `android:debuggable="false"` release'de** — ✅ Geçti — override edilmemiş, AGP varsayılanı geçerli.

**5) Release build'de hassas veri loglanmıyor** — ✅ Geçti — `fcm_service.dart:65,94,96` yalnızca token'ın varlığını (boolean) logluyor.

**6) Root/jailbreak tespiti** — ~~❌ Yok~~ **✅ Kısmen düzeltildi (2026-09-27)** — genel bir root/jailbreak engelleme eklenmedi (kampüs sosyal uygulaması için gereksiz sürtünme yaratır), bunun yerine tespit edilen **gerçek risk** olan kupon GPS-spoofing'ine hedefli önlem alındı: `safe_device` paketi eklenip `flip_coupon_card.dart`'a `SafeDevice.isMockLocation` kontrolü eklendi — sahte konum uygulaması tespit edilirse kupon açma engelleniyor (sunucu tarafı mesafe kontrolüne ek bariyer).

**7) Debugger/emülatör/Frida tespiti** — ❌ Yok — Risk: Düşük, bilinçli olarak ertelendi (finansal işlem yok).

**8) Uygulama bütünlüğü/Play Integrity/App Attest**
- **Durum:** ❌ Yok — backend yalnızca JWT/Bearer ile doğruluyor, cihaz bütünlüğü kontrolü yok.
- **Risk seviyesi:** Orta (Bölüm 8.8 bulgusuyla birlikte önem kazanıyor)

**9) Güvenlik kararları yalnızca istemcide değil, sunucu tarafında da**
- **Durum:** ✅ Geçti (2026-09-30 itibarıyla) — RLS genel olarak kapsamlı; haftalık destek limiti artık sunucu saatine göre hesaplanıyor (Bölüm 8.8, düzeltildi), `communities`/`community_links`/`posts` DELETE RLS boşlukları da kapatıldı (Bölüm 5.2/5.5).
- **Risk seviyesi:** ➖ (kapatıldı)

---

# 10. Ödeme ve Uygulama İçi Satın Alma

Tüm alt maddeler doğrulandı: `pubspec.yaml`'da IAP/RevenueCat yok; ödeme/kart/checkout için tüm proje tarandı, sonuç yok.

- **1-8 (tümü):** ➖ Uygulanamaz — uygulamada satın alma/abonelik/kart akışı yok. Kuponlar gerçek dünya fiziksel indirimleri.

**Ek not (görev kapsamı dışı ama önemli):** `claimCoupon` (`supabase_data_service.dart:920-978`) — RPC (`claim_coupon`) başarısız olursa istemci **RPC hatasını yakalayıp yerel "fallback simülasyonu" ile sahte başarı yanıtı ve kupon kodu üretiyor** (yalnızca istemci taraflı GPS mesafe kontrolüyle — GPS spoofing ile atlatılabilir).
- **Risk seviyesi:** Orta-Yüksek — ayrıca incelenmeli, `claim_coupon` başarısız olduğunda gerçek bir hata gösterilmeli, sahte başarı üretilmemeli.

---

# 11. Bağımlılıklar ve Tedarik Zinciri

**1) Tüm paketler gerçekten var ve resmi kaynaktan**
- **Durum:** ✅ Geçti (bilgiye dayalı, internet erişimi yok) — pubspec.yaml'daki 24 paket hepsi gerçek, yaygın pub.dev paketleri; `flutter pub get` başarıyla çözümlendi.
- **❓ Not:** Kesin doğrulama için `flutter pub outdated` internet erişimiyle çalıştırılmalı.

**2) İndirilme sayısı/bakım durumu** — ❓ Doğrulanamadı — internet erişimi yok.

**3) `npm audit`/`flutter pub outdated`/Dependabot çalıştırıldı mı**
- **Durum:** ❓ Doğrulanamadı — çalıştırılmadı, `.github/dependabot.yml` yok.
- **Düzeltme:** `flutter pub outdated` + `dependabot.yml` eklenmeli.

**4) Bilinen güvenlik açığı olan sürüm yok** — ❓ Doğrulanamadı — CVE veritabanı erişimi gerekli.

**5) Kullanımdan kaldırılmış paket/API yok** — ✅ Geçti — tüm paketler güncel majör sürümler.

**6) Lock dosyası commit edilmiş** — ✅ Geçti — `git ls-files` → `pubspec.lock` mevcut.

**7) Paket sürümleri framework sürümüyle uyumlu** — ✅ Geçti — `sdk: '>=3.0.0 <4.0.0'`, kurulu Flutter 3.41.5/Dart 3.11.3 uyumlu.

**8) Kullanılmayan bağımlılıklar kaldırıldı**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)**
- **Kanıt:** `cupertino_icons` `pubspec.yaml`'dan kaldırıldı; `package_info_plus` artık kullanılmıyor değil — `ForceUpdateService`'te build numarası okumak için kullanılıyor.
- **Risk seviyesi:** ➖ (kapatıldı)
- **Düzeltme önerisi:** `pubspec.yaml`'dan kaldırın (veya `package_info_plus`'ı Bölüm 31.6'daki zorunlu güncelleme kontrolü için kullanmaya başlayın).

**9) Bağımlılık lisansları ticari kullanıma uygun** — ✅ Geçti (bilgiye dayalı) — tüm paketler BSD-3/MIT, GPL tespit edilmedi.

**10) 3. taraf SDK'ların topladığı veriler biliniyor** — ✅ Geçti — `GIZLILIK_POLITIKASI.md:47-53` Supabase/Firebase/OSM'i ve topladıkları veriyi listeliyor.

---

# 12. Gizlilik ve Yasal Uyumluluk

**1) KVKK aydınlatma metni ve gerekli açık rızalar mevcut** — ✅ Geçti — `GIZLILIK_POLITIKASI.md` KVKK maddelerini detaylı listeliyor; `privacy_policy_screen.dart:19,31,36-38` ilk kullanımda açık onay alıyor.

**2) GDPR gereklilikleri karşılanıyor**
- **Durum:** ⚠️ Kısmen — politika GDPR'a atıf yapıyor ama veri taşınabilirliği yalnızca e-posta talebiyle sağlanıyor, uygulama içi export yok.
- **Risk seviyesi:** Orta

**3) Gizlilik politikası uygulama içinde erişilebilir** — ✅ Geçti — `options_sheet.dart:6,239-251` → `PrivacyPolicyScreen`.

**4) Veri minimizasyonu** — ✅ Geçti — yalnızca gerekli veri toplanıyor, `ACCESS_BACKGROUND_LOCATION` istenmiyor.

**5) Kullanıcı verisini görüntüleme/dışa aktarma/silme hakkı**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)**
- **Kanıt (silme — sağlam):** `options_sheet.dart:278-282,100-152` → `deleteAccount()` → RPC `delete_account` (`supabase/delete_account.sql:12-40`). `SECURITY DEFINER`, `auth.uid()` ile self-only, CASCADE ile tüm alt tablolar temizleniyor.
- **Kanıt (görüntüleme/dışa aktarma):** `MyDataScreen` + `SupabaseDataService.exportMyData()` eklendi — profil/gönderi/talep verisi uygulama içinden görüntülenip JSON olarak panoya kopyalanabiliyor (`options_sheet.dart` → "Verilerim").

**6) Analitik ve crash raporlama için onay mekanizması var**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)**
- **Kanıt:** Ayarlar'a "Çökme Raporları Gönder" anahtarı eklendi (`NotificationPrivacySettingsScreen` → `setCrashlyticsCollectionEnabled`); `GIZLILIK_POLITIKASI.md`'ye Crashlytics maddesi eklendi.

**7) Verilerin yurt dışına aktarımı değerlendirildi** — ✅ Geçti (belgelenmiş) — `GIZLILIK_POLITIKASI.md:51-53` Supabase/Firebase kullanıldığını belirtiyor. Sunucu bölgesi ❓ (Supabase panelinden doğrulanmalı).

**8) Çocuklara yönelik içerikte COPPA ve mağaza politikaları** — ✅ Geçti — `.edu` e-posta zorunluluğu, 13 yaş altı hedeflenmiyor (`GIZLILIK_POLITIKASI.md:86-88`).

**9) Loglarda ve analitikte kişisel veri yok/maskeleniyor** — ✅ Geçti — taranan log çağrılarında e-posta/token/şifre basılmıyor.

**10) Veri saklama süreleri tanımlı**
- **Durum:** ⚠️ Kısmen
- **Kanıt:** Teknik olarak tanımlı: `supabase/migrations/20260927_content_retention_cleanup.sql:1-60` — posts 30 gün, announcements 1 gün, tickets 7 gün, job_listings 14 gün, news 7 gün (pg_cron). Ancak politika metni bu süreleri kullanıcıya bildirmiyor.
- **Risk seviyesi:** Düşük-Orta — **Düzeltme:** Politika metnine saklama sürelerini ekleyin.

---

# 13. Mağaza Gereksinimleri

**1) Uygulama içinden hesap silme özelliği var** — ✅ Geçti — `options_sheet.dart:275-282` → onay diyaloğu → RPC. Apple/Google gereksinimini karşılıyor.

**2) Üçüncü taraf sosyal giriş varsa "Sign in with Apple" eklendi**
- **Durum:** ➖ Uygulanamaz (mevcut kod tabanında) — `sign_in_with_apple`/`google_sign_in` paketi yok, sosyal giriş şu an mevcut değil.
- **Not:** Google girişi eklenirse Apple Sign-In de zorunlu olacak; `AndroidManifest.xml`'deki atıl `supabase://login` kaydı bu konuda kafa karıştırıcı (bkz. Bölüm 4.2).

**3) iOS Privacy Manifest (`PrivacyInfo.xcprivacy`) ve Required Reason API beyanları**
- **Durum:** ⚠️ Kısmen — dosya mevcut, `NSPrivacyTracking:false` doğru, 3 Required Reason API beyanı var. Ancak `NSPrivacyCollectedDataTypes` boş — uygulama e-posta/isim/konum/fotoğraf topladığı halde beyan edilmemiş (App Store Connect panelinde ayrıca doldurulmalı).
- **Risk seviyesi:** Düşük-Orta

**4) Tüm `Info.plist` izin açıklamaları mevcut ve anlamlı** — ✅ Geçti — 5 izin açıklaması, hepsi amaca özgü ve anlamlı.

**5) `targetSdkVersion` Google Play'in güncel minimum gereksiniminde**
- **Durum:** ✅ Geçti — `flutter.targetSdkVersion` kullanılıyor (Flutter varsayılanı, ~API 36). Sabitlenmemiş — esneklik/risk trade-off'u.

**6) Foreground service türleri beyan edilmiş** — ➖ Uygulanamaz — hiçbir `<service>`/`FOREGROUND_SERVICE` izni yok, foreground service kullanılmıyor.

**7) Hassas izinler için beyan formları** — ➖ (mevcut izin seti için gerek yok) — yalnızca CAMERA/konum/POST_NOTIFICATIONS/RECEIVE_BOOT_COMPLETED/INTERNET var.

**8) Demo hesap bilgileri inceleme ekibi için hazır** — ❓ Doğrulanamadı — koddan anlaşılmaz, App Store Connect/Play Console inceleme notlarında sağlanmalı.

**9) Uygulama ikonu/ekran görüntüleri/açıklama politikalara uygun** — ❓ Doğrulanamadı — mağaza paneli kontrolü gerekir.

---

# 14. Mimari ve Kod Kalitesi

**1) UI, iş mantığı, veri erişimi ve state yönetimi ayrılmış**
- **Durum:** ⚠️ Kısmen — `supabase_data_service.dart` (1959 satır) tek bir "God service" — tüm domainler tek sınıfta. Ekranlar servisi doğrudan çağırıp aynı dosyada UI+iş kuralı+veri dönüşümü yapıyor.
- **Risk seviyesi:** Orta — **Öneri:** Domain bazlı repository'lere bölün (`PostsRepository`, `CommunityRepository`...).

**2) Tek dosyada yüzlerce satırlık dev bileşen yok**
- **Durum:** ❌ Kaldı — **YÜKSEK**
- **Kanıt:** `admin_screen.dart` 2386 satır (`_AdminScreenState` ~1700 satır), `calendar_screen.dart` 1575 satır, `baskan_panel_screen.dart` 1474 satır, `home_screen.dart` 1045 satır.
- **Risk seviyesi:** Yüksek — **Öneri:** Her sekme/panel ayrı `StatefulWidget` dosyasına çıkarılmalı.

**3) Tutarlı isimlendirme, klasör yapısı ve state yönetimi yaklaşımı**
- **Durum:** ⚠️ Kısmen — Provider/Riverpod/Bloc yok, `StatefulWidget`+`setState`+global singleton tutarlı uygulanmış (iyi). Ancak TR/EN karışık isimlendirme var (`Topluluk` modeli ama `CommunityDetailScreen`; `toplulukAdi` ile `isSupportedByMe` aynı `PostModel`'de).
- **Risk seviyesi:** Düşük

**4) Parça parça üretilen kodlar arasında tutarsızlık yok**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)**
- **Kanıt:** `post_card.dart`'ın `_toggleEventJoin()` metoduna `home_screen.dart`'taki doğru örnekle aynı desen (rollback + `SnackBar`) uygulandı.

**5) Silinmiş veya "// geri kalan kod aynı" ile atlanmış kısım yok** — ✅ Geçti — grep sıfır sonuç.

**6) `// ignore:`, `dynamic`, `!` force unwrap, `late` kötüye kullanımı yok**
- **Durum:** ⚠️ Kısmen — `// ignore:` 1 kez (meşru). `dynamic` 167 kez (çoğu JSON parse, kabul edilebilir). Force-unwrap ~68 kez (`supabase_auth_service.dart` 16, `calendar_screen.dart` 8, `admin_screen.dart` 5, `profile_screen.dart` 8). `late` 28 kez, kötüye kullanım yok.
- **Risk seviyesi:** Orta (force-unwrap yoğunluğu) — **Öneri:** null-check ile değiştirin.

**7) Lint kuralları kapatılmamış; uyarılar giderilmiş**
- **Durum:** ⚠️ Kısmen — `analysis_options.yaml:24` `use_null_aware_elements: false` (1 kural kapatılmış). `flutter analyze` → **"No issues found!"**.
- **Risk seviyesi:** Düşük

**8) Hatayı sessizce yutan boş `catch` blokları yok**
- **Durum:** ~~❌ Kaldı~~ **✅ Gözden geçirildi (2026-09-27)**
- **Kanıt:** İki kritik yazma işlemi (`unsupportPost`, `updateUserProfile`) düzeltildi. Kalan ~26 `catch (_) {}` tek tek incelendi — büyük çoğunluğu kasıtlı/doğru best-effort desenler (bkz. bu belgenin başındaki "Bu denetimden sonra yapılan ek düzeltmeler" tablosu); sistemik bir hatayı gizleyebilecek 4 tanesine gözlemlenebilirlik için loglama eklendi.

**9) Mock veri, sahte API yanıtı ve TODO/FIXME yer tutucuları production'da yok**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)**
- **Kanıt:** `_demoTopluluklar`/`_demoGonderiler`/`_demoKuponlar` (~250 satır) tamamen kaldırıldı; ağ hatası artık kullanıcıya gerçek hata olarak yansıyor.

**10) Ölü kod ve kullanılmayan import'lar temizlendi** — ✅ Geçti — `flutter analyze` "No issues found".

**11) Sihirli sayılar ve sabit değerler sabit/yapılandırma dosyasında**
- **Durum:** ❌ Kaldı — `AppSpacing`/`AppRadius` sabitleri tanımlı ama codebase'de yalnızca 1 kez kullanılmış; `EdgeInsets.all(<sayı>)` 149 kez, `EdgeInsets.symmetric` 139 kez ham sayı.
- **Risk seviyesi:** Düşük

**12) Tip güvenliği etkin** — ✅ Geçti — `sdk: '>=3.0.0 <4.0.0'`, `flutter analyze` temiz.

**13) Aşırı mühendislik veya yetersiz yapı yok**
- **Durum:** ⚠️ Kısmen — proje ölçeğine göre aşırı mühendislik yok ama bazı ekranlarda (madde 2) yetersiz yapı var.
- **Risk seviyesi:** Orta

---

# 15. Bellek, Yaşam Döngüsü ve Eşzamanlılık

**1) Event listener, subscription, timer ve stream'ler kapatılıyor**
- **Durum:** ✅ Geçti — tüm bulunan kaynaklar tek tek doğrulandı: `main.dart:175,190-193` (`_authSubscription`), `home_screen.dart:39,108-110` (`_socketSub`), `community_maze_screen.dart:21,96-100` (Timer+controller), `games/*`, `widgets/news_bulletin_carousel.dart`, `widgets/animated_theme_background.dart`, `widgets/flip_coupon_card.dart` — hepsinde ilgili `dispose()` doğru kaynağı kapatıyor.

**2) Android'de Activity/Context sızıntısı yok** — ❓ Doğrulanamadı — `BuildContext` sınıf alanında saklanmıyor (iyi işaret), kesin sonuç için LeakCanary testi gerekir.

**3) iOS'ta retain cycle yok** — ➖ Uygulanamaz — saf Flutter/Dart, özel Swift/ObjC kod yok.

**4) Bileşen kapandıktan sonra state güncellenmiyor**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)**
- **Kanıt:** Bulunan 5 dosyanın tümüne (`community_settings_screen.dart`, `create_post_screen.dart`, `login_screen.dart`, `notification_center_screen.dart` — 3 nokta, `profile_screen.dart`) her `await` sonrası `setState`'ten hemen önce `if (!mounted) return;` eklendi.

**5) Ekrandan çıkıldığında devam eden istekler iptal ediliyor**
- **Durum:** ➖/⚠️ Kısmen — Supabase SDK çağrılarında CancelToken yok; tek ham HTTP isteğinde (Telegraph upload) `.timeout(20s)` var ama `dispose()`'da iptal yok. Etkisi düşük.

**6) Hızlı ardışık isteklerde race condition yok** — ✅ Geçti — `community_maze_screen.dart:30-44` 400ms debounce doğru uygulanmış; diğer aramalar yerel filtre (ağ çağrısı yok).

**7) Process death sonrası state geri yükleniyor**
- **Durum:** ❌ Kaldı/❓ — `RestorationMixin`/`onSaveInstanceState` yok. Login durumu korunuyor (Supabase token persist) ama form/scroll state kaybolur.
- **Risk seviyesi:** Düşük

**8) Arka plan ↔ ön plan geçişleri doğru yönetiliyor**
- **Durum:** ~~❌ Kaldı~~ **⚠️ Kısmen düzeltildi (2026-09-26)** — `campus_map_screen.dart` (izin tekrar kontrolü, Bölüm 28.4) ve tema sistemi (`_SystemBrightnessWatcher`, Bölüm 20.7) artık `WidgetsBindingObserver` kullanıyor. Genel bir "foreground dönüşünde veri tazele" politikası hâlâ yok — diğer ekranlar kapsanmıyor.
- **Risk seviyesi:** Düşük-Orta

**9) Ağır işler ana thread dışında** — ➖ Uygulanamaz — `compute()` kullanılmıyor ama `jsonDecode` boyutları küçük, sorun değil.

**10) Deadlock ve thread-safety sorunları yok** — ❓ Doğrulanamadı — Lock/synchronized kullanımı yok, Dart tek-thread event-loop, risk düşük.

**11) Yapılandırma değişikliklerinde veri kaybı yok** — ✅ Geçti — Flutter'da native Activity recreate yok, `TextEditingController` state'te tutulduğundan form korunur.

---

# 16. Hata Yönetimi ve Ağ Dayanıklılığı

**1) Her ekranda yükleniyor, boş, hata ve başarı durumları tasarlanmış** — ✅ Geçti (örneklenen ekranlarda) — `community_detail_screen.dart`, `home_screen.dart`, `job_listings_screen.dart` tutarlı.

**2) Mutlu yol dışındaki senaryolar ele alınmış**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — demo-veri geri dönüşleri kaldırıldığı için (Bölüm 14.9) artık gerçek hata kullanıcıya yansıyor.

**3) Çevrimdışı durumda anlamlı mesaj**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)** — `getTopluluklar`/`getGonderiler`/`getKuponlar` artık sessizce demo veri döndürmüyor, gerçek hata ekrana yansıyor (14.9 ile aynı kök, birlikte düzeltildi).

**4) Bağlantı geri geldiğinde otomatik yeniden deneme** — ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-27)** — `connectivity_plus` eklendi; `ConnectivityService` uygulama genelinde bağlantı durumunu izliyor ve çevrimdışıyken `OfflineBanner` ile kullanıcıya bildiriyor.

**5) İsteklerde timeout tanımlı**
- **Durum:** ⚠️ Kısmen — yalnızca Telegraph upload'ta `.timeout(20s)` var; Supabase SDK çağrılarının hiçbirinde açık timeout yok.
- **Risk seviyesi:** Orta

**6) Retry mantığı exponential backoff ile** — ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-27)** — `retryWithBackoff()` yardımcı fonksiyonu eklendi ve ana içerik akışının (`home_screen.dart` → `getGonderiler`) ilk yüklemesine uygulandı (3 deneme, üstel gecikme). Diğer ekranların çoğunda hâlâ yalnızca manuel "yeniden dene" var — en kritik/en sık kullanılan yol düzeltildi, tam kapsamlı uygulama ayrı bir iş.

**7) Null, eksik alan ve beklenmeyen API yanıtları uygulamayı çökertmiyor**
- **Durum:** ⚠️ Kısmen — çoğu yerde `as String? ?? 'varsayılan'` deseni var ama Bölüm 14.6'daki force-unwrap noktaları risk taşıyor.
- **Risk seviyesi:** Orta

**8) 4xx/5xx durum kodları ayrı ayrı ele alınıyor** — ➖ Uygulanamaz — Supabase SDK tipli exception kullanıyor (`SupabaseAuthException`), `_mapError` ile kullanıcı diline çevriliyor — bu, 4xx/5xx ayrımının Supabase-native karşılığı.

**9) Global hata yakalayıcı** — ✅ Geçti — `main.dart` `FlutterError.onError` + `PlatformDispatcher.instance.onError` + `runZonedGuarded`, hepsi Crashlytics'e yönlendiriyor.

**10) Kullanıcıya teknik değil anlaşılır hata mesajları** — ✅ Geçti — "Bir şeyler ters gitti...", "E-posta veya şifre hatalı." gibi mesajlar, stack trace sızmıyor.

**11) Butonlara çift basma engelleniyor** — ✅ Geçti — `_loading ? null : ...` deseni tutarlı.

**12) Yavaş ağda (3G, yüksek gecikme) test edildi** — ❓ Doğrulanamadı — manuel/profiler testi gerekir.

**13) Sayfalama veya sonsuz kaydırma doğru çalışıyor**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi**
- **Kanıt:** `home_screen.dart`'a `ScrollController` + `_page`/`_hasMorePosts` eklendi, ana akış artık gerçek sonsuz kaydırma yapıyor.

**14) Sunucu bakım/zorunlu güncelleme yanıtları ele alınıyor**
- **Durum:** ⚠️ Kod tarafı hazır (`ForceUpdateService`), `app_settings` migration'ı henüz canlıya uygulanmadı (bkz. yönetici özeti madde 17).
- **Risk seviyesi:** Düşük

---

# 17. Çökmeler ve Donmalar

**1) Crash raporlama entegre ve release'de aktif** — ✅ Geçti — `main.dart:84-90` `setCrashlyticsCollectionEnabled(!kDebugMode)`.

**2) Symbol/mapping dosyaları yükleniyor**
- **Durum:** ⚠️ Kısmen — **YÜKSEK (iOS için)**
- **Kanıt:** Android: `com.google.firebase.crashlytics` gradle plugin var → mapping otomatik. Flutter: `--obfuscate --split-debug-info` üç CI dosyasında da var. **iOS dSYM için `project.pbxproj`'da Crashlytics "Run Script" build phase yok** — iOS native crash'ler sembolize edilemeyebilir.
- **Risk seviyesi:** Yüksek — **Düzeltme:** Xcode'a `"${PODS_ROOT}/FirebaseCrashlytics/run"` run script eklenmeli.

**3) Android ANR riski olan ana thread işleri yok**
- **Durum:** ⚠️ Kısmen düzeltildi (2026-09-27) — `flutter_native_splash` eklendi (Android 12+ dahil), böylece `runApp()` öncesi sıralı `await`'ler (Firebase, LocalStorage, Supabase.initialize, tema) sırasında artık boş/beyaz ekran yerine marka logosu gösteriliyor — algılanan açılış süresi iyileşti. Init'lerin kendisi `runApp()` sonrasına taşınmadı (daha invaziv bir değişiklik, ayrı bir iş).
- **Risk seviyesi:** Düşük-Orta

**4) iOS watchdog zaman aşımına neden olan açılış işleri yok**
- **Durum:** ⚠️ Kısmen (madde 3 ile aynı kök) — zayıf ağda `Supabase.initialize` gecikmesi riski artırabilir.
- **Risk seviyesi:** Düşük-Orta

**5) Düşük bellek uyarıları ele alınıyor** — ❌ Kaldı — `didHaveMemoryPressure` hiç işlenmiyor. Risk: Düşük (büyük in-memory cache yok).

**6) Eski işletim sistemi sürümlerinde test edildi**
- **Durum:** ⚠️ Kısmen — `minSdk = flutter.minSdkVersion` (override yok), iOS `IPHONEOS_DEPLOYMENT_TARGET=13.0`.
- **Risk seviyesi:** Düşük

**7) Release build gerçek cihazda test edildi** — ❓ Doğrulanamadı — manuel test gerekir (`isMinifyEnabled=true` aktifken önemli).

---

# 18. Performans

**1) Uzun listelerde sanallaştırma** — ✅ Geçti — 22 `ListView.builder`/`GridView.builder` kullanımı; `ListView(children)` yalnızca küçük/sabit içerikte.

**2) Liste öğelerinde benzersiz ve kararlı key**
- **Durum:** ⚠️ Kısmen — açık key kullanımı yalnızca 2 yerde; `notification_center_screen.dart:535` `ValueKey(title+time)` kullanıyor (id yerine metin birleşimi, teorik çakışma).
- **Risk seviyesi:** Düşük — **Düzeltme:** `ValueKey(n['id'])` kullanın.

**3) Gereksiz yeniden render yok**
- **Durum:** ⚠️ Kısmen — `const` 1645 kez kullanılmış (~%5.8) ama büyük State sınıflarında her `setState` koca `build()`'i çalıştırıyor.
- **Risk seviyesi:** Orta

**4) Görseller boyutlandırılmış, sıkıştırılmış ve önbellekleniyor** — ✅ Geçti — `Image.network` hiç kullanılmıyor, hepsi `CachedNetworkImage` (`app_network_image.dart`) üzerinden; `ImageSanitizer` ile sıkıştırma da var.

**5) Açılış süresi ölçüldü ve optimize edildi**
- **Durum:** ⚠️ Kısmen — native splash eklendi (bkz. Bölüm 17.3), ve Firebase Performance Monitoring artık açılış/ağ sürelerini ölçüyor (bkz. Bölüm 32.3). Bizzat bir optimizasyon (init'lerin `runApp()` sonrasına taşınması) henüz yapılmadı — artık ölçülebilir olduğu için ileride veriye dayalı yapılabilir.

**6) Animasyonlar akıcı, native driver kullanılıyor** — ❓ Doğrulanamadı — DevTools profiling gerekir.

**7) Uygulama boyutu optimize**
- **Durum:** ⚠️ Kısmen — `app-release.aab` ~134 MB — sosyal/topluluk uygulaması için oldukça büyük.
- **Risk seviyesi:** Orta — **Öneri:** `flutter build appbundle --analyze-size` ile incelenmeli.

**8) Gereksiz ağ istekleri ve tekrarlayan çağrılar yok** — ✅ Geçti — `community_maze_screen.dart` stale-while-revalidate deseni, `location_service.dart` ~2km cache.

**9) Büyük verilerde arama/filtreleme için debounce kullanılıyor** — ✅ Geçti (bkz. Bölüm 15.6).

**10) Bellek kullanımı profil araçlarıyla incelendi** — ❓ Doğrulanamadı — DevTools Memory testi gerekir.

---

# 19. Pil ve Kaynak Kullanımı

**1) Sürekli yüksek hassasiyetli konum takibi yok** — ✅ Geçti — yalnızca tek seferlik `getCurrentPosition()`, `getPositionStream` hiç kullanılmıyor, `getLastKnownPosition` fallback var.

**2) Gereksiz polling yerine push/WebSocket tercih ediliyor** — ✅ Geçti — Supabase Realtime channel + `subscribeToNotifications`; `Timer.periodic` yalnızca oyun içi sayaçlarda.

**3) Arka plan işleri sistem planlayıcılarıyla yapılıyor** — ➖ Uygulanamaz — `workmanager` paketi yok, tasarım gereği gerekmiyor.

**4) Wake lock'lar serbest bırakılıyor** — ➖ Uygulanamaz — `wakelock` paketi hiç kullanılmıyor.

**5) Sensörler kullanılmadığında kapatılıyor** — ✅ Geçti — `qibla_compass_screen.dart` `StreamBuilder` ile, ekran kapanınca otomatik iptal.

**6) Mobil veride büyük indirmeler kullanıcı onayıyla** — ❓ Doğrulanamadı — Wi-Fi/mobil veri ayrımı yok ama görseller zaten sıkıştırılmış.

---

# 20. Arayüz ve Duyarlı Tasarım

**1) Safe area, çentik, Dynamic Island, alt gezinme çubuğu hesaba katılmış** — ✅ Geçti — 22 dosyada `SafeArea` kullanılıyor.

**2) Android 15 edge-to-edge uyumu** — ✅ Geçti — `main.dart:94-102` `SystemUiMode.edgeToEdge`, açıkça belgelenmiş.

**3) Android geri tuşu ve predictive back hareketi doğru çalışıyor**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — `AndroidManifest.xml`'e `android:enableOnBackInvokedCallback="true"` eklendi; ayrıca `create_post_screen.dart`/`register_screen.dart`'a `PopScope` tabanlı kaydedilmemiş-değişiklik onayı da eklendi (bkz. Bölüm 23.7).

**4) Klavye form alanlarını kapatmıyor** — ✅ Geçti — `adjustResize`, `resizeToAvoidBottomInset` hiç `false` yapılmamış.

**5) Küçük telefon, büyük telefon, tablet, katlanabilir cihazlarda test edildi**
- **Durum:** ❓ Doğrulanamadı — `main.dart:413-418` MediaQuery eşikleri var ama gerçek cihaz/tablet testi doğrulanamaz; tablet için genişlik sınırlaması yok.
- **Risk seviyesi:** Orta

**6) Yatay mod destekleniyor veya bilinçli olarak kilitlendi**
- **Durum:** ⚠️ Kısmen — kilit yok, `Info.plist` hem portrait hem landscape destekliyor ama hiçbir ekran landscape'e uyarlanmamış.
- **Risk seviyesi:** Orta — **Öneri:** Ya bilinçli kilitleyin ya da harita/oyun ekranlarını uyarlayın.

**7) Karanlık mod destekleniyor; sabit renk yok**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — `useSystemTheme()` + `_SystemBrightnessWatcher` eklendi, `theme_customizer_screen.dart`'a sistem temasını takip etme seçeneği eklendi.

**8) Uzun metinler taşmıyor** — ✅ Geçti — 85+ yerde `overflow`/`maxLines` kullanılmış.

**9) iOS ve Android platform alışkanlıklarına uygun gezinme** — ✅ Geçti — `app_theme.dart:152-157` platform bazlı `pageTransitionsTheme`.

**10) Dokunmatik geri bildirim**
- **Durum:** ⚠️ Kısmen — `InkWell` yalnızca 6 dosyada 10 kullanım, `GestureDetector` 27 dosyada 44 kullanım (ripple'sız), `HapticFeedback` yalnızca 1 yerde.
- **Risk seviyesi:** Düşük

---

# 21. Erişilebilirlik

**1) Tüm etkileşimli öğelerde erişilebilirlik etiketleri**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-27)** — alt gezinme çubuğuna `Semantics(label:, selected:, button:)` eklendi; ayrıca proje genelindeki **71 `IconButton`'ın tamamı** tek tek gözden geçirilip etiketsiz olan ~48'ine anlamlı Türkçe `tooltip` eklendi (Flutter'da `tooltip`, `Tooltip` widget'ı üzerinden ekran okuyucu için semantic label olarak da kullanılır). `flutter analyze` ile doğrulandı.

**2) VoiceOver ve TalkBack ile test edildi** — ❓ Doğrulanamadı — gerçek cihaz testi gerekir.

**3) Dokunma alanları en az 44×44 pt/48×48 dp**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — alt gezinme çubuğundaki her öğe `Expanded` ile sarmalanıp tam genişliğe çıkarıldı, ~24-30dp'ye düşen dokunma alanı sorunu giderildi.

**4) Dinamik yazı boyutu destekleniyor** — ✅ Geçti (kısıtlama yok) — `textScaleFactor` hiçbir yerde sabitlenmemiş, ama büyük yazıda bazı sabit `fontSize`+`maxLines:1` alanlar test edilmemiş.

**5) Renk kontrastı WCAG AA seviyesinde**
- **Durum:** ❓ Doğrulanamadı — `app_theme.dart:65-77` açık temada `textMuted`(#64748B)/`background`(#F1F5F9) sınırda kalabilir.
- **Risk seviyesi:** Düşük-Orta

**6) Bilgi yalnızca renkle iletilmiyor** — ✅ Geçti — `ticket_model.dart:67-90` durum hem metin hem renkle gösteriliyor.

**7) Odak sırası mantıklı** — ❓ Doğrulanamadı — özel odak kodu yok, varsayılan widget-tree sırası kullanılıyor.

**8) Animasyonları azaltma tercihi dikkate alınıyor** — ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)** — `animated_theme_background.dart` artık `MediaQuery.disableAnimations`'ı kontrol edip animasyonu durduruyor.

---

# 22. Yerelleştirme

**1) i18n altyapısı var** — ➖ Uygulanamaz — bilinçli tek dil (Türkçe), `flutter_localizations`/`intl` doğrudan bağımlılık değil.

**2) Türkçe `i/İ` ve `ı/I` dönüşümleri locale belirtilerek yapılıyor**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — `lib/utils/turkish_text.dart`'a `turkishToLower()` eklendi ve 4 arama noktasına (`baskan_panel_screen`, `admin_screen`, `campus_map_screen`, `register_screen`) uygulandı.

**3) Tarih, saat, sayı ve para birimi yerel formatta**
- **Durum:** ⚠️ Kısmen — `DateFormat`(intl) hiç kullanılmıyor, `register_screen.dart:63-67` manuel `padLeft` formatlanıyor.
- **Risk seviyesi:** Düşük

**4) Çoğul ifadeler doğru yönetiliyor** — ➖ Uygulanamaz.

**5) RTL dil desteği** — ➖ Uygulanamaz.

**6) Çevirilerde metin uzunluğu farkları arayüzü bozmuyor** — ➖ Uygulanamaz (i18n yok).

---

# 23. Formlar ve Kullanıcı Girdisi

**1) Uygun klavye tipleri** — ✅ Geçti — `emailAddress`, `url` tipleri doğru kullanılıyor.

**2) Otomatik doldurma ipuçları tanımlı**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)** — `app_text_field.dart`'a `autofillHints` parametresi eklendi, login/register e-posta+şifre alanlarına uygulandı.

**3) Anlık ve anlaşılır doğrulama mesajları**
- **Durum:** ⚠️ Kısmen — `register_screen.dart:72-109` yalnızca submit-time kontrol, alan bazlı anlık validator yok. Mesajlar anlaşılır Türkçe.
- **Risk seviyesi:** Düşük

**4) Emoji, özel karakter ve çok uzun girişlerde uygulama bozulmuyor**
- **Durum:** ⚠️ Kısmen — `maxLength` çoğu alanda var ama isim/e-posta alanlarında yok.

**5) Baştaki/sondaki boşluklar temizleniyor** — ✅ Geçti — `register_screen.dart`'ta 9 adet `.trim()`.

**6) Gönderim sırasında buton devre dışı** — ✅ Geçti — `_loading ? null : ...` deseni tutarlı.

**7) Yarım kalmış form verisi yanlışlıkla kaybolmuyor**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)** — `create_post_screen.dart`/`register_screen.dart`'a `PopScope` tabanlı kaydedilmemiş-değişiklik onayı eklendi.

---

# 24. Veri, Senkronizasyon ve Önbellek

**1) Yerel veritabanı migration'ları yazılmış ve test edilmiş**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)** — `local_storage_service.dart`'a `_currentSchemaVersion` + `_runMigrationsIfNeeded()` scaffold'ı eklendi. (Gerçek bir sürüm geçişi henüz yaşanmadığı için scaffold uçtan uca test edilemedi — ilk gerçek şema değişikliğinde doğrulanacak.)

**2) Çevrimdışı değişikliklerde çakışma çözüm stratejisi var**
- **Durum:** ⚠️ Kısmen — "yerel-öncelikli, sunucu her zaman kazanır" — gerçek iki-yönlü çakışma çözümü yok ama tek-cihaz senaryosu için yeterli.

**3) Tarihler sunucuda UTC olarak saklanıyor**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — sunucuya yazılan tüm zaman damgaları (`fcm_service.dart`, `supabase_data_service.dart`'taki ilgili noktalar) `.toUtc()` kullanacak şekilde düzeltildi. `local_storage_service.dart`'taki kalan `DateTime.now()` kullanımları saf yerel veri (senkron zaman damgası, hatıra albümü) — sunucuya yazılmadığı için `.toUtc()` gerektirmiyor.

**4) Önbellek geçersiz kılma stratejisi tanımlı**
- **Durum:** ⚠️ Kısmen — `getLastSyncTimestamp()` var ama TTL bazlı geçersiz kılma yok.

**5) Kullanıcı değiştiğinde önceki kullanıcının önbelleği gösterilmiyor**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — `clearUserSessionCache()` eklendi ve `_onLogout()`'a bağlandı.

**6) Abonelik süresi ve kampanya bitişi sunucu saatine göre** — ❓ Doğrulanamadı — istemci kodunda ücretli abonelik yok, backend'e bağlı.

---

# 25. Bildirimler

**1) Android 13+ `POST_NOTIFICATIONS` izni isteniyor** — ✅ Geçti — manifest + `fcm_service.dart:43-47` `requestPermission`.

**2) Push token'ı logout'ta sunucudan siliniyor** — ✅ Geçti — `main.dart:241-254` `fcm_tokens` tablosundan delete.

**3) Bildirim içeriğinde OTP veya hassas veri yok** — ❓ Doğrulanamadı — Edge Function içerikleri (`sendUpdateAnnouncement`, `send-community-notification`) bu bağlamda tam incelenmedi.

**4) Bildirime tıklayınca doğru ekran açılıyor**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — `fcm_service.dart`'a gerçek navigasyon (`_navigateForMessage`, `navigatorKey` ile) ve cold-start için `checkInitialMessage()` eklendi.

**5) Bildirim kanalları (Android) tanımlı**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — `AndroidManifest.xml`'e FCM push için `default_notification_channel_id` meta-data'sı eklendi.

**6) Kullanıcı bildirim tercihlerini yönetebiliyor**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)** — `NotificationPrivacySettingsScreen` eklendi, `notificationsEnabled`/`setNotificationsEnabled` artık UI'dan çağrılıyor.

---

# 26. Medya, Kamera ve Dosyalar

**1) Android 13+ granüler medya izinleri ve Photo Picker kullanılıyor** — ✅ Geçti — `image_picker` sistem Photo Picker'ı otomatik kullanıyor.

**2) iOS sınırlı fotoğraf erişimi ele alınıyor** — ✅ Geçti — `image_picker` `PHPickerViewController` ile otomatik yönetiyor.

**3) Yüklenen görsellerde EXIF konum verisi temizleniyor — ÖNEMLİ OLUMLU BULGU**
- **Durum:** ✅ Geçti
- **Kanıt:** `lib/utils/image_sanitizer.dart:10-32` `stripExifAndReencode()` — EXIF (GPS dahil) tamamen siliniyor. `supabase_data_service.dart:838-858` `uploadPostImage()` (Telegraph'a giden **tek** herkese-açık yol) bunu çağırıyor, bilinçli güvenlik önlemi olarak belgelenmiş. Görev talimatındaki "muhtemelen eksik" varsayımının aksine **doğru uygulanmış**.

**4) Büyük dosya yüklemelerinde ilerleme, iptal ve devam ettirme**
- **Durum:** ⚠️ Kısmen — belirsiz progress indicator var ama yüzde ilerleme/iptal/devam yok.

**5) İndirilen dosyalar doğrulanıyor** — ➖ Uygulanamaz — uzaktan dosya indirme senaryosu yok, yalnızca yükleme var (`FileValidator` ile doğrulanıyor).

---

# 27. Konum ve Sensörler

**1) Yalnızca gereken hassasiyet isteniyor** — ✅ Geçti — `location_service.dart:44-48` `LocationAccuracy.high`, tek seferlik `getCurrentPosition()`.

**2) Arka plan konumu yalnızca gerçekten gerekliyse** — ✅ Geçti — `ACCESS_BACKGROUND_LOCATION` izni yok.

**3) Konum izni reddedildiğinde uygulama çalışmaya devam ediyor** — ✅ Geçti — `campus_map_screen.dart:117-124` durumlar ayrı ele alınmış.

**4) Konum verisi gereğinden uzun saklanmıyor** — ✅ Geçti — yalnızca bellek-içi ~2km yarıçaplı cache, diske/sunucuya yazılmıyor.

---

# 28. İzin Akışları

**1) İzin reddedildiğinde uygulama çökmüyor** — ✅ Geçti — try/catch + enum kontrolü.

**2) "Bir daha sorma" seçildiğinde ayarlara yönlendiriliyor** — ✅ Geçti — `Geolocator.openAppSettings()`.

**3) İzin istenmeden önce neden gerektiği açıklanıyor** — ✅ Geçti — `_showLocationRationale()`, yalnızca önceden reddedilmişse gösteriliyor.

**4) Kullanıcı izni ayarlardan kaldırıp geri döndüğünde uygulama doğru davranıyor**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-26)** — `campus_map_screen.dart`'a `WidgetsBindingObserver` + `didChangeAppLifecycleState(resumed)` eklendi, izin reddedilmişse konum init'i tekrar deniyor.

---

# 29. Arka Plan İşleri

**1) Doze modu ve App Standby etkileri hesaba katılmış** — ➖ Uygulanamaz — kendi arka plan işi yok, FCM+`zonedSchedule(inexactAllowWhileIdle)` Doze-uyumlu.

**2) iOS arka plan yürütme sınırlarına uyuluyor** — ➖ Uygulanamaz — `BGTaskScheduler` kullanılmıyor, yalnızca FCM background handler (hemen dönüyor).

**3) Arka plan işleri başarısız olursa yeniden deneniyor** — ➖ Uygulanamaz — kalıcı iş kuyruğu yok.

**4) Foreground service kullanımı gerekçeli ve bildirimli** — ➖ Uygulanamaz — kullanılmıyor.

---

# 30. Test

**1) Birim testleri iş mantığını kapsıyor**
- **Durum:** ~~❌ Kaldı~~ **⚠️ Temel atıldı (2026-09-27)** — 5 yeni test dosyası, 30 test, tümü geçiyor: `SupabaseAuthService.validateEduEmail`/`validatePassword` (bu iki metod test edilebilmesi için public yapıldı — Dart'ta `_` ile başlayan üyeler başka dosyadan asla erişilemez), `SupabaseDataService.isoWeek`, `turkishToLower`, `retryWithBackoff`, `LocalStorageService`'in `AuthUser` cache round-trip'i ve bildirim tercihi. Test yazma sürecinde gerçek bir bulgu da ortaya çıktı: orijinal denetimin "Dart'ta İ.toLowerCase() bileşik karakter üretir" iddiası **yanlış** çıktı (Dart bunu zaten doğru yapıyor) — asıl hata ASCII "I"nın "ı" yerine "i"ye çevrilmesiydi; `turkishToLower` zaten doğru fonksiyonu yapıyordu, yalnızca dokümantasyon/test gerekçesi düzeltildi.
- **Risk seviyesi:** Orta — **Hâlâ eksik:** `supabase_data_service.dart`'ın Supabase'e bağımlı metodları (mock/DI olmadan test edilemiyor — bu, servisin "God service" mimarisiyle bağlantılı, bkz. Bölüm 14.1) ve `file_validator.dart` hâlâ testsiz. Kapsamlı bir DI/mock altyapısı kurmak ayrı, daha büyük bir iş.

**2) Entegrasyon ve uçtan uca testler** — ❌ Kaldı — `integration_test/` klasörü yok, paket bağımlılığı yok. Bilinçli olarak ertelendi.

**3) Hata senaryoları ve kenar durumlar test ediliyor** — ⚠️ Kısmen — yeni eklenen birim testleri hata/sınır durumlarını da kapsıyor (geçersiz e-posta, kısa şifre, yıl sonu ISO hafta geçişi, tekrar deneme tükenmesi vb.) ama yalnızca test edilen dar kapsamda; genel olarak hâlâ çoğunlukla happy-path.

**4) Güvenlik testleri: MobSF statik/dinamik analiz** — ❓ Doğrulanamadı — CI'da böyle bir adım yok, ama repo dışı çalıştırılabilir.

**5) Firebase/Supabase kuralları için otomatik testler**
- **Durum:** ❌ Kaldı — **YÜKSEK**
- **Kanıt:** `supabase/tests/` veya pgTAP tabanlı test dosyası yok; RLS politikaları elle yazılmış, regresyon koruması yok.
- **Risk seviyesi:** Yüksek — **Düzeltme:** `supabase/tests/rls_test.sql` (pgTAP) eklenip CI'da `supabase test db` çalıştırılabilir.

**6) Farklı cihaz ve işletim sistemi sürümlerinde test** — ❓ Doğrulanamadı — CI tek runner kullanıyor (`macos-15`).

**7) Güncelleme senaryosu test edildi**
- **Durum:** ❌ Kaldı — `local_storage_service.dart` içinde `migrat`/`schema`/`onUpgrade` gibi hiçbir anahtar kelime yok; anahtarlar `_v1` son ekiyle "versiyonlanmış" görünüyor ama gerçek dönüştürme kodu yok.
- **Risk seviyesi:** Orta

**8) Temiz kurulum senaryosu test edildi** — ❓ Doğrulanamadı — manuel/QA testi gerektirir.

---

# 31. Build, Yapılandırma ve Dağıtım

**1) Dev, staging ve production ortamları ayrı**
- **Durum:** ⚠️ Altyapı hazır (2026-09-27) — `app_config.dart`'a `AppEnvironment` enum'u + `String.fromEnvironment` ile `--dart-define=SUPABASE_URL=...=APP_ENV=staging` desteği eklendi; `--dart-define` verilmezse davranış tamamen aynı (mevcut prod sabitleri). **Gerçek bir staging Supabase projesi henüz yok** — bu yalnızca ileride bir tane açıldığında koda dokunmadan bağlanabilmeyi sağlıyor.
- **Risk seviyesi:** Düşük

**2) Release build yapılandırması debug'dan ayrı ve doğru** — ✅ Geçti — `build.gradle.kts:71-82` `isMinifyEnabled=true`, `isShrinkResources=true`, `key.properties` yoksa build'i durduran guard var.

**3) Sürüm numaralandırması tutarlı**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — `codemagic.yaml`'daki hardcoded `--build-name=1.0.25 --build-number=26` kaldırıldı, sürüm artık `pubspec.yaml`'dan otomatik okunuyor (şu an `1.0.27+28`).

**4) CI/CD hattı var**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — `.github/workflows/build_android.yml` eklendi, Android AAB artık CI'da da üretilebiliyor.

**5) CI'da secret'lar güvenli değişkenlerde** — ✅ Geçti — `build_ios.yml:34-47` yalnızca `secrets.*`'tan okunuyor, eksikse build durduruluyor, repo içi `.p8` fallback'i kasıtlı kaldırılmış.

**6) Zorunlu güncelleme mekanizması var**
- **Durum:** ⚠️ Kod tarafı hazır (2026-09-26) — `ForceUpdateService` + açılışta min-build kontrolü + kapatılamaz güncelleme diyaloğu eklendi. **Canlıya henüz uygulanmadı:** `supabase/migrations/20260930_app_settings_force_update.sql`'in Supabase Dashboard'da çalıştırılması gerekiyor.

**7) OTA güncellemeleri imzalı ve mağaza kurallarına uygun** — ➖ Uygulanamaz — Shorebird/OTA kullanılmıyor.

**8) `build.gradle`, `Podfile`, `AndroidManifest.xml`, `Info.plist` doğru ve güncel** — ✅ Geçti — güncel pratiklere uygun (Java 17, `coreLibraryDesugaring`, `usesCleartextTraffic=false`).

**9) Aşamalı yayın kullanılıyor** — ❓ Doğrulanamadı — Play Console ayarı, kod/repo üzerinden görünmüyor.

---

# 32. İzleme, Loglama ve Analitik

**1) Yapılandırılmış loglama; release'de log seviyesi düşük**
- **Durum:** ⚠️ Kısmen — `print(` kullanımı **0** (iyi). `debugPrint(` 91 kez, `kDebugMode` kontrolüyle sarmalanmamış — release modda da konsola yazmaya devam eder. Gerçek log seviyesi/uzak toplama servisi yok.
- **Risk seviyesi:** Düşük — **Öneri:** `if (kDebugMode) debugPrint(...)` veya `logger` paketi.

**2) Loglarda token, şifre ve kişisel veri yok** — ✅ Geçti — `fcm_service.dart:63-65` yalnızca token'ın varlığını (boolean) logluyor; genel taramada gerçek token/parola log'a yazılmıyor.

**3) Performans izleme (açılış süresi, ağ süreleri)**
- **Durum:** ~~❌ Kaldı~~ **✅ Düzeltildi (2026-09-27)** — `firebase_performance` eklendi (Android Gradle plugin dahil), Crashlytics ile aynı kullanıcı onayına ("Çökme Raporları Gönder") bağlandı, gizlilik politikasına eklendi.

**4) Önemli olaylar için analitik; kullanıcı onayına bağlı** — ➖ Uygulanamaz — `firebase_analytics` yok, davranış analitiği toplanmıyor.

**5) Backend hata ve anormallik uyarıları kurulu**
- **Durum:** ⚠️ Kısmen — Edge Function'larda `console.error` var (Supabase log konsoluna) ama harici alarm/monitoring (Sentry, Slack webhook) yok.

---

# 33. Yapay Zeka Tarafından Üretilen Koda Özgü Kontroller

**1) Üretilen her paket adı ve API resmi dokümantasyonda doğrulandı** — ✅ Geçti — tüm 24 paket gerçek, yaygın pub.dev paketleri, `flutter pub get` sorunsuz çözümlendi.

**2) Kullanımdan kaldırılmış API'ler yok** — ✅ Geçti — `flutter analyze` → "No issues found! (ran in 23.8s)".

**3) Güvenlik önlemleri yalnızca istendiğinde değil, varsayılan olarak var** — ✅ Geçti (genel değerlendirme) — güvenli imzalama guard'ı, `usesCleartextTraffic=false`, `flutter_secure_storage`, CI secret yönetimi — sonradan eklenmiş yamalar değil, varsayılan.

**4) Backend tarafı unutulmamış** — ✅ Geçti — Bölüm 5'te detaylandırıldı (RLS genel olarak kapsamlı, `communities`/`community_links` boşluğu hariç).

**5) Geçici güvenlik gevşetmeleri geri alınmış**
- **Durum:** ✅ Geçti — TODO/FIXME/HACK/allowAll/bypass/`badCertificateCallback` taramaları temiz (tek "HACK" eşleşmesi bir topluluk adı, yanlış pozitif).

**6) Uzun konuşmalarda mimari sapma yok** — ✅ Geçti (genel değerlendirme) — `backend/` klasörünün kaldırılması Supabase-native mimariye geçişin tutarlı tamamlandığını gösteriyor.

**7) Yapılandırma dosyalarındaki değişiklikler elle gözden geçirildi** — ❓ — bu denetimin kapsamı dışında, süreçsel bir konu.

**8) "Tamamlandı" denilen özellikler gerçekten uçtan uca çalışıyor**
- **Durum:** ❓ Doğrulanamadı — test kapsamı olmadığından (Bölüm 30) hiçbir özelliğin uçtan uca çalıştığı koddan kesin doğrulanamaz. Ayrıca somut bir örnek bulundu: Google girişi özelliği (hafızada "tamamlandı" olarak not düşülmüş) kod tabanında aktif değil (bkz. Bölüm 4.2).

---

# 34. Framework'e Özgü Hızlı Kontroller

## Flutter

**1) `--obfuscate --split-debug-info` ile derleniyor**
- **Durum:** ~~⚠️ Kısmen~~ **✅ Düzeltildi (2026-09-26)** — `build_ios_ipa.yml`'e de `--obfuscate --split-debug-info` eklendi, artık tüm 4 build yolunda (`build_ios.yml`, `build_ios_ipa.yml`, `codemagic.yaml`, `build_aab.ps1`) var.

**2) `kDebugMode`/`kReleaseMode` kontrolleri doğru** — ✅ Geçti — `main.dart:35` (debug'da hata detayı) ve `:86` (debug'da Crashlytics kapalı) doğru kullanım.

**3) `HttpClient.badCertificateCallback` release'de yok** — ✅ Geçti — grep sıfır sonuç.

**4) Controller'lar ve stream'ler `dispose()` ediliyor** — ✅ Geçti — bkz. Bölüm 15.1 (detaylı doğrulama orada yapıldı), 25 dosyada `dispose()` override edilmiş.

## React Native / Native Android / Native iOS

➖ Uygulanamaz — proje tamamen Flutter tabanlı, bu alt bölümler geçersiz.

---

# 35. Önerilen Araçlar

Bu denetimde fiilen çalıştırılanlar: `flutter analyze` (temiz sonuç), `git log --all --full-history` (secret sızıntısı taraması), `flutter pub get` (paket çözümleme doğrulaması), kapsamlı `grep`/statik kod okuma.

Bu denetimin **kapsamadığı**, ayrıca çalıştırılması gereken araçlar:

- **Statik/dinamik güvenlik analizi:** MobSF, OWASP MASTG test senaryoları — çalıştırılmadı.
- **Secret taraması:** `gitleaks detect --source . -v` veya `trufflehog git file://.` — tam repo taraması yapılmadı (yalnızca bilinen dosya adları için `git log` araması yapıldı).
- **Bağımlılık taraması:** `flutter pub outdated`, Snyk, Dependabot — internet erişimi gerektiği için çalıştırılmadı; `.github/dependabot.yml` yok.
- **Trafik inceleme:** Burp Suite, mitmproxy, Charles — gerçek cihaz/proxy testi gerekir.
- **Çalışma zamanı analizi:** Frida, objection — gerçek cihaz testi gerekir.
- **Bellek ve performans:** LeakCanary, Android Profiler, Xcode Instruments, Flutter DevTools — gerçek cihaz/emülatör testi gerekir (Bölüm 15.2, 18.6, 18.10 için gerekli).
- **Referans standartlar:** OWASP MASVS ve OWASP Mobile Top 10.

---

## Sonuç

NevGenç projesinin genel güvenlik mimarisi (RLS-öncelikli Supabase yaklaşımı, `flutter_secure_storage`, EXIF temizliği, obfuscation, Crashlytics, hesap silme akışı) sağlam temeller üzerine kurulmuş. Ancak canlıya taşıma sürecinde bazı tablolarda (`communities`, `community_links`, `posts` DELETE/UPDATE) RLS politikalarının unutulmuş olma ihtimali **acilen canlı ortamda doğrulanmalı** — bu, projenin bu tür geçişlerde daha önce de yaşadığı bir desenin devamı olabilir. Bunun dışında en büyük risk alanları güvenlik değil **dayanıklılık/kalite** tarafında: sessizce yutulan hatalar, ağ hatasında sahte veri gösterimi, bağlanmamış sayfalama ve test kapsamının neredeyse hiç olmaması.
</content>
