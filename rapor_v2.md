# NevGenç — Derinlemesine Denetim Raporu v2 (Kalan Eksikler & Zafiyetler)

**Tarih:** 2026-06-06
**Kapsam:** Bir önceki turda (`rapor.md`) kapatılan maddelerin DIŞINDA, kodun **daha önce derinlemesine incelenmemiş** bölümleri: takvim, bildirimler, options_sheet, tema özelleştirici, `backend/`, Android yapılandırması, testler ve bağımlılıklar.

> Not: `rapor.md`'deki tüm maddeler çözüldü. Bu rapor **yeni/farklı** bulguları içerir. Her madde dosya + satır hedefiyle doğrulanmıştır.

---

## 🔴 ÖNCELİK SIRALAMASI (özet)

| # | Bulgu | Önem | Efor |
|---|---|---|---|
| E1 | `widget_test.dart` kırık — `flutter test` patlıyor, sıfır test kapsamı | 🔴 Kritik | Düşük |
| B1 | FCM `google-services.json` yok → Android push tamamen devre dışı | 🔴 Kritik | Düşük |
| B2 | Bildirimler in-memory + yerel → restart'ta kaybolur, background push listeye düşmez | 🟠 Yüksek | Orta |
| B3 | Takvim notları yalnızca cihazda (SharedPreferences) — sunucu tablosu boşta | 🟠 Yüksek | Orta |
| A1 | `backend/` (~1980 satır Node.js) tamamen ölü | 🟠 Yüksek | Düşük |
| A2 | Kullanılmayan bağımlılıklar: `flutter_secure_storage`, `lottie` | 🟠 Yüksek | Düşük |
| A3 | SupabaseDataService'te 7 kullanılmayan metod (notifications + calendar) | 🟡 Orta | Düşük |
| C1 | `BackdropFilter` hâlâ 5 dosyada (calendar 2×, podium 3×, detail, sheet) | 🟡 Orta | Orta |
| D1 | AndroidManifest: explicit INTERNET / POST_NOTIFICATIONS izni yok | 🟡 Orta | Düşük |
| E2 | `options_sheet._showComingSoon`: pop sonrası context ile SnackBar | 🟡 Orta | Düşük |
| B4 | 3 "Coming Soon" placeholder özellik production UI'da | 🟢 Düşük | — |
| E3 | Takvim notuna uzunluk limiti yok | 🟢 Düşük | Düşük |

---

## 1. TEST & QA

### E1. 🔴 KRİTİK: Tek Test Kırık — `flutter test` Çöküyor
**Dosya:** `test/widget_test.dart`

**Sorun:** Test, `NevGencApp`'i `Supabase.initialize(...)` çağrılmadan pump ediyor. `main.dart:20`'deki `final supabase = Supabase.instance.client;` ve `AuthGate.initState`'teki `supabase.auth.onAuthStateChange` satırları, başlatılmamış `Supabase.instance`'a erişince **exception fırlatır**.
```dart
await tester.pumpWidget(const NevGencApp()); // → Supabase.instance henüz init değil → patlar
```
**Risk:** `flutter test` her zaman başarısız → CI kuramazsınız, gerçek test kapsamı **sıfır**. Bu, ilerideki regresyonların hiçbirini yakalamaz.

**Çözüm:** Smoke test'i izole edilebilir bir widget'a yöneltin veya Supabase'i mock'layın. En basiti, tema gibi Supabase'siz bir bileşeni test edin:
```dart
testWidgets('Tema notifier varsayılanı forest', (tester) async {
  expect(themeNotifier.value.type, ThemeType.forest);
});

// Gerçek uygulama testi için Supabase'i sahte başlatın (setUpAll içinde):
// SharedPreferences.setMockInitialValues({});
// + Supabase init'i test ortamında mock'layan bir yardımcı.
```
Orta vadede en az: auth doğrulama (`_validateEduEmail`, `_validatePassword`), `_isoWeek`, model `fromApiJson` dönüşümleri için **unit testler** ekleyin — bunlar Supabase gerektirmez.

---

## 2. YARIM KALMIŞ / ÇALIŞMAYAN ÖZELLİKLER

### B1. 🔴 KRİTİK: FCM Push Çalışmıyor — `google-services.json` Yok
**Dosya:** `android/app/google-services.json` (mevcut değil) · `lib/services/fcm_service.dart`

**Sorun:** Firebase yapılandırma dosyası projede yok. `FcmService.initialize()` hatayı yakalayıp **sessizce** push'u devre dışı bırakıyor (`fcm_service.dart:50-55`). Yani tüm FCM altyapısı (token kaydı, `fcm_tokens` tablosu, `send-notification` edge function) kodda var ama **gerçekte hiç bildirim gönderilemez/alınamaz**.

**Risk:** Ürün "push bildirim" vaat ediyor ama özellik tamamen ölü; kullanıcı/admin hiçbir bildirim almaz.

**Çözüm:** Firebase Console → proje oluştur → Android app ekle → `google-services.json`'ı `android/app/`'e koy; iOS için `GoogleService-Info.plist`. Android `build.gradle`'da `com.google.gms.google-services` plugin'inin uygulandığını doğrula. (Dosyayı `.gitignore`'a ekle.)

### B2. 🟠 Bildirimler Kalıcı Değil + Sunucu Tablosu Kullanılmıyor
**Dosyalar:** `lib/services/notification_service.dart` · `lib/screens/notifications_screen.dart` · `fcm_service.dart:8-13`

**Sorun:** `NotificationService` sadece bir in-memory `ValueNotifier<List>`. Uygulama kapanınca **tüm bildirimler kaybolur**. Dahası:
- Arka plan FCM handler'ı yalnızca `debugPrint` yapıyor (`_firebaseMessagingBackgroundHandler`) → app kapalıyken gelen push'lar listeye hiç düşmez.
- Supabase'deki `notifications` tablosu ve `SupabaseDataService.getNotifications/markNotificationRead/...` metotları **hiçbir ekranda çağrılmıyor**. `NotificationsScreen` tamamen yerel servisi okuyor.

**Risk:** Bildirim merkezi güvenilmez; "okundu" durumu cihazlar arası senkronize değil; sunucu kaynaklı bildirimler görünmez.

**Çözüm:** İki yoldan biri:
1. **Tam çözüm:** `NotificationsScreen`'i `SupabaseDataService.getNotifications()`'a bağla, `markNotificationRead`/`deleteNotification` çağır; yerel servisi yalnızca anlık (foreground) uyarılar için kullan, açılışta sunucudan birleştir.
2. **Sadeleştirme:** Sunucu bildirimleri kullanmayacaksanız, en azından yerel listeyi SharedPreferences'a serialize edip restart'ta geri yükleyin; kullanılmayan Supabase metotlarını silin (bkz. A3).

### B3. 🟠 Takvim Notları Yalnızca Cihazda
**Dosya:** `lib/screens/calendar_screen.dart:50-85`

**Sorun:** Notlar `SharedPreferences('calendar_notes_v1')`'a JSON olarak yazılıyor; Supabase'deki `calendar_notes` tablosu ve `getCalendarNotes/addCalendarNote/deleteCalendarNote` metotları **kullanılmıyor**. Notlar reinstall'da kaybolur, cihazlar arası senkron yok.

**Çözüm:** Notları `SupabaseDataService.addCalendarNote(userId, date, note)` ile sunucuya yaz; açılışta `getCalendarNotes(userId)` ile çek. (Çevrimdışı destek istiyorsanız SharedPreferences'ı cache olarak koruyup sunucuyla senkronize edin.)

### B4. 🟢 Production'da "Coming Soon" Placeholder Özellikler
**Dosya:** `lib/widgets/options_sheet.dart:199, 221, 228`

**Sorun:** "Oyun Odası", "Kitap Okuma Kulübü", "Topluluk Haberleri" tıklanınca yalnızca "yakında geliyor 🚀" SnackBar'ı çıkıyor. Yayın sürümünde boş vaatler.

**Çözüm:** Ya gerçekten uygulayın ya da yayın build'inde gizleyin (örn. bir `kFeatureFlags` ile). Eksik özellikleri menüde tutmak profesyonellik algısını düşürür.

---

## 3. MİMARİ / ÖLÜ KOD

### A1. 🟠 `backend/` Klasörü Tamamen Ölü (~1980 satır)
**Dizin:** `backend/` (Node.js + Express + SQLite + Socket.IO + JWT)

**Sorun:** Flutter uygulaması artık Supabase kullanıyor; kodda `localhost:8000`, `/v1/`, `backend` referansı **yok** (grep doğrulandı). Bu komple sunucu (auth, rate-limit, helmet, migrate/seed, route'lar) terk edilmiş paralel bir sistem. `socket_service.dart`'taki "Eski Socket.IO arayüzü korundu" yorumu da bu kalıntıya işaret ediyor.

**Risk:** Kafa karışıklığı; yeni geliştirici hangi backend'in canlı olduğunu bilemez; `backend/.env` içinde `JWT_SECRET` gibi sırlar tutulur (kullanılmasa da sızıntı yüzeyi).

**Çözüm:** `backend/` klasörünü repodan **kaldırın** (veya ayrı bir arşiv repo'ya/`legacy/` dizinine taşıyın ve README'de "kullanılmıyor" notu düşün). Aynı şekilde `socket_service.dart` artık Supabase Realtime sarmalayıcısı — yorumları güncelleyin, "Socket.IO" ifadelerini temizleyin.

### A2. 🟠 Kullanılmayan Bağımlılıklar — APK Şişmesi
**Dosya:** `pubspec.yaml`

**Sorun:**
- `flutter_secure_storage: ^9.2.2` — kodda hiç kullanılmıyor (eski backend token saklama kalıntısı).
- `lottie: ^3.1.3` — hiç import edilmiyor; `assets/animations/rocket_bear.json` da boşta duruyor.

```bash
flutter pub remove flutter_secure_storage lottie
```
Lottie animasyonunu kullanacaksanız bir yerde gösterin (örn. boş-durum ekranları); kullanmayacaksanız asset'i de silin.

### A3. 🟡 SupabaseDataService'te 7 Kullanılmayan Metod
**Dosya:** `lib/services/supabase_data_service.dart`

**Sorun:** Aşağıdaki metotlar tanımlı ama **hiçbir ekran çağırmıyor** (B2/B3 ile ilişkili):
- `getNotifications` (332), `markNotificationRead` (343), `markAllNotificationsRead` (351), `deleteNotification` (359)
- `getCalendarNotes` (415), `addCalendarNote` (424), `deleteCalendarNote` (437)

**Çözüm:** B2/B3'te bu metotları UI'ya bağlamaya karar verirseniz **tutun**; bağlamayacaksanız **silin**. Ortada "yarım" bırakmak en kötüsü.

---

## 4. PERFORMANS (Kalan)

### C1. 🟡 `BackdropFilter` Hâlâ 5 Dosyada
**Dosyalar:** `calendar_screen.dart:291, 379` (2×) · `widgets/podium_card.dart` · `community_detail_screen.dart` · `widgets/options_sheet.dart:96`

**Sorun:** `rapor.md`'de glass_card / profile / admin düzeltildi; ancak:
- **calendar_screen**: 2 adet, üstelik `AnimatedThemeBackground` animasyonu arkasında → sürekli offscreen blur.
- **podium_card**: LeaderboardScreen'de podyum 3 kez render edilir → liste giriş animasyonu sırasında 3× blur.
- **community_detail** ve **options_sheet**: talep üzerine açıldıkları için daha az kritik ama yine de orta segmentte maliyetli.

**Çözüm:** `GlassCard`'ta uygulanan deseni kopyalayın — `BackdropFilter` yerine yarı saydam `Container` (`color: surface.withValues(alpha: 0.5)` + border + hafif `boxShadow`). Özellikle calendar (2×) ve podium (3×) öncelikli.

---

## 5. GÜVENLİK / YAPILANDIRMA

### D1. 🟡 AndroidManifest: Explicit İzinler Eksik
**Dosya:** `android/app/src/main/AndroidManifest.xml`

**Sorun:** Ana manifest'te `INTERNET` ve `POST_NOTIFICATIONS` izinleri açıkça tanımlı değil. `INTERNET` debug manifest'inde/eklentilerle merge olabilir ama **release** için ana manifest'te bulunması güvenlidir. `POST_NOTIFICATIONS` (Android 13+) bildirim göstermek için zorunludur.

**Çözüm:** `<manifest>` altına ekleyin:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```
Ayrıca FCM için varsayılan bildirim kanalı/ikonu meta-data'sı eklemek iyi olur (`com.google.firebase.messaging.default_notification_channel_id`).

---

## 6. UX / KÜÇÜK HATALAR

### E2. 🟡 `_showComingSoon`: Pop Sonrası Context ile SnackBar
**Dosya:** `lib/widgets/options_sheet.dart:72-87`

**Sorun:** Önce `Navigator.pop(context)` (bottom sheet kapatılır), hemen ardından **aynı** (artık deaktive olmuş) `context` ile `ScaffoldMessenger.of(context).showSnackBar(...)`. Bu, "deactivated widget's ancestor" hatasına veya SnackBar'ın hiç görünmemesine yol açabilir.

**Çözüm:** Pop'tan önce messenger referansını alın:
```dart
void _showComingSoon(BuildContext context, String featureName) {
  final messenger = ScaffoldMessenger.of(context);
  final theme = themeNotifier.value;
  Navigator.pop(context);
  messenger.showSnackBar(SnackBar(content: Text('$featureName yakında geliyor! 🚀'), ...));
}
```

### E3. 🟢 Takvim Notuna Uzunluk Limiti Yok
**Dosya:** `lib/screens/calendar_screen.dart:393` (`TextField` `maxLines: 6`, `maxLength` yok)

**Sorun:** Not alanına sınırsız uzunlukta metin girilip SharedPreferences'a yazılabilir. Sunucuya taşınırsa (B3) bir de DB tarafında limit gerekir.

**Çözüm:** `maxLength: 2000` ekleyin; sunucuya taşırken `calendar_notes.note` için CHECK constraint koyun.

---

## 7. ÖNERİLEN SPRINT (1 gün — hızlı kazanımlar)

1. **`widget_test.dart`'ı düzelt** (E1) + birkaç Supabase'siz unit test ekle.
2. **Kullanılmayan bağımlılıkları kaldır** (A2): `flutter pub remove flutter_secure_storage lottie`.
3. **`backend/` klasörünü arşivle/kaldır** (A1) + `socket_service.dart` yorumlarını güncelle.
4. **`_showComingSoon` context hatası** (E2) — 3 satır.
5. **Kalan `BackdropFilter`'ları kaldır** (C1) — özellikle calendar (2×) ve podium (3×).
6. **AndroidManifest izinleri** (D1) — 2 satır.
7. **Karar ver:** Bildirim & takvim sunucu senkronu (B2/B3) yapılacak mı? Yapılacaksa bağla, yapılmayacaksa kullanılmayan metotları sil (A3).
8. **FCM'i etkinleştir** (B1): `google-services.json` ekle (ürün push vaat ediyorsa şart).

> Bu maddelerin tamamı **kod tarafında uygulanabilir** (B1 hariç — Firebase Console'dan dosya indirmenizi gerektirir). İstersen 1-7'yi doğrudan uygulayabilirim.
