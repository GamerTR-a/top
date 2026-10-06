# NevGenç Mobil Uygulaması Gizlilik Politikası

**Son Güncelleme Tarihi:** 29 Ağustos 2026

**NevGenç** ("Uygulama", "Biz") olarak, kullanıcılarımızın ("Kullanıcı", "Siz") kişisel verilerinin gizliliğine ve güvenliğine büyük önem veriyoruz. Bu Gizlilik Politikası, **NevGenç** mobil uygulamasını kullandığınızda hangi kişisel verilerinizin toplandığını, bu verilerin hangi amaçlarla işlendiğini, kimlerle paylaşıldığını, veri güvenliği tedbirlerimizi ve 6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") ile Genel Veri Koruma Tüzüğü ("GDPR") kapsamındaki haklarınızı açıklamaktadır.

---

## 1. Toplanan Kişisel Veriler ve Toplama Yöntemleri

Uygulamayı kullanırken sunduğumuz hizmetlerin niteliğine bağlı olarak aşağıdaki verileriniz işlenmektedir:

### a) Hesap ve Profil Bilgileri
- **Kimlik ve İletişim Verileri:** Ad, soyad, kurumsal öğrenci e-posta adresi (`.edu` / `.edu.tr` uzantılı) ve hesabınız için belirlediğiniz şifre. *(Şifreniz kimlik doğrulama altyapımızda güvenli kriptografik algoritmalarla hash'lenerek saklanır; tarafımızca asla düz metin olarak görülemez veya erişilemez.)*
- **Akademik ve Profil Detayları:** Üniversite/Fakülte, bölüm, sınıf bilgisi, profil fotoğrafı (yüklemeniz halinde), kazandığınız rozetler, puanlar ve sistem içi oluşturulan dijital **NevGenç QR Kimlik** verileri.

### b) Konum Verileri (İsteğe Bağlı ve Hassas İzinler)
- **Kampüs Haritası ve Navigasyon:** Uygulama içerisindeki "Kampüs Cepte" (kampüs haritası, pusula ve etkinlik lokasyonları) özelliğini kullandığınızda, size harita üzerinde anlık konumunuzu gösterebilmek ve kampüs içi yönlendirme yapabilmek amacıyla cihazınızın hassas ve yaklaşık konum verileri (`ACCESS_FINE_LOCATION` ve `ACCESS_COARSE_LOCATION`) işlenir.
- **Konum Kullanım İlkemiz:** Konum bilginiz yalnızca uygulama açıkken ve ilgili harita ekranını kullandığınız esnada anlık olarak işlenir; arka planda gizlice izlenmez, sunucularımızda kronolojik konum geçmişi olarak kaydedilmez ve üçüncü taraflara satılmaz.

### c) Kamera ve Medya / Galeri İzinleri
- **Profil ve İçerik Görselleri:** Profil fotoğrafı belirleme, topluluk logosu yükleme veya gönderilerinize görsel ekleme işlevleri için cihazınızın kamerası (`CAMERA`) veya fotoğraf seçicisi (Android Photo Picker) aracılığıyla yalnızca sizin seçtiğiniz görsellere erişilir. Uygulamamız galeri veya cihaz depolamanızdaki diğer kişisel dosyalarınıza erişmez.

### d) Bildirim ve Cihaz Verileri
- **Anlık Bildirimler (Push Notifications):** Duyurular, etkinlik hatırlatmaları, topluluk mesajları ve sistem bilgilendirmelerini iletebilmek amacıyla cihazınıza özel Firebase Cloud Messaging (FCM) token bilgisi ve `POST_NOTIFICATIONS` izni işlenir. Bu bildirimleri Ayarlar > "Bildirim ve Gizlilik Tercihleri" ekranından istediğiniz zaman kapatabilirsiniz.
- **Çökme Raporları ve Performans Verileri:** Uygulama beklenmedik şekilde kapanırsa hatanın nedenini bulup düzeltebilmemiz için Firebase Crashlytics aracılığıyla anonim teknik hata raporu (hatanın oluştuğu kod satırı, cihaz modeli, işletim sistemi sürümü) gönderilir; ayrıca uygulamayı hızlandırabilmemiz için Firebase Performance Monitoring aracılığıyla açılış süresi ve ağ isteği süreleri gibi anonim performans verileri toplanır. Bu veriler isim, e-posta gibi kişisel veri İÇERMEZ ve Ayarlar > "Bildirim ve Gizlilik Tercihleri" ekranından tek bir anahtarla kapatılabilir.

### e) Kullanıcı Tarafından Oluşturulan İçerikler ve Etkileşimler
- Oluşturduğunuz gönderiler, yorumlar, topluluk sohbet mesajları, katıldığınız etkinlikler, beğeni/destek kayıtları ve kişisel takvim görevleriniz.

### f) Yerel Depolama (Local Storage / Cache)
- Çevrimdışı kullanım hızını artırmak ve oturum tercihlerinizi korumak amacıyla cihaz içi güvenli yerel depolama (`SharedPreferences` / Önbellek) kullanılır.

---

## 2. Kişisel Verilerin İşlenme Amaçları

Kişisel verileriniz aşağıdaki amaçlarla sınırlı ve ölçülü olarak işlenmektedir:
1. Kullanıcı hesabınızı oluşturmak, kimliğinizi doğrulamak ve güvenli giriş sağlamak,
2. Uygulamanın temel işlevlerini (Topluluklar, Etkinlikler, Gönderiler, Kampüs Haritası, Takvim ve Liderlik Tablosu) sunmak,
3. Kampüs içi harita ve yönlendirme hizmetlerini anlık konumunuzla entegre çalıştırmak,
4. Bildirimler ve duyurular aracılığıyla sizi kampüs etkinliklerinden haberdar etmek,
5. Siber güvenliği sağlamak, yetkisiz erişimleri ve kötüye kullanımı önlemek,
6. Hizmet kalitemizi iyileştirmek ve teknik hataları tespit edip gidermek.

---

## 3. Verilerin Aktarıldığı Üçüncü Taraflar ve Hizmet Sağlayıcılar

Verileriniz hiçbir koşulda üçüncü taraflara satılmaz veya ticari/reklam amaçlarıyla paylaşılmaz. Hizmetlerin yürütülmesi için yalnızca aşağıdaki güvenilir altyapı sağlayıcıları ile veri işlenmektedir:

- **Supabase Inc.:** Veritabanı barındırma, kullanıcı kimlik doğrulama (Auth) ve medya depolama (Storage) hizmetleri. Verileriniz Supabase'in **SOC 2 Type II, HIPAA ve GDPR** sertifikalı bulut altyapısında Satır Düzeyi Güvenlik (RLS - Row Level Security) protokolleri ile korunmaktadır.
- **Google Firebase (Google LLC):** Cihazınıza anlık bildirim (push notification) iletebilmek için FCM altyapısı, uygulama çökmelerini tespit edip düzeltebilmek için Crashlytics ve Performance Monitoring kullanılır. Google Cloud altyapısı **ISO/IEC 27001, 27017, 27018, SOC 1, SOC 2, SOC 3 ve PCI-DSS** sertifikalarına sahiptir.
- **OpenStreetMap / Mapbox:** Kampüs haritası karo görsellerinin sunulması için harita servis sağlayıcıları.

---

## 4. Veri Güvenliği ve Altyapı Sertifikasyon Uyumluluğu

Kişisel verileriniz, hesabınız aktif olduğu sürece saklanır. Verilerinizin yetkisiz erişim, kayıp veya kötüye kullanıma karşı korunması için endüstri standardı şifreleme yöntemleri (SSL/TLS 1.3), Satır Düzeyi Güvenlik (RLS) kuralları ve güvenli kimlik doğrulama protokolleri uygulanmaktadır.

NevGenç mobil uygulaması ve sunucu mimarisi **OWASP MASVS (Mobile Application Security Verification Standard v2.0)** güvenlik standartlarına göre denetlenmiş ve yapılandırılmıştır. Verilerinizin saklandığı tüm üçüncü taraf bulut sağlayıcıları bağımsız kuruluşlarca verilmiş uluslararası SOC 2 Type II ve ISO 27001 sertifikalarına sahiptir.

Bazı geçici içerikler, sunucularımızda otomatik olarak ve daha kısa sürelerde silinir:
- Gönderiler: 30 gün,
- Genel duyuru bildirimleri: 1 gün,
- Destek talepleri/şikayetler (çözümlendikten sonra): 7 gün,
- İş ilanları: 14 gün,
- Haber bültenleri: 7 gün.

---

## 5. Hesabı ve Verileri Silme Hakkı (Account Deletion)

Kullanıcılarımızın kendi verileri üzerinde tam kontrol hakkı vardır. Hesabınızı ve ilişkili verilerinizi silmek için iki yöntem mevcuttur:

1. **Uygulama İçi Otomatik Silme:**
   Uygulama içerisinde **Profil / Ayarlar → Hesabı Sil** adımlarını takip ederek hesabınızı, profil bilgilerinizi, gönderilerinizi, rozetlerinizi ve topluluk üyeliklerinizi **anında ve kalıcı olarak** silebilirsiniz.
2. **E-posta İle Silme Talebi:**
   Uygulamaya kayıtlı kurumsal e-posta adresinizden **destek@nevgenc.app** *(veya ilgili destek e-postasına)* subject başlığı "Hesap Silme Talebi" olan bir e-posta göndererek verilerinizin silinmesini talep edebilirsiniz. Talebiniz en geç 30 gün içerisinde işleme alınır.

---

## 6. KVKK ve GDPR Kapsamındaki Haklarınız

6698 Sayılı KVKK'nın 11. maddesi ve GDPR uyarınca aşağıdaki haklara sahipsiniz:
- Kişisel verilerinizin işlenip işlenmediğini öğrenme,
- İşlenmişse buna ilişkin bilgi talep etme ve verilerinizin bir kopyasını alma,
- Verilerinizin işlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,
- Eksik veya yanlış işlenmiş verilerin düzeltilmesini isteme,
- Kanun uyarınca verilerinizin silinmesini veya yok edilmesini talep etme,
- İşlenen verilerin münhasıran otomatik sistemler vasıtasıyla analiz edilmesi suretiyle aleyhinize bir sonucun ortaya çıkmasına itiraz etme.

**Verilerinizi görüntüleme/kopya alma hakkını uygulama içinden kendiniz kullanabilirsiniz:** Profil / Ayarlar → **Verilerim** ekranından profil bilgilerinizi, gönderilerinizi ve taleplerinizi görüntüleyebilir, tamamını JSON formatında panoya kopyalayabilirsiniz.

---

## 7. Çocukların Gizliliği

NevGenç uygulaması yükseköğrenim öğrencilerine yönelik olup kurumsal öğrenci e-postası gerektirmektedir. Uygulamamız 13 yaşın altındaki çocuklardan bilerek kişisel veri toplamaz. 13 yaşından küçük bir çocuğun veri sağladığını fark etmemiz halinde söz konusu veriler derhal silinir.

---

## 8. Politika Değişiklikleri

Bu Gizlilik Politikası zaman zaman güncellenebilir. Önemli bir değişiklik yapıldığında uygulama içi bildirimler veya güncelleme duyuruları aracılığıyla bilgilendirileceksiniz.

---

## 9. İletişim ve Veri Sorumlusu

Gizlilik politikamız, kişisel verilerinizin işlenmesi veya haklarınızın kullanımı ile ilgili her türlü soru, talep ve görüşleriniz için bizimle iletişime geçebilirsiniz:

- **E-posta:** destek@nevgenc.app
- **Uygulama:** NevGenç Mobil Uygulaması / İletişim Sekmesi
- **Geliştirici:** NevGenç Ekibi

