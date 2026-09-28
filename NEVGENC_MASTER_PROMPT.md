# NevGenç — Tek Prompt ile Sıfırdan İnşa (Master Prompt)

> Aşağıdaki metnin tamamını bir yapay zeka kodlama modeline tek seferde verin.

---

## ROLÜN

Sen kıdemli bir **Flutter + Supabase** mobil uygulama mimarı ve geliştiricisisin. Görevin, aşağıda baştan sona tarif edilen **NevGenç** adlı üniversite öğrenci topluluk platformunu, Google Play ve App Store'a gönderilebilecek kalitede, **üretime hazır** şekilde inşa etmek. Binlerce eşzamanlı öğrenciye hizmet verecek; bu yüzden güvenlik, çevrimdışı dayanıklılık ve maliyet (Supabase ücretsiz plan sınırları) birinci sınıf gereksinimdir.

Çalışma kuralların:
- Kodu **fazlar hâlinde** üret (en altta "Teslim Sırası" bölümü). Her fazın sonunda derlenebilir, çalışan bir uygulama olmalı.
- Bir özelliğe ait her şeyi birlikte teslim et: **SQL migration + RLS + RPC → Dart servis metodu → model → ekran**. Veritabanında karşılığı olmayan bir Dart çağrısı ya da ekranı olmayan ölü servis metodu bırakma.
- Güvenliği asla istemciye emanet etme. İstemcideki her kontrol yalnızca kullanıcı deneyimi içindir; asıl kural sunucuda (RLS, trigger, `SECURITY DEFINER` RPC) uygulanır.
- Belirsiz bir noktada makul bir varsayım yap, varsayımını kod yorumuyla değil teslim notunda belirt ve devam et.
- Tüm kullanıcıya görünen metinler **Türkçe**; kod, tablo ve değişken adları İngilizce (ekran/model adlarında Türkçe kökenli adlar serbest: `Topluluk`, `getTopluluklar` gibi).

---

## 1. ÜRÜN VİZYONU

**NevGenç**, Sakarya Üniversitesi (SAÜ) başta olmak üzere üniversite öğrencilerini öğrenci toplulukları (kulüpler) etrafında bir araya getiren bir kampüs yaşam uygulamasıdır. Tek bir uygulamada şunları sunar:

1. **Topluluk keşfi ve üyelik** — 30+ gerçek öğrenci topluluğu, kategorilere göre keşif, katıl/ayrıl.
2. **Topluluk akışı** — toplulukların duyuru ve etkinlik gönderileri; öğrenciler gönderileri destekler (haftalık sınırlı), 1–5 yıldızla puanlar, şikayet eder.
3. **Etkinlikler** — yaklaşan etkinlikler, gönderi içinden "Etkinliğe Katıl", QR kimlik kartıyla etkinlik girişi.
4. **NEV+** — kampüs hayatı süper-menüsü: indirim kuponları (konuma bağlı), iş ilanları, kampüs haritası, kıble pusulası, oyun odası, sosyal medya merkezi, başkan/admin panelleri.
5. **Kişisel araçlar** — takvim/ajanda, görev ve hatırlatıcılar, günlük notlar, anı albümleri.
6. **Oyunlaştırma** — XP puanı, rozetler, liderlik tablosu (topluluklar ve üyeler).
7. **Yönetim** — topluluk başkanları için yönetim paneli, adminler için tam kontrol paneli.

Hedef hissiyat: genç, canlı, animasyonlu ama hızlı; "cam" (glassmorphism) kartlar, temalı hareketli arka planlar, emoji destekli samimi Türkçe dil.

---

## 2. KULLANICI ROLLERİ VE YETKİ MODELİ

Rol, `profiles.role` sütununda tutulur: `'student' | 'baskan' | 'admin'`.

| Rol | Yapabildikleri |
|---|---|
| **Öğrenci** (varsayılan) | Toplulukları görür, katılır/ayrılır; gönderileri okur, destekler, puanlar, şikayet eder; etkinliğe katılır; kupon açar; talep/şikayet oluşturur; kendi profilini düzenler. **Gönderi paylaşamaz.** |
| **Başkan** | Öğrencinin her şeyi + **yalnızca başkanı olduğu topluluk** adına gönderi paylaşır/siler/gizler, üyeleri yönetir, topluluk ayarlarını ve sohbet bağlantılarını düzenler, üyelere bildirim gönderir, analitikleri görür. |
| **Admin** | Her şey: tüm topluluklar adına gönderi, kullanıcı yönetimi, başkan atama/kaldırma, kullanıcı silme, şikayet moderasyonu, talep yönetimi, topluluk oluşturma, haber bülteni, iş ilanları, güncelleme duyurusu. |

Kritik kurallar (sunucuda zorunlu):
- Yeni profil **her zaman** `role='student'` ile oluşur (INSERT policy bunu zorlar).
- Kullanıcı kendi profilini güncelleyebilir ama **rolünü değiştiremez** (`WITH CHECK role = (SELECT role FROM profiles WHERE id = auth.uid())`).
- Rol değişikliği yalnızca admin tarafından yapılır (`profiles_update_admin` policy).
- Başkan ataması: admin panelinden bir kullanıcı bir topluluğa başkan atanır → `communities.chairman_id/chairman_name` güncellenir, `profiles.role='baskan'` olur. Bir kişi aynı anda tek topluluğun başkanı olabilir; atama öncesi eski başkanlığı temizlenir. Başkanlık kaldırılınca rol `student`'a döner (admin ise dokunulmaz).
- Başkan `communities` tablosunu güncelleyebilir ama `chairman_id`/`chairman_name` alanlarını **değiştiremez**.
- Rolü okuyan yardımcı fonksiyon: `current_user_role()` (SECURITY DEFINER, STABLE) — RLS policy'lerinde tekrar tekrar alt sorgu yazmak yerine bunu kullan.

---

## 3. TEKNOLOJİ YIĞINI

**İstemci:** Flutter (Dart SDK ≥ 3.0), Material 3, tek kod tabanı Android + iOS (web için sınırlı stub).

**Arka uç:** %100 **Supabase** — Auth, PostgreSQL (RLS), Storage, Realtime, Edge Functions (Deno/TypeScript), `pg_cron`. Ayrı bir Node/Express sunucusu **yazma**.

**Paketler (pubspec):**
- Veri/Ağ: `supabase_flutter`, `http`, `connectivity_plus`
- Depolama: `shared_preferences`, `flutter_secure_storage` (Supabase oturumu için özel `LocalStorage` adaptörü), `path_provider`, `path`
- Görsel: `cached_network_image`, `image_picker`, `image` (EXIF temizleme)
- UI: `table_calendar`, `fl_chart`, `qr_flutter`, `flutter_native_splash`
- Bildirim: `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `timezone`
- İzleme: `firebase_crashlytics`, `firebase_performance`
- Konum: `flutter_map` + `latlong2` (OpenStreetMap), `geolocator`, `geocoding`, `flutter_compass`
- Diğer: `url_launcher`, `package_info_plus`, `safe_device`

**Proje yapısı:**
```
lib/
  config/        app_config.dart (gitignore'da; .example dosyası repoda)
  constants/     departments.dart (bölüm listesi)
  models/        auth_user, user_profile, topluluk, post, discount, ticket,
                 news, job_listing, leaderboard, campus_poi, memory_gallery
  services/      supabase_auth_service, supabase_data_service, local_storage_service,
                 secure_local_storage, joined_communities_service, fcm_service,
                 local_notification_service, notification_service, socket_service (Realtime),
                 connectivity_service, force_update_service, location_service, campus_poi_data
  screens/       (bkz. Bölüm 5) + baskan_panel/ alt sekmeleri + games/
  widgets/       glass_card, post_card, post_card_skeleton, app_network_image, app_text_field,
                 discount_carousel, flip_coupon_card, news_bulletin_carousel, podium_card,
                 ranking_item, options_sheet, offline_banner, empty_state_widget,
                 animated_theme_background, category_button
  theme/         app_theme.dart, app_spacing.dart
  utils/         app_exception_handler, file_validator, image_sanitizer, navigation_service,
                 secure_screen, timeout_http_client, turkish_text
supabase/
  migrations/    YYYYMMDD_aciklama.sql  ← TEK doğru kaynak, tarih sırasıyla
  functions/     delete-user, send-notification, send-community-notification
  README.md
```

**Mimari ilkeler:**
- Katmanlar: Ekran → Servis (`SupabaseAuthService`, `SupabaseDataService` singleton) → Supabase. Ekranlar doğrudan `Supabase.instance.client` çağırmaz (admin rol koruması hariç).
- Durum yönetimi basit tut: `StatefulWidget` + `ValueNotifier`/`ValueListenableBuilder` (tema için global `themeNotifier`). Ağır bir state kütüphanesi ekleme.
- Supabase istemcisine global `final` ile değil **lazy getter** ile eriş (`SupabaseClient get supabase => Supabase.instance.client;`) — aksi hâlde `initialize` öncesi erişim açılışta çöker.
- Tüm HTTP çağrılarını 15 sn timeout'lu bir `http.Client` sarmalayıcısıyla ver (`Supabase.initialize(httpClient: TimeoutHttpClient(...))`).
- Auth akışı **PKCE**, oturum `flutter_secure_storage` tabanlı özel `LocalStorage` ile saklanır.

---

## 4. UYGULAMA AÇILIŞI VE NAVİGASYON

**`main()`** (`runZonedGuarded` içinde):
1. `LocalStorageService` başlat (kullanıcının çökme raporu onayını okumak için Firebase'den önce).
2. `Firebase.initializeApp()`; Crashlytics ve Performance toplama = `!kDebugMode && kullanıcıOnayı`.
3. Global hata yakalayıcılar: `FlutterError.onError`, `PlatformDispatcher.onError`, zone hatası → Crashlytics. Release'de kırmızı hata ekranı yerine sade "Bir şeyler ters gitti" ekranı (`ErrorWidget.builder`).
4. Edge-to-edge sistem UI (Android 15 uyumu).
5. `Supabase.initialize(...)` — try/catch; başarısızsa uygulama yine açılmalı.
6. Kayıtlı temayı yükle; FCM ve yerel bildirimleri `unawaited` başlat (hata uygulamayı durdurmasın).
7. Bağlantı izleyicisini başlat; `runApp`.

**`MaterialApp.builder`** tüm ekranları `OfflineBanner` ile sarar (çevrimdışıyken üstte ince uyarı şeridi).

**`AuthGate`:**
- Açılışta oturumu kontrol eder (yükleme göstergesi; hata olsa bile mutlaka login'e düşmeli — sonsuz yükleme yasak).
- `onAuthStateChange` dinler: `signedIn` → kullanıcıyı yükle, Realtime bağlan, FCM token kaydet, katılınan toplulukları senkronla; `signedOut` → temizle; `tokenRefreshed` → FCM token yenile.
- İlk frame sonrası **zorunlu güncelleme** kontrolü (`app_settings` tablosundaki minimum build numarası < mevcut build ise kapatılamaz diyalog + mağaza linki).
- Uygulama bir bildirime tıklanarak soğuk başlatıldıysa ilgili ekrana yönlendir.
- Çıkışta: bu cihazın FCM token'ını **yalnızca bu kullanıcıya ait satırdan** sil, Realtime kopar, oturumu kapat, kullanıcıya ait tüm yerel önbelleği temizle (paylaşılan cihazda veri sızmasın).

**Ana iskelet (`MainScaffold`)** — 5 sekmeli alt navigasyon, `IndexedStack` + sayfa önbelleği (sayfa ilk ziyarette oluşturulur, görünmeyen sekmelerin animasyonları `TickerMode` ile durdurulur):

| # | Sekme | Ekran |
|---|---|---|
| 0 | Anasayfa | `HomeScreen` |
| 1 | Topluluklar | `CommunityMazeScreen` |
| 2 | **NEV +** (ortada, altın çerçeveli özel logo) | `NevPlusScreen` |
| 3 | Takvim | `CalendarScreen` |
| 4 | Profil | `ProfileScreen` |

Nav öğeleri `Expanded` ile eşit genişlikte (min 44dp dokunma alanı), `Semantics` etiketli, seçiliyken `easeOutBack` büyüme animasyonu; küçük ekran (<380) / tablet (≥600) için ikon ve yazı boyutu uyarlanır.

---

## 5. ÖZELLİKLER — EKRAN EKRAN

### 5.1 Giriş (`LoginScreen`)
- E-posta + şifre; **yalnızca `.edu` veya `.edu.tr`** uzantılı e-postalar (istemci doğrular, sunucuda `profiles` üzerindeki trigger da `auth.users.email` kontrol eder).
- "Şifremi Unuttum" → Supabase şifre sıfırlama e-postası.
- Hata mesajları **e-posta varlığını sızdırmamalı**: "geçersiz kimlik bilgisi" ve "e-posta doğrulanmadı" tek bir genel mesajda birleşir.
- İsteğe bağlı: **Google ile giriş** — `signInWithOAuth(OAuthProvider.google, redirectTo: 'supabase://login')` (PKCE, tarayıcı + derin link). Google hesabı da `.edu` filtresinden geçer; geçmezse `signOut` + ret. Android manifest'e `supabase://login` intent-filter ekle.
- Başarılı girişte profil yoksa oluştur ("İlk Adım" rozetini ver), `AuthUser`'ı cihaza önbelleğe al (çevrimdışı açılışta login'e düşmesin).

### 5.2 Kayıt (`RegisterScreen`)
- Alanlar: Ad Soyad, `.edu` e-posta, şifre + tekrar, opsiyonel doğum tarihi (tarih seçici), **çoklu bölüm seçimi** (`constants/departments.dart` listesinden, `TEXT[]` olarak saklanır), sınıf.
- Şifre politikası: en az 8 karakter, en az 1 büyük harf, en az 1 rakam.
- E-posta doğrulaması açıksa: "Doğrulama bağlantısı gönderdik" bilgisi; açıksa profil anında oluşur.

### 5.3 Anasayfa (`HomeScreen`)
Yukarıdan aşağı:
1. Kişisel selamlama ("Merhaba, Ad 👋") + **bildirim zili** (okunmamış sayısı rozeti) → Bildirim Merkezi.
2. **Haber bülteni karuseli** (`news_bulletins`, admin yönetir) → haber detay ekranı.
3. **Yaklaşan Etkinlikler 📅** yatay listesi (`events`, tarih/konum).
4. **Topluluk Akışı 🔮** — filtre: "Tümü" / "Konuya Göre" (kategori). Sayfalı (15'er), aşağı çekip yenile, iskelet (skeleton) yükleme, boş durum ve "Tekrar Dene" hata durumu.
5. Admin veya başkansa **FAB** → Gönderi Oluştur.

**Gönderi kartı (`PostCard`)**: topluluk logosu + adı, zaman ("Az önce", "3 sa"), metin (1–5000 karakter), görsel (disk önbellekli), etkinlikse "Etkinliğe Katıl" butonu + katılımcı sayısı, şu etkileşimler:
- **Destek:** her öğrenci **haftada en fazla 2 gönderiyi** destekleyebilir. Hafta/yıl **sunucuda `NOW()`'dan hesaplanır** (istemcinin gönderdiği `week_number`'a güvenme). Optimistik UI; hata olursa geri al. Kalan hak göstergesi.
- **Puan:** 1–5 yıldız; kullanıcı başına tek kayıt (`post_ratings` PK: user_id+post_id), `upsert_post_rating` RPC ortalamayı ve sayıyı atomik günceller, **ilk puanda +10 XP** verir.
- **Şikayet 🚩:** `report_post` RPC (kullanıcı başına gönderi başına 1), admin moderasyon kuyruğuna düşer.
- Gizlenmiş (`status='hidden'`) gönderiler akışta görünmez.

### 5.4 Gönderi Oluştur (`CreatePostScreen`)
- Topluluk seçimi: admin tüm toplulukları, başkan **yalnızca kendi topluluğunu** görür (sunucuda `enforce_posts_leader_insert` trigger'ı da zorlar; öğrenci INSERT'i reddedilir).
- Metin (sayaçlı, maks 5000), galeriden/kameradan görsel veya harici `https://` görsel URL'i, "Etkinlik Katılım Butonu" anahtarı (`is_event`).
- **Görsel yükleme hattı:** dosya doğrulama (tür + boyut) → `ImageSanitizer` ile EXIF/GPS temizleme (`bakeOrientation` + JPEG yeniden kodlama) → birincil host **Telegraph** (`POST https://api.telegra.ph/upload`, 5 MB, 20 sn timeout) → başarısızsa **Supabase Storage `post-images`** bucket'ına `posts/<uid>/...` altına fallback. (Amaç: Supabase 1 GB depolama kotasını korumak.)

### 5.5 Topluluklar (`CommunityMazeScreen`)
- Tüm topluluklar ızgarası; kategori filtre çipleri: Teknoloji, Mühendislik, Bilim, Kariyer, Kültür, Sanat & Müzik, Sosyal, Sosyal Sorumluluk, Spor, Doğa & Gezi, "Tümü"; arama.
- Önce önbellekten anında göster, arka planda tazele.

### 5.6 Topluluk Detay (`CommunityDetailScreen`)
- Logo, ad, kategori, açıklama, üye sayısı, puan, başkan adı.
- **Katıl / Ayrıl** (`community_members`; üye sayısı trigger/RPC ile tutarlı tutulur; katılınanlar yerelde de önbelleklenir ve girişte sunucuyla senkronlanır).
- **Son Faaliyetler** (topluluğun gönderileri + etkinlikleri).
- **"Sohbete Katıl 💬"** → uygulama içi mesajlaşma **yok**; topluluğun **Telegram/Discord** davet bağlantısına derin link (`url_launcher`, `externalApplication`). Bağlantılar `community_links` tablosunda (`community_id` + `platform` UNIQUE, yalnızca `https://`). Başkan/admin bu ekrandan bağlantı ekler/düzenler/kaldırır.
- Başkan/admin için "Topluluk Yönetimi" girişi.

### 5.7 Topluluk Yönetimi (başkan/admin)
- **`CommunityManagementScreen`:** Genel / Gönderiler / Üyeler / Linkler sekmeleri — gönderiyi yayımla/gizle/sil (YAYINDA/GİZLİ rozetleri), üyeyi çıkar, sohbet linklerini yönet, hızlı işlemler.
- **`CommunityAnalyticsScreen`** (`fl_chart`): toplam üye, toplam gönderi, toplam destek, ortalama puan, aktif üye oranı, gönderi başına destek, üye başına gönderi; üye büyüme trendi ve gönderi aktivite trendi grafikleri; en aktif üyeler listesi.
- **`CommunitySettingsScreen`:** ad, logo, kategori, açıklama, harici bağlantılar; "Tehlikeli Bölge" → topluluğu sil (onaylı).

### 5.8 NEV + (`NevPlusScreen`)
Renkli kart ızgarası; her kart bir alt modüle gider:
- **Nev Fırsatlar** — indirim/kupon modülü (5.9)
- **İş İlanları** — `job_listings` (admin ekler/düzenler/siler; öğrenci görür, başvuru linki açar)
- **Kampüs Cepte** — harita (5.10)
- **Oyun Odası** — Tetris, Sudoku, Baloncuk Patlatma (saf Flutter, `CustomPainter`/`Ticker`; en yüksek skor yerelde)
- **SOSYO** — NevGenç'in sosyal medya merkezi (Instagram, LinkedIn, Telegram bağlantıları + hakkında)
- **Kitap Okuma Kulübü** — "yakında" (release'te özellik bayrağıyla gizlenebilir olmalı)
- Rol bazlı: **Başkan Paneli**, **Admin Paneli**

### 5.9 Nev Fırsatlar — Konuma Bağlı Kupon Sistemi
- `discounts`: işletme adı, açıklama, indirim oranı, görsel, kategori, `latitude/longitude`, `geofence_radius_meters` (varsayılan 50), kod öneki alanları.
- Kartlar **çevrilebilir kupon kartı** (`FlipCouponCard`) şeklinde; ön yüz işletme, arka yüz kod.
- Kupon açma: istemci yalnızca ham konumu gönderir → **`claim_coupon(p_discount_id, p_user_lat, p_user_lng)` RPC** sunucuda mesafeyi (haversine) hesaplar, geofence içindeyse önceden üretilmiş havuzdan (`coupons` tablosu) bir kodu atomik olarak kullanıcıya bağlar, **rate limit** uygular, JSON döner (`success`, `code` veya `error` + Türkçe `message`).
- **Asla** istemcide sahte başarı/kod üretme (sahte GPS ile sınırsız kupon açığı doğar). Ağ hatasında dürüst hata mesajı göster.
- Sahte konum/root tespiti için `safe_device` ile uyarı; kupon ekranı `secure_screen` ile ekran görüntüsüne kapalı (yalnızca bu ekran — `FLAG_SECURE`'u tüm uygulamaya uygulama, bazı cihazlarda siyah ekran/çökme yapar).
- Admin RPC'leri `generate_merchant_coupons` ve `export_merchant_paper_list` (işletmeye basılı liste) **yalnızca admin**, `REVOKE ... FROM PUBLIC`.

### 5.10 Kampüs Cepte (`CampusMapScreen`) + Kıble Pusulası
- `flutter_map` + OpenStreetMap karoları (atıf zorunlu: "© OpenStreetMap contributors").
- İlgi noktaları `assets/data/campus_poi.json`'dan: yurtlar, otobüs durakları, Wi-Fi noktaları, ders çalışma alanları, bisiklet ve yürüyüş rotaları (polyline). Kategori filtreleri: Tümü / Yurtlar / Duraklar / Ders Çalışma / Rotalar.
- Konum izni akışı (izin ver / kalıcı reddedildiyse "Ayarları Aç"), "Konumuma git", "Kampüsten uzaktasın 📍" uyarısı, "Yol Tarifi Al" (harici harita uygulaması).
- **Kıble Pusulası 🧭:** `flutter_compass` + konumdan Kâbe yönü ve uzaklığı.

### 5.11 Takvim / Ajanda (`CalendarScreen`) — **yerel öncelikli**
- `table_calendar`; tam ve küçültülmüş görünüm (tercih hatırlanır).
- **Görevler & Hatırlatıcılar:** başlık, açıklama, ikon türü (ödev, kitap, etkinlik, topluluk), renk, saat; tamamla / aktife al / sil / "Tamamlananları Sil". Hatırlatıcılar `flutter_local_notifications` + `timezone` ile **uygulama kapalıyken de** tetiklenir.
- **Notlar & Günlük:** güne bağlı not (maks 2000 karakter).
- Veriler `SharedPreferences`'ta sürümlü anahtarlarla (`calendar_tasks_v1`, `calendar_notes_v1`); ikon `codePoint`, renk ARGB int olarak serileştirilir.
- Yaklaşan topluluk etkinlikleri takvimde işaretlenir.

### 5.12 Profil (`ProfileScreen`) — yerel öncelikli + senkron
- Önce önbellekteki profili anında göster, sonra sunucudan tazele. Düzenleme önce yerelde uygulanır, sonra sunucuya best-effort gönderilir.
- Profil fotoğrafı (kamera/galeri), ad, bölüm(ler), sınıf, üyelik tarihi, XP.
- **"NevGenç Kimliğim"** — kullanıcı ID'sini içeren **QR kod** (`qr_flutter`): "Taratarak Etkinliklere Katılın".
- **Başarılarım ve Anılarım** (`ProfileAchievementsScreen`): kazanılan rozetler (NevGenç Üyesi, İlk Adım, NEV + Üyesi, Topluluk Lideri, Etkinlik Ustası, Sosyal Kelebek, Bilgi Şampiyonu, Kitap Kurdu, Sporcu Genç, Gönüllü Genç, Oyun Ustası), katıldığı topluluklar, katıldığı etkinlikler.
- **Hatıra Galerisi 🔭** (`MemoryGalleryScreen`): kullanıcının cihazda (yalnızca yerel depolama) sakladığı etkinlik fotoğraf albümleri — oluştur, yeniden adlandır, sil, albüm detayında fotoğraf ekle/kaldır.
- **Ayarlar / Seçenekler alt sayfası** (`OptionsSheet`): Tema Özelleştirme, Gizlilik Politikası & Depolama, Verilerim, Bildirim ve Gizlilik Tercihleri, Talep ve Şikayetler, Çıkış Yap, **Hesabı Sil**.

### 5.13 Liderlik Tablosu (`LeaderboardScreen`)
- İki sekme: **Topluluklar** (puana göre) ve **Üyeler** (XP'ye göre, ilk 20). İlk üç için podyum kartları (👑 🥈 🥉), ardından sıralama listesi; "Öne Çıkanlar ✨".

### 5.14 Bildirim Merkezi (`NotificationCenterScreen`)
- Kaynak: Supabase `notifications` tablosu (kalıcı, cihazlar arası) + Realtime ile anlık ekleme; ön plandaki push'lar yerel bildirim olarak da gösterilir.
- Türler: `announcement`, `event_created`, `event_reminder`, `member_joined`, `member_left`, `post_rated`, `post_reported`, `badge_earned`, `community`, `info`; `data` (jsonb) alanı derin link bilgisi taşır; `is_update=true` + `store_url` olan güncelleme duyuruları mağazaya yönlendirir.
- Filtre (Tümü / Okunmamış), "Tümünü Okundu İşaretle", sayfalama ("Daha fazla yükle"), detay görünümü.
- Ayarlar: tür bazlı aç/kapa (duyuru, etkinlik, yeni üye, rozet, rapor), push, Realtime senkron, "30 günden eski okunmuş bildirimleri temizle".

### 5.15 Talep ve Şikayetler (`TicketCreateScreen`, `TicketListScreen`)
- Tür: `complaint` (Şikayet) / `request` (Talep) / `suggestion` (Öneri); konu + açıklama.
- Durum yaşam döngüsü: `open` → `in_progress` → `resolved` / `closed`; admin notu kullanıcıya görünür. Kullanıcı yalnızca kendi taleplerini görür.

### 5.16 Gizlilik ve Veri Hakları (KVKK / App Store 5.1.1(v) / Google Play)
- **Gizlilik Politikası** ekranı (uygulama içinde tam metin + depolama açıklaması).
- **Verilerim** (`MyDataScreen`): profil, rozetler, gönderiler, talepler, katılınan topluluk sayısı — "JSON olarak kopyala" (veri taşınabilirliği).
- **Bildirim ve Gizlilik Tercihleri:** "Bildirimleri Al" (kapatılınca `fcm_tokens` satırı silinir), "Çökme Raporları Gönder" (Crashlytics + Performance için tek onay anahtarı).
- **Hesabı Sil:** onay diyaloğu → `delete_account()` RPC (SECURITY DEFINER; profil ve ilişkili veriler CASCADE silinir, `auth.users` kaydı silinir — `auth.admin.delete_user` plpgsql'den çağrılamaz, doğrudan `DELETE FROM auth.users WHERE id = auth.uid()` kullan) → yerel veriyi temizle → login.

### 5.17 Tema Özelleştirme (`ThemeCustomizerScreen`)
- `ThemeType { starry, geometric, geometricLight, light, custom }` — hazır temalar (Yıldızlı/galaksi, Geometrik koyu, Geometrik açık, Açık) + "Sistemi Kullan" + özel renk.
- Her `AppTheme`: `primary`, `secondary`, `background`, `surface`, `text`, `textMuted`, `themeData` ve **animasyonlu arka plan** (`AnimatedThemeBackground`: yıldızlar, geometrik şekiller; orman/okyanus/galaksi görselleri). Seçim kalıcıdır ve anında tüm uygulamaya yansır (`themeNotifier`).
- Performans: `BackdropFilter` blur **kullanma** (özellikle liste ve animasyon arkasında); cam efektini yarı saydam yüzey + ince kenarlık + hafif gölgeyle taklit et (`GlassCard`).

### 5.18 Başkan Paneli (`BaskanPanelScreen`)
Başkanın atanmış topluluğu yoksa "Atanmış Topluluk Bulunamadı" boş durumu. Sekmeler:
- **Gönderiler** — kendi topluluğunun gönderileri, silme (onaylı).
- **Üyeler & Mailler** — üye listesi (ad, bölüm, rol), üyeyi çıkar, **"Tüm Katılımcı Maillerini Kopyala 📋"**.
- **Bildirim Gönder** — başlık + mesaj → `send-community-notification` Edge Function (çağıranın gerçekten o topluluğun başkanı olduğunu sunucuda doğrular, üyelerin FCM token'larına push + `notifications` satırı; gönderilen sayı döner). Onay diyaloğu, kötüye kullanım için rate limit.
- **Bağlantılar** — Telegram, Discord, Instagram, WhatsApp linkleri.

### 5.19 Admin Paneli (`AdminScreen`)
Açılışta **sunucudan rol kontrolü** (admin değilse ekranı kapat). Sekmeler:
- **Kullanıcılar** — arama, rol rozeti, başkanlık topluluğu; "Başkan Ata" diyaloğu (topluluk açılır menüsü) / "Başkanlığı Kaldır"; **"Kullanıcıyı Sil"** → `delete-user` Edge Function (service role ile; çağıranın admin olduğunu JWT'den doğrular).
- **İstatistikler** — toplam kullanıcı, aktif topluluk, bu hafta yeni üye, gönderi sayıları (`Future.wait` ile paralel).
- **Şikayetler** — `post_reports` kuyruğu: "Gönderiyi Gizle" (`set_post_status`) / "Reddet" / "Değerlendirildi".
- **Talepler** — duruma göre filtre, durum değiştir, admin notu yaz.
- **Topluluklar** — yeni topluluk oluştur, düzenle, başkan belirle.
- **Güncelleme Duyurusu Yap 🚀** — tüm kullanıcılara `is_update` bildirimi + mağaza linki; `app_settings` üzerinden minimum sürümü yükseltme (zorunlu güncelleme).
- **Haber Bültenini Yönet 📰** (`NewsAdminScreen`) ve İş İlanları CRUD.

---

## 6. VERİ TABANI (Supabase / PostgreSQL)

Her tabloda **RLS açık**. Aşağıdaki şema asgari gereksinimdir; tipleri, kısıtları ve indeksleri sen tamamla.

| Tablo | Amaç / Önemli sütunlar | RLS özeti |
|---|---|---|
| `profiles` | `id` (= auth.users.id, CASCADE), `name`, `email`, `role`, `department TEXT[]`, `grade`, `birth_date`, `xp`, `profile_photo`, `created_at` | herkes okur (hassas alanlar hariç görünüm), sahibi günceller (rol kilitli), admin günceller/siler; INSERT yalnızca kendi id'si ve `role='student'` |
| `communities` | `name`, `logo_path`, `category`, `score`, `member_count`, `description`, `chairman_id`, `chairman_name` | herkes okur; admin ALL; başkan kendi satırını UPDATE (chairman alanları kilitli) |
| `community_members` | `community_id`, `user_id`, `joined_at` (PK ikilisi) | üye kendi satırını ekler/siler; başkan kendi topluluğunda siler; okuma herkese |
| `community_links` | `community_id`, `platform` (`telegram`/`discord`/…), `url` (`https://` CHECK) | herkes okur; başkan (kendi topluluğu) / admin yazar |
| `posts` | `community_id`, `community_name`, `community_logo`, `user_id`, `content` (1–5000 CHECK), `image_url`, `is_event`, `status` (`published`/`hidden`), `support_count`, `rating_avg`, `rating_count`, `quality_score`, `created_at` | `published` herkese; INSERT trigger ile admin/başkan(kendi topluluğu); DELETE/UPDATE admin veya o topluluğun başkanı |
| `post_supports` | `user_id`, `post_id`, `community_id` (trigger doldurur), `week_number`, `year` | sahibi ekler/siler; **haftalık 2 sınırı trigger'da, hafta `NOW()`'dan** |
| `post_ratings` | PK (`user_id`, `post_id`), `rating` 1–5 CHECK | yalnızca kendi satırı; yazma `upsert_post_rating` RPC ile |
| `post_reports` | UNIQUE (`post_id`, `user_id`), `reason`, `status` | kullanıcı RPC ile ekler; okuma/güncelleme admin |
| `events` / `event_registrations` | takvim etkinlikleri (başlık, tarih, konum, topluluk) ve kayıtlar | herkes okur; kayıt sahibi yazar |
| `event_participants` | gönderi-içi "Etkinliğe Katıl" (`post_id`, `user_id`) | sahibi ekler/siler; başkan/admin okur |
| `notifications` | `user_id`, `type`, `title`, `body`, `data jsonb`, `is_read`, `is_update`, `store_url`, `created_at` | yalnızca sahibi okur/günceller/siler; yazma Edge Function/RPC |
| `fcm_tokens` | `user_id`, `token` (UNIQUE), `platform`, `updated_at` | yalnızca sahibi |
| `badges` / `user_badges` | rozet tanımları / kazanılanlar | tanımlar herkese; kazanımlar sahibi okur, yazma sunucu |
| `discounts` / `coupons` | işletme + geofence / kod havuzu ve sahiplik | discounts herkes okur; coupons yalnızca sahibinin açtıkları, yazma RPC |
| `user_tickets` | `type`, `subject`, `description`, `status`, `admin_notes` | sahibi okur/ekler; admin ALL |
| `news_bulletins` | başlık, özet, içerik, görsel, tarih | herkes okur; admin yazar |
| `job_listings` | başlık, şirket, açıklama, konum, link, son tarih | herkes okur; admin yazar |
| `app_settings` | `key`/`value` (ör. `min_build_android`, `min_build_ios`, mağaza URL'leri) | herkes okur; admin yazar |

**RPC'ler (hepsi `SECURITY DEFINER`, `SET search_path = public`, içeride `auth.uid()` ve rol kontrolü, gereksizse `REVOKE EXECUTE ... FROM PUBLIC`):**
`current_user_role`, `upsert_post_rating`, `report_post`, `set_post_status`, `increment_post_support`, `decrement_post_support`, `decrement_community_member`, `add_user_xp` (yalnızca sunucu içi/admin; kullanıcı kendine XP basamaz), `claim_coupon`, `generate_merchant_coupons` (admin), `export_merchant_paper_list` (admin), `delete_account`, `cleanup_old_content`.

**Trigger'lar:** e-posta domain doğrulama (`.edu`/`.edu.tr`), `enforce_posts_leader_insert`, `check_weekly_support_limit`, `post_supports.community_id` doldurma, üye sayısı senkronu, `updated_at` güncelleme.

**Storage:** `post-images` (public okuma; yazma yalnızca authenticated ve **yalnızca kendi `posts/<auth.uid()>/` klasörüne**), `avatars` (aynı klasör sahipliği kuralı). Bucket'larda `file_size_limit` (ör. 5 MB) ve `allowed_mime_types` (jpeg/png/webp).

**Realtime:** `notifications` ve `posts` tablolarını `supabase_realtime` yayınına **açıkça ekle** (`ALTER PUBLICATION supabase_realtime ADD TABLE ...`) — eklenmezse hata vermeden sessizce çalışmaz.

**Saklama politikası (`pg_cron`, günlük `cleanup_old_content()`):** gönderiler 30 gün, `announcement` bildirimleri 1 gün, talepler 7 gün, iş ilanları 14 gün, haber bülteni 7 gün. Her tablo kendi `BEGIN/EXCEPTION` bloğunda (biri patlarsa diğerleri çalışsın). Diğer bildirim türleri kullanıcı tarafından manuel temizlenir.

**Seed:** 32 gerçek SAÜ öğrenci topluluğu (ad, kategori, açıklama, logo asset yolu, başlangıç puanı), rozet tanımları, örnek kampüs POI'leri. Demo/test kullanıcılarını seed'e koyma.

**Migration disiplini:**
- `supabase/migrations/` tek doğru kaynaktır; dosyalar tarih önekli ve **idempotent** (`IF NOT EXISTS`, `CREATE OR REPLACE`, `DROP POLICY IF EXISTS` → `CREATE POLICY`).
- Var olan migration'ı değiştirme; yeni tarihli dosya ekle.
- Her migration dosyasının sonuna doğrulama sorguları ekle (`pg_policies`, `pg_proc`, `information_schema.columns`).
- Bir SQL dosyası daha önce çalıştırılmış eski ve zayıf bir tanımı tekrar getirebiliyorsa (ör. rol kilidi olmayan policy), o eski dosyayı da düzelt.

---

## 7. EDGE FUNCTIONS (Deno / TypeScript)

1. **`delete-user`** — Authorization başlığındaki JWT'den çağıranı çöz, `profiles.role='admin'` doğrula, service role ile `auth.admin.deleteUser(targetId)`. Admin değilse 403.
2. **`send-notification`** — admin: hedef kullanıcı(lar)a veya herkese push (FCM HTTP v1, servis hesabı secret'tan) + `notifications` satırı; geçersiz token'ları temizle. İsteğe bağlı e-posta (Resend, `RESEND_API_KEY` secret).
3. **`send-community-notification`** — başkan/admin: çağıranın o topluluğun başkanı olduğunu sunucuda doğrula, topluluk üyelerine push + bildirim satırı, gönderilen sayıyı dön; topluluk başına saatlik rate limit.

Tüm secret'lar `supabase secrets set` ile; hiçbir anahtar istemciye veya repoya girmez. CORS başlıklarını doğru ayarla.

---

## 8. ÇAPRAZ KESEN GEREKSİNİMLER

**Çevrimdışı ve hız (yerel öncelikli desen):**
- Liste verileri (gönderiler 1. sayfa, kuponlar, etkinlikler, topluluklar, profil, `AuthUser`) başarılı ağ yanıtından sonra **ham satırlar** olarak `SharedPreferences`'a sürümlü anahtarlarla yazılır (`offline_cached_posts`, `offline_cached_kuponlar_v1` …). Demo/fallback veri asla önbelleğe yazılmaz.
- Ekran açılışında: senkron önbellek getter'ı → anında göster (skeleton'ı atla) → arka planda ağdan tazele → başarılıysa önbelleği güncelle. Ağ hatasında son veri ekranda kalır.
- Ağ hatasını **sessizce demo veriye düşürerek gizleme**; kullanıcıya "Tekrar Dene" göster, logla.
- Birbirinden bağımsız sorguları `Future.wait` ile paralelleştir.
- Tüm uzak görseller tek bir `AppNetworkImage` widget'ı üzerinden (`cached_network_image`, `cacheWidth` ile bellek dostu, placeholder + fallback; asset yollarını da destekler).
- Kullanıcıya ait önbellek anahtarları kullanıcı ID'si içerir ve çıkışta temizlenir.

**Bildirimler:**
- FCM: izin iste (Android 13+ `POST_NOTIFICATIONS`), token'ı `fcm_tokens`'a upsert et, token yenilemesini dinle, arka plan handler'ı, bildirime tıklayınca `data`'daki hedefe yönlendir (global `navigatorKey`).
- Firebase yapılandırma dosyaları (`google-services.json`, `GoogleService-Info.plist`) yoksa uygulama çökmemeli; push özelliği `kPushEnabled` bayrağıyla devre dışı kalmalı.

**Güvenlik kontrol listesi:**
- `app_config.dart` (Supabase URL + publishable/anon key) gitignore'da; repoda yalnızca `app_config.example.dart`. Service role anahtarı **asla** istemcide.
- Release derlemede `--obfuscate --split-debug-info`; R8/ProGuard açıksa Supabase, Firebase ve Flutter için gerekli keep kuralları.
- Tüm kullanıcı girdilerinde uzunluk sınırları hem istemcide hem DB `CHECK`'lerinde.
- URL'ler yalnızca `https://` kabul edilir.
- Yüklenen görsellerde MIME/boyut doğrulama + EXIF temizliği.
- Admin/başkan ekranları UI'da gizlense bile her işlem sunucuda yeniden yetkilendirilir.

**Erişilebilirlik ve UI:**
- Min 44dp dokunma alanları, `Semantics` etiketleri, yeterli kontrast (açık temada da), büyük yazı tipinde taşma olmaması.
- Tutarlı boşluk sistemi (`AppSpacing`), boş durum (`EmptyStateWidget`), iskelet yükleyiciler, hata + "Tekrar Dene".
- Türkçe büyük/küçük harf ve arama normalizasyonu (`İ/ı`, `Ş/ş` …) için `turkish_text` yardımcıları.
- Tarih biçimleri Türkçe (Ocak, Şub, … / "Az önce", "3 sa önce").

**Gözlemlenebilirlik:** Crashlytics (kullanıcı onayına bağlı), Firebase Performance, anlamlı `debugPrint` logları; yakalanan ama yutulan hatalar en azından loglanır.

---

## 9. PLATFORM, DERLEME VE YAYIN

- **Uygulama adı:** "NevGenç" (Android `android:label`, iOS `CFBundleDisplayName`, `MaterialApp.title`). Paket adı `com.Nevgenc` (veya belirlenen). `minSdk 24`, güncel `targetSdk`.
- Android manifest: `INTERNET`, `POST_NOTIFICATIONS`, konum izinleri; `supabase://login` derin link intent-filter; `launchMode="singleTop"`; varsayılan FCM bildirim kanalı meta-data.
- iOS `Info.plist`: konum, kamera, fotoğraf kütüphanesi kullanım açıklamaları (Türkçe), URL scheme, arka plan push modu.
- `flutter_native_splash` ile açılış ekranı (açık/koyu).
- **CI/CD:** GitHub Actions (Android AAB + iOS IPA; iOS için `macos-15`, `pod install --repo-update`, `xcodebuild archive` → `Payload` zip) ve/veya Codemagic. İmza anahtarları CI secret'larında.
- Sürümleme: `pubspec.yaml` `version: x.y.z+build`; her mağaza yüklemesinde build numarası artar; `app_settings` minimum build'i ile zorunlu güncelleme koordine edilir.
- Not: Windows'ta proje yolu ASCII olmayan karakter içeriyorsa (ör. `Masaüstü`) release AOT derlemesi başarısız olabilir — derleme betiği projeyi ASCII bir yola kopyalayıp orada derlemeyi desteklemeli.

---

## 10. TEST

- Supabase gerektirmeyen **unit testler:** `.edu` e-posta doğrulama, şifre politikası, ISO hafta hesabı, model `fromApiJson`/`toJson` gidiş-dönüşleri, Türkçe metin normalizasyonu, kupon yanıtı ayrıştırma.
- Widget testleri Supabase'i başlatmadan çalışabilmeli (servisleri enjekte edilebilir yap veya init'i sahtele); `flutter test` her zaman yeşil.
- SQL tarafı: her migration sonunda doğrulama sorguları; RLS'i en az üç rolle (anon, student, baskan, admin) elle test etmek için bir kontrol listesi (`supabase/README.md`).
- `flutter analyze` sıfır hata.

---

## 11. TESLİM SIRASI (FAZLAR)

1. **Temel:** proje iskeleti, tema sistemi, `main()` + hata yakalama, `AuthGate`, login/kayıt (.edu + şifre politikası), `profiles` + rol kilidi RLS, 5 sekmeli iskelet (boş ekranlar).
2. **Topluluklar:** `communities`, `community_members`, `community_links` + RLS; keşif ızgarası, detay, katıl/ayrıl, Telegram/Discord derin linkleri; 32 topluluk seed'i.
3. **Akış:** `posts`, destek (haftalık 2, sunucuda hafta), puan, şikayet; anasayfa akışı, gönderi kartı, gönderi oluşturma (Telegraph + Supabase fallback, EXIF temizleme); yerel öncelikli önbellek.
4. **Etkinlikler ve takvim:** `events`, `event_participants`, yaklaşan etkinlikler, takvim/görev/not/hatırlatıcı (yerel bildirim), QR kimlik.
5. **Yönetim:** başkan paneli, topluluk yönetimi/analitik/ayarlar, admin paneli (kullanıcılar, başkan atama, şikayet, talepler, topluluklar, istatistik), `delete-user` Edge Function.
6. **Bildirimler:** `notifications` + Realtime, FCM, bildirim merkezi, `send-notification` / `send-community-notification`, güncelleme duyurusu + zorunlu güncelleme.
7. **NEV+:** kupon sistemi (`claim_coupon` + geofence + rate limit), iş ilanları, haber bülteni, kampüs haritası + kıble, oyun odası, SOSYO.
8. **Oyunlaştırma ve profil:** XP, rozetler, liderlik tablosu, başarılar, hatıra galerisi, tema özelleştirici.
9. **Uyumluluk ve sağlamlaştırma:** gizlilik politikası, Verilerim (JSON dışa aktarma), hesap silme, bildirim/çökme onayları, saklama politikası (`pg_cron`), storage limitleri, güvenlik denetimi (her tabloyu ve RPC'yi rol bazında gözden geçir), testler, CI/CD, mağaza hazırlığı.

Her faz sonunda şunları teslim et: (a) yeni/değişen dosyalar, (b) Supabase SQL Editor'da çalıştırılacak migration dosyaları ve sırası, (c) Dashboard'da elle yapılması gerekenler (Auth provider, redirect URL, secret'lar, bucket ayarları, pg_cron), (d) o fazın kabul kriterleri ve nasıl doğrulanacağı.

---

## 12. KABUL KRİTERLERİ (ÖZET)

- Öğrenci hesabıyla REST API'ye doğrudan istek atarak: kendi rolünü değiştiremez, gönderi ekleyemez, başka topluluğun başkanını değiştiremez, başkasının klasörüne dosya yükleyemez, haftalık 2 destek sınırını aşamaz, sahte konumla veya istemci taraflı kod üreterek kupon alamaz, admin RPC'lerini çağıramaz.
- Başkan yalnızca kendi topluluğunda işlem yapabilir; admin her yerde.
- Uçak modunda uygulama açılır, son görülen akış/topluluklar/profil/takvim görünür, üstte çevrimdışı şeridi çıkar; bağlantı gelince veriler tazelenir.
- Firebase dosyaları eksik olsa veya Supabase'e ulaşılamasa bile uygulama çökmez, anlamlı hata gösterir.
- Hesap silme sonrası kullanıcının sunucu ve cihaz verisi kalmaz.
- `flutter analyze` temiz, `flutter test` yeşil, release AAB/IPA CI'da üretilir.
