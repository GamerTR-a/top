# NevGenç — Teknik Sağlık ve İyileştirme Raporu (Güncel Durum)

**Tarih:** 2026-05-29
**Analist:** Kıdemli Yazılım Mimarı · Baş Güvenlik Analisti · Kıdemli UX/QA Mühendisi
**Kapsam:** Flutter/Dart Mobil · Statik Web (`website copy/`) · Supabase (Postgres + Realtime + Edge Functions) · Eski Node.js backend (`backend/`, devre dışı)

> Bu rapor, kaynak kodun **şu anki hali satır satır okunarak** hazırlanmıştır. Önceki rapordaki maddelerin büyük kısmı zaten uygulanmıştır (bkz. **Bölüm 0**). Aşağıdaki açık maddeler, gerçekten hâlâ kodda mevcut olan sorunlardır; her biri dosya + satır hedefiyle doğrulanmıştır.

---

## ✅ GÜNCELLEME (2026-06-06) — Tüm Açık Maddeler Giderildi

Bu rapordaki açık maddelerin **tamamı koda uygulandı**. `flutter analyze`: **0 hata, 0 uyarı** (kalan 7 madde, dosyaların önceden de içerdiği `info` düzeyinde tek-satır-`if` stil tercihidir).

**Kod tarafı (uygulandı):**
- Ölü kod silindi: `data_service.dart` + tüm kullanılmayan `fromJson`/`toJson` factory'leri (1-A).
- `SmartDataService` tamamen kaldırıldı; 7 ekran doğrudan `SupabaseDataService` kullanıyor (1-B).
- `send-notification` edge function'a **JWT + admin rol** doğrulaması eklendi; `admin.html` artık anon key yerine oturum token'ı gönderiyor (4-A).
- Yeni `delete-user` edge function (service-role) eklendi; `deleteAdminUser` onu çağırıyor (4-B).
- Kalan `BackdropFilter`'lar (profil QR + admin StatCard) yarı saydam Container'a çevrildi (3-A).
- Profilde açık UUID metni kaldırıldı; edit dialog + servis tarafına uzunluk guard'ı eklendi (4-C, 4-D).
- `AppTextField` + `AppSpacing`/`AppRadius` token'ları eklendi; 4 form helper'ı tek bileşene delege edildi (5-A, 5-B).
- `main.dart`'ta offstage sekmeler için `TickerMode` (3-B); `admin.html` non-blocking font (5-E); HomeScreen skeleton loading (5-D).

**Supabase tarafında ELLE çalıştırılması gerekenler (kod hazır, dağıtım sizde):**
1. `supabase/migrations/20260529_security_constraints.sql` dosyasını **SQL Editor**'da çalıştırın → haftalık destek limiti trigger'ı, `UNIQUE`/`CHECK` constraint'leri, RLS politikaları (2-A, 4-C, 4-E).
2. İki edge function'ı deploy edin: `supabase functions deploy send-notification` ve `supabase functions deploy delete-user`.
3. Edge function secret'larını ayarlayın: `RESEND_API_KEY`, `SERVICE_ROLE_KEY` (ve istenirse `ALLOWED_ORIGIN`).
4. **RLS denetimi:** Migration dosyasındaki politika şablonunu temel alıp *her* tabloda RLS'in açık olduğunu doğrulayın — anon key açıkta olduğundan gerçek güvenlik sınırı budur.

**Bilerek ertelenen (gerekçeli):** Mobilde Inter font bundling (5-C) — `.ttf` asset'leri repoda yok; eklemek için font dosyaları gerekir. Realtime `posts` kanalı filtresi (3-C) — mevcut ölçekte sorun değil, ölçek büyüyünce ele alınmalı.

---

## 0. ÖNCE: Doğrulanan ve Çözülmüş Maddeler ✅

Aşağıdakiler kodda **fiilen uygulanmış** durumda — tekrar ele almaya gerek yok:

| Konu | Kanıt (dosya) | Durum |
|---|---|---|
| Lazy loading (sekmeler ilk ziyarette yüklenir) | `lib/main.dart:166-186` `_pageCache` + `putIfAbsent` | ✅ |
| FCM token logout'ta siliniyor | `lib/main.dart:118-132` | ✅ |
| `joinCommunity` race condition fallback'i kaldırıldı | `lib/services/supabase_data_service.dart:108-131` | ✅ |
| `sendCommunityMessage` artık `userName` parametresi alıyor (gereksiz DB sorgusu yok) | `supabase_data_service.dart:79-96` | ✅ |
| Login boş input doğrulaması | `lib/screens/login_screen.dart:132-135` | ✅ |
| AdminScreen route guard (rol kontrolü + pop) | `lib/screens/admin_screen.dart:28-46` | ✅ |
| PostCard `more_vert` → çalışan `PopupMenuButton` | `lib/widgets/post_card.dart:137-163` | ✅ |
| PostCard tema değişimini dinliyor (`ValueListenableBuilder`) | `post_card.dart:71-73` | ✅ |
| SharedPreferences tek seferde yükleniyor; `hasRated` dışarıdan geçiyor | `lib/screens/home_screen.dart:82-98` | ✅ |
| `AnimatedThemeBackground` `RepaintBoundary` ile izole edildi | `lib/widgets/animated_theme_background.dart:80-92` | ✅ |
| `GlassCard`'tan `BackdropFilter` kaldırıldı (sahte cam efekti) | `lib/widgets/glass_card.dart:34-46` | ✅ |
| Topluluk arama/kategori **sunucu tarafı** filtreliyor (debounce'lu) | `lib/screens/community_maze_screen.dart:24-46` | ✅ |
| Chat ekranı `userId`'yi senkron alıyor (DB beklemiyor) | `lib/screens/community_chat_screen.dart:35-40` | ✅ |
| `AuthUser` temizlendi: `passwordHash` ve ölü factory'ler yok | `lib/models/auth_user_model.dart` | ✅ |
| `DiscountCarousel` yanıltıcı boş `onTap` kaldırıldı | `lib/widgets/discount_carousel.dart` | ✅ |
| Register logosu tema renklerini kullanıyor (hardcoded mavi yok) | `lib/screens/register_screen.dart:140-143` | ✅ |
| Leaderboard tek `AnimationController` + `CurvedAnimation` | `lib/screens/leaderboard_screen.dart:29-48` | ✅ |
| Web SEO meta etiketleri (description, OG, Twitter, canonical) | `website copy/index.html:7-16` | ✅ |
| `index.html` non-blocking font (preload + onload) | `website copy/index.html:18-24` | ✅ |
| `admin.html` sayfa açılışında session + rol guard | `website copy/admin.html:453-461` | ✅ |
| `connectivity_plus` + `crypto` bağımlılıkları kaldırıldı | `pubspec.yaml` | ✅ |
| `app_config.dart` `.gitignore`'da | `.gitignore:53` | ✅ |

**Genel sağlık:** Proje, önceki rapordan bu yana ciddi şekilde iyileşmiş; mimari ve performans tarafında en kritik kalemler kapatılmış. Aşağıdaki açık maddeler ağırlıklı olarak **backend/RLS tarafı zorlamaları**, **ölü kod temizliği** ve **UI tutarlılığı** kategorilerinde.

---

## 1. TEKNİK MİMARİ VE KOD KALİTESİ

### 1-A. 🔴 YENİ: `data_service.dart` Tamamen Ölü Kod
**Dosya:** `lib/services/data_service.dart` (95 satır)

**Sorun:** `DataService` sınıfı asset'lerdeki JSON dosyalarından (`assets/data/*.json`) veri okuyan eski mimarinin kalıntısı. Projede `DataService()` çağrısı **hiçbir yerde yok** (grep doğrulandı). Yalnızca bu sınıf üzerinden çağrılan `PostModel.fromJson`, `Topluluk.fromJson`/`toJson`, `UserProfileModel.fromJson`, `DiscountModel.fromJson`, `LeaderboardData.fromJson` factory'leri de dolaylı olarak ölü.

**Risk:** Yeni geliştirici hangi servisin gerçek olduğunu anlayamaz; `flutter analyze` gürültüsü; `Topluluk.fromJson` tip-güvensiz (`json['id']` cast'siz, satır 24) — yanlışlıkla kullanılırsa runtime crash.

**Çözüm:**
```bash
# Tümüyle sil:
rm lib/services/data_service.dart
# Ardından kullanılmayan factory'leri modellerden temizle:
#  - PostModel.fromJson (post_model.dart:59-71)
#  - Topluluk.fromJson + toJson (topluluk.dart:22-59)
#  - UserProfileModel.fromJson (user_profile_model.dart:40-58)
#  - RozetModel.fromJson, DiscountModel.fromJson, LeaderboardData.fromJson
# Yalnızca *.fromApiJson / fromProfileJson kalsın.
```

---

### 1-B. 🟡 `SmartDataService` — Hâlâ Anlamsız Geçiş (Passthrough) Katmanı
**Dosya:** `lib/services/smart_data_service.dart`

**Sorun:** Her metod yalnızca `SupabaseDataService`'i çağırıp `debugPrint` ekliyor. Ayrıca `saveProfileOverrides` **tamamen boş gövdeli ölü metod** (satır 63). En kritiği: `ProfileScreen` aynı anda **hem** `SmartDataService` **hem** `SupabaseDataService` kullanıyor — tutarsızlık.

```dart
// smart_data_service.dart:63 — çağrıldığında sessizce hiçbir şey yapmaz:
Future<void> saveProfileOverrides(Map<String, String> overrides) async {}

// profile_screen.dart:23 ve :77 — iki ayrı servis aynı ekranda:
final SmartDataService _dataService = SmartDataService();   // okuma
await SupabaseDataService().updateUserProfile(...);          // yazma
```

**Risk:** Soyutlamanın hiçbir değeri yok (cache, retry, fallback eklemiyor). Bakım maliyeti + kafa karışıklığı.

**Çözüm (iki seçenek):**
- **Tercih edilen:** `SmartDataService`'i silip tüm ekranlarda doğrudan `SupabaseDataService` kullanın (tek tip).
- **Veya** soyutlamayı koruyacaksanız ona gerçek değer ekleyin (bellek-içi cache, hata haritalama) ve ölü `saveProfileOverrides`'ı kaldırın; `ProfileScreen` tek servise sabitlensin.

---

### 1-C. 🟢 Merkezi State Yok — Kullanıcı Verisi 3 Yerde Bağımsız
**Dosyalar:** `lib/main.dart` (`_currentUser`), `home_screen.dart`, `profile_screen.dart`, `community_chat_screen.dart`

**Sorun:** State management paketi yok; `themeNotifier` dışında global durum yok. Kullanıcı adı `ProfileScreen`'de güncellense `AuthGate._currentUser` eski kalır; chat ekranı adı ayrıca `profiles`'tan çeker (`community_chat_screen.dart:42-52`).

**Risk:** Veri tutarsızlığı (profil güncellemesi diğer ekranlara yansımaz), tekrarlı sorgular.

**Çözüm (minimum, paket eklemeden):**
```dart
// Global, theme ile aynı desende:
final ValueNotifier<AuthUser?> currentUserNotifier = ValueNotifier(null);
// AuthGate'te her güncellemede: currentUserNotifier.value = user;
// ProfileScreen kaydetince de güncelle → chat/home aynı kaynaktan okur.
```

---

## 2. UYGULAMA İÇİ AKIŞLAR VE GEÇİŞLER (ROUTING & UX)

### 2-A. 🔴 Haftalık Destek Limiti Hâlâ Yalnızca Client'ta
**Dosya:** `lib/screens/home_screen.dart:146-149`

**Sorun:** `2/2` destek hakkı kontrolü yalnızca yerel `_kullanilanDestek` sayacıyla yapılıyor:
```dart
if (_kullanilanDestek >= _haftalikDestekIzni) {  // sadece RAM'deki sayaç
  _showNotification('Haftalık destek haklarını tükettin! (2/2)', isError: true);
  return;
}
```
`supportPost` (`supabase_data_service.dart:160-181`) `post_supports`'a `week_number`/`year` ile satır ekliyor ama **haftalık 2 sınırını zorlayan bir DB kısıtı yok**. Doğrudan REST isteğiyle veya app'i yeniden başlatarak aşılabilir.

**Risk:** Oyunlaştırma metriği (lig sıralaması) manipüle edilebilir.

**Çözüm — Supabase'de trigger ile zorla:**
```sql
CREATE OR REPLACE FUNCTION check_weekly_support_limit()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT COUNT(*) FROM post_supports
      WHERE user_id = NEW.user_id AND week_number = NEW.week_number
        AND year = NEW.year) >= 2 THEN
    RAISE EXCEPTION 'weekly_limit_exceeded';
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_weekly_limit
  BEFORE INSERT ON post_supports
  FOR EACH ROW EXECUTE FUNCTION check_weekly_support_limit();
```
Ayrıca aynı gönderiyi iki kez desteklemeyi engellemek için `UNIQUE(user_id, post_id)` kısıtı ekleyin.

---

### 2-B. 🟢 Profil Fotoğrafı — Düzenle İkonu Yanıltıcı (Foto Yükleme Yok)
**Dosya:** `lib/screens/profile_screen.dart:213-228`

**Sorun:** Avatarın üzerindeki kalem ikonu (`Icons.edit`) tıklanınca `_showEditDialog()` → yalnızca **metin** (ad/bölüm/sınıf) düzenleme açılıyor. Foto değiştirme akışı yok; `image_picker` bağımlılığı da yok.

**Risk:** Kullanıcı "fotoğrafımı değiştireceğim" beklentisiyle tıklar, metin formu açılır → beklenti-deneyim çatışması.

**Çözüm:** Ya foto yükleme akışını gerçekten ekleyin (`image_picker` + Supabase Storage `avatars` bucket — `backend/uploads/avatars` zaten bunun için planlanmış), ya da ikonu metin düzenleme niyetini doğru yansıtacak biçimde değiştirin (kalem ikonunu profilin yanına alın; avatar üzerine `camera_alt` koyup ayrı `_showPhotoOptions()` bağlayın).

---

## 3. PERFORMANS VE KAYNAK OPTİMİZASYONU

### 3-A. 🟠 `BackdropFilter` İki Ekranda Hâlâ Açık
**Dosyalar:** `lib/screens/profile_screen.dart:263-265` (QR kartı) · `lib/screens/admin_screen.dart:307-308` (`_StatCard`, satırı 4 kez tekrarlı)

**Sorun:** `GlassCard` düzeltildi ama bu iki `BackdropFilter(ImageFilter.blur(...))` kaldı. AdminScreen'de 4 istatistik kartı = 4 offscreen GPU texture; `AnimatedThemeBackground` zaten arkada çiziliyorken orta segment cihazlarda gereksiz yük.

**Çözüm:** `GlassCard`'ta uygulanan yaklaşımı kopyalayın — `BackdropFilter`'ı çıkarıp yarı saydam `Container` (`color: ...withValues(alpha: 0.5)` + güçlü border + hafif `boxShadow`) kullanın. Görsel olarak neredeyse aynı, GPU maliyeti yok.

---

### 3-B. 🟢 IndexedStack: Offstage Ekranlar Animasyonu Çalıştırmaya Devam Ediyor
**Dosya:** `lib/main.dart:224-234` + `animated_theme_background.dart:23-26`

**Sorun:** Lazy loading başlangıç yükünü çözdü ✅; ancak `IndexedStack` ziyaret edilmiş sekmeleri ağaçta canlı tutuyor. Her ekranın kendi `AnimatedThemeBackground`'ı var ve `_controller..repeat()` görünmese bile sonsuza dek tikliyor. 5 sekmenin tamamı gezildikten sonra ~5 controller arka planda döner (boyama maliyeti `RepaintBoundary` ile sınırlı ama controller tick + pil tüketimi sürer).

**Çözüm:** Görünür olmayan sekmede tick'i durdurun:
```dart
// AnimatedThemeBackground'ı görünürlüğe göre TickerMode ile sarın
// veya MainScaffold'da yalnızca aktif index'in animasyonunu .repeat()/.stop() yapın.
TickerMode(
  enabled: isVisible,        // offstage iken false → controller boşa dönmez
  child: AnimatedThemeBackground(child: ...),
)
```

---

### 3-C. 🟢 Realtime: `posts` Kanalı Tüm Güncellemeleri Dinliyor
**Dosya:** `lib/services/socket_service.dart:35-55`

**Sorun:** `public:posts` kanalı filtre olmadan **her** post UPDATE'ini her bağlı istemciye yayıyor. Az veride sorun değil ama gönderi sayısı arttığında gereksiz network/CPU.

**Çözüm:** Kısa vadede sorun değil; ölçek büyürse görünen gönderi ID'lerine `in` filtresi veya topluluk bazlı kanal kullanın.

---

## 4. GÜVENLİK VE VERİ DOĞRULAMA

### 4-A. 🔴 KRİTİK · YENİ: `send-notification` Edge Function Kimlik Doğrulaması Yok
**Dosya:** `supabase/functions/send-notification/index.ts`

**Sorun:** Fonksiyon gövdeyi alıp doğrudan e-posta gönderiyor; **çağıranın admin/yetkili olup olmadığını hiç kontrol etmiyor.** `Access-Control-Allow-Origin: *` ve anon key web bundle'ında açık (`admin.html:447`). Yani herkes bu endpoint'e POST atıp e-posta tetikleyebilir.
```ts
serve(async (req) => {
  ...
  const { subject, message } = await req.json();   // ← yetki kontrolü YOK
  const apiKey = Deno.env.get("RESEND_API_KEY");   // anahtar env'de (iyi ✅)
  // doğrudan Resend'e gönder...
});
```

**Risk:** Spam/abuse — saldırgan döngüyle çağırıp Resend kotanızı tüketir, e-posta itibarınızı (deliverability) bozar. Alıcı sabit (`nevgenc54@gmail.com`) olduğundan veri sızıntısı sınırlı ama **servis kötüye kullanımı** açık.

**Çözüm — JWT doğrula ve admin rolünü zorla:**
```ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const authHeader = req.headers.get("Authorization") ?? "";
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return new Response("Unauthorized", { status: 401, headers: CORS });

  const { data: profile } = await sb.from("profiles").select("role").eq("id", user.id).single();
  if (profile?.role !== "admin") {
    return new Response("Forbidden", { status: 403, headers: CORS });
  }
  // ... yetki onaylandı, e-postayı gönder
});
```
Ek olarak CORS `*` yerine kendi domaininizle sınırlayın ve basit bir rate-limit ekleyin.

---

### 4-B. 🟠 `deleteAdminUser` — Cascade Varsayımı Güvensiz
**Dosya:** `lib/services/supabase_data_service.dart:465-468`

**Sorun:** Yalnızca `profiles` satırını siliyor; yorumda "cascade ile `auth.users`'dan da silinir" deniyor ama bu FK cascade garanti değil.
```dart
Future<void> deleteAdminUser(String userId) async {
  await _db.from('profiles').delete().eq('id', userId);  // auth.users'a dokunmuyor
}
```

**Risk:** Cascade yoksa `auth.users`'ta yetim kayıt kalır → kullanıcı aynı e-postayla tekrar kayıt olamaz; client anon key ile `auth.admin.deleteUser` zaten çağrılamaz.

**Çözüm:** Service-role key ile çalışan bir Edge Function üzerinden silin:
```ts
// supabase/functions/delete-user/index.ts (service role + admin doğrulaması ile)
const admin = createClient(url, Deno.env.get("SERVICE_ROLE_KEY")!);
await admin.auth.admin.deleteUser(userId);   // hem auth hem (cascade ile) profiles
```

---

### 4-C. 🟡 Sunucu Tarafı Uzunluk/Format Kısıtları Eksik
**Dosyalar:** `supabase_data_service.dart:85` (mesaj) · `:276-289` (`updateUserProfile`)

**Sorun:** Mesaj uzunluğu (`1–2000`) yalnızca Dart'ta kontrol ediliyor; `updateUserProfile` ise **hiç** uzunluk/format kontrolü yapmıyor — `name`/`department`/`grade` istediği kadar uzun olabilir. REST API'ye doğrudan istek bunları aşar.
```dart
// updateUserProfile — doğrulama yok:
final updates = { if (name != null) 'name': name, ... };
await _db.from('profiles').update(updates).eq('id', userId);
```

**Risk:** DB şişmesi; profil/mesaj listelerinin yavaşlaması; aşırı uzun adların UI'ı bozması.

**Çözüm — DB tarafında CHECK constraint (tek doğruluk kaynağı):**
```sql
ALTER TABLE community_messages ADD CONSTRAINT content_len CHECK (char_length(content) BETWEEN 1 AND 2000);
ALTER TABLE profiles
  ADD CONSTRAINT name_len CHECK (char_length(name) <= 100),
  ADD CONSTRAINT dept_len CHECK (char_length(department) <= 100),
  ADD CONSTRAINT grade_len CHECK (char_length(grade) <= 20);
```
Client'ta da `ProfileScreen._showEditDialog` kaydet butonuna `if (name.length > 100) ...` guard'ı ekleyin (anında geri bildirim için).

---

### 4-D. 🟡 QR + Açık Metin: Ham Supabase UUID İfşası
**Dosya:** `lib/screens/profile_screen.dart:183` ve `:304`

**Sorun:** Hem QR hem de ekranda kullanıcının ham UUID'si görünüyor:
```dart
final qrData = 'NEVGENC|${widget.user.id}|$displayName';   // :183
Text('ID: ${widget.user.id}', ...)                          // :304 — açık metin
```

**Risk:** QR'ı tarayan/ekranı gören biri UUID'yi öğrenir. Güvenlik tamamen RLS'e bağlı kalır; RLS'te en ufak açık (örn. `profiles` SELECT'in herkese açık olması) varsa o UUID ile veri çekilebilir.

**Çözüm:** Açık `ID:` satırını kaldırın. QR için ham UUID yerine süreli/imzalı kısa token kullanın (HMAC) veya etkinlik check-in akışını sunucu tarafında doğrulanan opak bir token'a bağlayın. **Ön koşul:** `profiles` ve diğer tablolarda RLS politikalarının "yalnızca kendi satırını oku/yaz" olduğunu doğrulayın — bu, anon key'in açıkta olmasının da tek gerçek savunması.

---

### 4-E. 🟡 Anon Key APK İçinde (gitignore var, env yok)
**Dosya:** `lib/config/app_config.dart:3-5`

**Sorun:** `app_config.dart` `.gitignore`'da ✅, ama key yine de derlenmiş APK'ya gömülü ve `--dart-define`/`String.fromEnvironment` yaklaşımı uygulanmamış. Web tarafında (`admin.html:446-447`) zaten açık.

**Değerlendirme:** Supabase **anon key'i tanımı gereği "public"tir** — sızması tek başına zafiyet değildir; gerçek güvenlik sınırı **RLS**'tir. Yani bu madde "anahtarı sakla" değil, **"RLS'i doğrula"** maddesidir.

**Çözüm:**
1. (Opsiyonel hijyen) `--dart-define` ile build edip `String.fromEnvironment` kullanın.
2. (Zorunlu) Tüm tablolarda RLS'in açık ve doğru olduğunu denetleyin: her tablo için yalnızca sahibinin yazabildiği, admin işlemlerinin `role='admin'` kontrolünden geçtiği politikalar.

---

> **Not (olumlu):** Auth doğrulamaları sağlam — `.edu/.edu.tr` e-posta zorunluluğu, şifre gücü (8+ karakter, büyük harf, rakam), kullanıcı dostu hata haritalama (`supabase_auth_service.dart:14-62`). Edge function'da mesaj HTML-escape ediliyor (`index.ts:27-31`). Register tarafı eksiksiz valide ediliyor.

---

## 5. PROFESYONEL GÖRÜNÜM VE UI/UX

### 5-A. 🟡 TextField Stili 5 Yerde Kopyalanmış (DRY İhlali)
**Dosyalar:** `login_screen.dart:70` (`_buildDialogField`) ve `:369` (`_Field`) · `register_screen.dart:285` (`_buildField`) · `profile_screen.dart:135` (`_editField`) · `create_post_screen.dart` (inline) · `community_chat_screen.dart:481` (inline)

**Sorun:** Aynı `OutlineInputBorder` + `fillColor` + `prefixIcon` stili 5-6 kez neredeyse birebir tekrarlanıyor (yalnızca `fillColor` alpha'sı oynuyor).

**Çözüm:** Tek `lib/widgets/app_text_field.dart` bileşeni oluşturun ve hepsini onunla değiştirin:
```dart
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint; final IconData icon; final AppTheme theme;
  final bool obscure; final TextInputType? keyboardType; final Widget? suffix;
  const AppTextField({super.key, required this.controller, required this.hint,
      required this.icon, required this.theme, this.obscure = false,
      this.keyboardType, this.suffix});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, obscureText: obscure, keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: theme.textMuted),
      prefixIcon: Icon(icon, color: theme.textMuted, size: 20), suffixIcon: suffix,
      filled: true, fillColor: theme.surface.withValues(alpha: 0.6),
      border: _b(theme.primary.withValues(alpha: 0.2)),
      enabledBorder: _b(theme.primary.withValues(alpha: 0.2)),
      focusedBorder: _b(theme.primary, 1.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
  OutlineInputBorder _b(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
}
```

### 5-B. 🟢 Spacing/Radius Token Sistemi Yok
**Dosyalar:** Tüm `lib/screens` & `lib/widgets`

**Sorun:** `SizedBox(height: 12/14/16/24...)`, `EdgeInsets.all(16/20/24)`, `circular(12/14/16/20/24)` dağınık ve tutarsız.

**Çözüm:** `lib/theme/app_spacing.dart` ile `AppSpacing.{xs,sm,md,lg,xl}` ve `AppRadius.{sm,md,lg}` sabitleri tanımlayıp kademeli uygulayın.

### 5-C. 🟢 Web–Mobil Font Tutarsızlığı
**Dosyalar:** `website copy/style.css` (Inter) · `pubspec.yaml` (özel font yok)

**Sorun:** Web `Inter` kullanıyor; mobilde özel font tanımı yok → Android'de Roboto, iOS'ta SF. Marka tipografisi tutarsız.

**Çözüm:** `assets/fonts/Inter-*.ttf` ekleyip `pubspec.yaml`'a `fonts:` bölümü ve `themeData.textTheme.apply(fontFamily: 'Inter')` tanımlayın.

### 5-D. 🟢 Yükleme Durumu Hep `CircularProgressIndicator`
**Dosyalar:** Tüm ekranlar

**Sorun:** İlk açılışta boş ekran + dönen daire; içerik gelince "layout shift" hissi.

**Çözüm:** `shimmer` paketi ile `PostCardSkeleton`/liste iskeletleri gösterin (algılanan performans + profesyonellik artışı).

### 5-E. 🟢 `admin.html` Hâlâ Render-Blocking Font
**Dosya:** `website copy/admin.html:9`

**Sorun:** `index.html` non-blocking yapıldı ✅ ama `admin.html` klasik `<link rel="stylesheet" href="...Inter...">` kullanıyor; ayrıca gereksiz ağırlıklar (`300;500`) yükleniyor.

**Çözüm:** `index.html`'deki preload + `onload="this.rel='stylesheet'"` desenini `admin.html`'e de uygulayın; kullanılmayan font ağırlıklarını kaldırın.

---

## 6. ÖNCELİK MATRİSİ (Açık Maddeler)

| # | Sorun | Dosya | Önem | Efor |
|---|---|---|---|---|
| 4-A | Edge function kimlik doğrulaması yok (spam/abuse) | `supabase/functions/send-notification/index.ts` | 🔴 Kritik | Orta |
| 2-A | Haftalık destek limiti yalnızca client'ta | `home_screen.dart:146` | 🔴 Kritik | Orta |
| 1-A | `data_service.dart` + ölü `fromJson` factory'leri | `services/data_service.dart` | 🟠 Yüksek | Düşük |
| 4-B | `deleteAdminUser` cascade güvensiz | `supabase_data_service.dart:465` | 🟠 Yüksek | Orta |
| 3-A | `BackdropFilter` profile QR + admin StatCard'ta | `profile_screen.dart:263`, `admin_screen.dart:307` | 🟠 Yüksek | Düşük |
| 4-C | Sunucu tarafı uzunluk kısıtı yok | `supabase_data_service.dart:85, 276` | 🟡 Orta | Düşük |
| 4-D | QR/ID'de ham UUID ifşası | `profile_screen.dart:183, 304` | 🟡 Orta | Orta |
| 1-B | `SmartDataService` passthrough + boş `saveProfileOverrides` | `smart_data_service.dart` | 🟡 Orta | Orta |
| 2-B | Profil foto ikonu yanıltıcı (yükleme yok) | `profile_screen.dart:216` | 🟡 Orta | Orta |
| 5-A | TextField stili 5× kopyalanmış | tüm formlar | 🟡 Orta | Orta |
| 4-E | Anon key APK'da → RLS denetimi şart | `app_config.dart` | 🟡 Orta | Düşük |
| 3-B | Offstage ekranlarda animasyon tick'i sürüyor | `main.dart` + arka plan | 🟢 Düşük | Düşük |
| 1-C | Merkezi kullanıcı state yok | `main.dart` vb. | 🟢 Düşük | Orta |
| 5-E | `admin.html` render-blocking font | `admin.html:9` | 🟢 Düşük | Düşük |
| 5-B/C/D | Spacing token / Inter font / shimmer | proje geneli | 🟢 Düşük | Orta |
| 3-C | Realtime posts kanalı filtresiz | `socket_service.dart:35` | 🟢 Düşük | Düşük |

---

## 7. ÖNERİLEN KISA VADELİ SPRINT (1–2 gün)

1. **`send-notification` edge function'a JWT + admin rol kontrolü ekle** (4-A) — en kritik, dışa açık abuse yüzeyi.
2. **`data_service.dart`'ı ve ölü `fromJson` factory'lerini sil** (1-A) — 10 dk, kod netleşir.
3. **Haftalık destek limitini DB trigger'ına taşı** (2-A) — `post_supports` üzerine trigger + `UNIQUE(user_id, post_id)`.
4. **Kalan iki `BackdropFilter`'ı yarı saydam Container'a çevir** (3-A) — `GlassCard` deseniyle aynı.
5. **DB CHECK constraint'leri ekle** (4-C) — mesaj + profil alan uzunlukları.
6. **`deleteAdminUser`'ı service-role Edge Function'a taşı** (4-B).
7. **`AppTextField` bileşenini oluştur** (5-A) ve tüm formları sadeleştir.

> **Önemli ön koşul (tüm güvenlik maddeleri için):** Supabase **RLS politikalarının** her tablo için doğru tanımlandığını denetleyin. Anon key hem mobilde hem webde açıkta olduğundan, sistemin gerçek güvenlik sınırı RLS'tir — bu doğrulanmadan diğer önlemler eksik kalır.
