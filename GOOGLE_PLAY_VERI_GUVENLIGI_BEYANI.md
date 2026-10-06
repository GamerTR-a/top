# Google Play Console — Veri Güvenliği Beyanı Rehberi
## NevGenç Mobil Uygulaması Pre-Filled Form Kılavuzu

Bu belge, Google Play Console > **Uygulama İçeriği (App Content)** > **Veri Güvenliği (Data Safety)** formunu doldururken birebir seçeceğiniz yanıtları içerir.

---

### BÖLÜM 1: Genel Veri Toplama ve Güvenlik Soruları

1. **Uygulamanız gerekli kullanıcı verilerini topluyor veya paylaşıyor mu?**
   - **Yanıt:** Evet

2. **Uygulamanızın topladığı tüm kullanıcı verileri aktarım sırasında şifreleniyor mu (TLS/HTTPS)?**
   - **Yanıt:** Evet *(NevGenç uygulamasındaki tüm ağ iletişimi HTTPS/TLS 1.3 ile şifrelenmektedir)*

3. **Kullanıcılara verilerinin silinmesini talep edebilecekleri bir yöntem sağlıyor musunuz?**
   - **Yanıt:** Evet *(Uygulama içi Profil > Ayarlar > Hesabı Sil butonu ve destek@nevgenc.app e-posta hattı ile anında silme imkanı vardır)*

4. **Uygulamanızın gizlilik politikası bağlantısı var mı?**
   - **Yanıt:** Evet (`https://nevgenc.app/GIZLILIK_POLITIKASI.md` veya `https://nevgenc.app/security.html`)

---

### BÖLÜM 2: Veri Türleri ve Seçilecek Detaylar

#### A. Kişisel Bilgiler (Personal Info)
1. **Ad (Name)**
   - Toplanıyor mu? **Evet**
   - Paylaşılıyor mu? **Hayır**
   - İşleme Türü: **Toplanır (Collected)**
   - Kullanıcı silme talebi mevcut mu? **Evet**
   - Toplanma Amacı: **Uygulama İşlevselliği (App Functionality)**, **Hesap Yönetimi (Account Management)**

2. **E-posta Adresi (Email Address)**
   - Toplanıyor mu? **Evet** (`.edu` / `.edu.tr` kurumsal e-posta)
   - Paylaşılıyor mu? **Hayır**
   - İşleme Türü: **Toplanır (Collected)**
   - Kullanıcı silme talebi mevcut mu? **Evet**
   - Toplanma Amacı: **Uygulama İşlevselliği (App Functionality)**, **Hesap Yönetimi (Account Management)**, **Güvenlik & Doğrulama (Security & Compliance)**

3. **Kullanıcı Kimlik Numarası (User IDs)**
   - Toplanıyor mu? **Evet** (Supabase Auth UID)
   - Paylaşılıyor mu? **Hayır**
   - İşleme Türü: **Toplanır (Collected)**
   - Toplanma Amacı: **Uygulama İşlevselliği (App Functionality)**

---

#### B. Konum (Location)
1. **Hassas Konum (Precise Location)**
   - Toplanıyor mu? **Evet** (Kampüs Haritası & Kupon/Etkinlik Doğrulama)
   - Paylaşılıyor mu? **Hayır**
   - Sürekli/Arka Planda izleniyor mu? **Hayır** (Yalnızca harita ekranı açıkken anlık kullanılır, kaydedilmez)
   - İşleme Türü: **Toplanır (Collected - Ephemeral/Geçici)**
   - Toplanma Amacı: **Uygulama İşlevselliği (App Functionality)**

---

#### C. Fotoğraflar ve Videolar (Photos and Videos)
1. **Fotoğraflar (Photos)**
   - Toplanıyor mu? **Evet** (Profil resmi ve gönderi görseli yükleme)
   - Paylaşılıyor mu? **Hayır**
   - İşleme Türü: **Toplanır (Collected)**
   - Toplanma Amacı: **Uygulama İşlevselliği (App Functionality)**

---

#### D. Uygulama Bilgileri ve Performansı (App Info and Performance)
1. **Çökme Günlükleri (Crash Logs)**
   - Toplanıyor mu? **Evet** (Firebase Crashlytics)
   - Paylaşılıyor mu? **Hayır**
   - Kişisel veriyle eşleştiriliyor mu? **Hayır (Anonim)**
   - Toplanma Amacı: **Analiz (Analytics)**, **Uygulama İyileştirme (App Functionality)**

2. **Performans Verileri (Performance Diagnostics)**
   - Toplanıyor mu? **Evet** (Firebase Performance Monitoring)
   - Paylaşılıyor mu? **Hayır**
   - Kişisel veriyle eşleştiriliyor mu? **Hayır (Anonim)**
   - Toplanma Amacı: **Analiz (Analytics)**

---

### Play Console Form Özet Cetveli
Formu kaydettiğinizde Google Play mağaza sayfanızda şu ifade yayınlanacaktır:
- 🟢 **Veriler aktarılırken şifrelenir** (Data is encrypted in transit)
- 🟢 **Verilerinizin silinmesini talep edebilirsiniz** (You can request that data be deleted)
- 🟢 **Üçüncü taraflarla veri paylaşılmaz** (No data shared with third parties)
