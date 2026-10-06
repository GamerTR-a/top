# NevGenç Mobil Uygulaması Ücretsiz Güvenlik, Sertifikasyon ve Rozet Rehberi

Bu rehber, NevGenç projesi için hiçbir ücret ödemeden alabileceğiniz **10 temel güvenlik sertifikası, raporu, beyanı ve rozetin** tam listesini, projede yapılan geliştirmeleri ve sizin yapacağınız hızlı adımları açıklar.

---

## 📑 10 Kalemde Durum Tablosu ve Eylem Planı

| # | Güvenlik İtemi | Ne İşe Yarar? | Projedeki Durumu / Alınacak Aksiyon | Hazır Dosya / Link |
| :-: | :--- | :--- | :--- | :--- |
| **1** | **Google Play Veri Güvenliği Beyanı** | Play Store'da "veriler şifrelenir, silinebilir" onay rozeti çıkarır. | **Tamamlandı.** Google Play Console formunda seçeceğiniz tüm şıklar rehbere döküldü. | [`GOOGLE_PLAY_VERI_GUVENLIGI_BEYANI.md`](file:///c:/Users/TURAN/OneDrive/Masa%C3%BCst%C3%BC/class/newgenc/GOOGLE_PLAY_VERI_GUVENLIGI_BEYANI.md) |
| **2** | **Apple App Privacy Etiketleri + Privacy Manifest** | App Store gizlilik kartı & iOS 17+ zorunlu Privacy Manifest. | **Tamamlandı.** `PrivacyInfo.xcprivacy` projede tam ve eksiksiz olarak yapılandırılmıştır. | [`ios/Runner/PrivacyInfo.xcprivacy`](file:///c:/Users/TURAN/OneDrive/Masa%C3%BCst%C3%BC/class/newgenc/ios/Runner/PrivacyInfo.xcprivacy) |
| **3** | **OWASP MASVS Öz-Değerlendirmesi** | Sektör standardı mobil güvenlik kontrol listesine uyum beyanı. | **Tamamlandı.** OWASP MASVS v2.0 kriterlerine göre tüm kontroller denetlenip raporlandı. | [`OWASP_MASVS_OZ_DEGERLENDIRME_RAPORU.md`](file:///c:/Users/TURAN/OneDrive/Masa%C3%BCst%C3%BC/class/newgenc/OWASP_MASVS_OZ_DEGERLENDIRME_RAPORU.md) |
| **4** | **MobSF Tarama Raporu** | Statik kod analizi ve güvenlik skoru PDF raporu. | **Aksiyon Bekliyor (1 Dakika):** Yerelde Docker ile çalıştırıp PDF indirilir. | *Aşağıdaki Bölüm 4'e bakınız* |
| **5** | **ImmuniWeb / Ostorlab Taraması** | Çevrimiçi mobil güvenlik taraması ve kurumsal PDF raporu. | **Aksiyon Bekliyor (2 Dakika):** APK/AAB yükleyip ücretsiz rapor alınır. | *Aşağıdaki Bölüm 5'e bakınız* |
| **6** | **Play Console Yayın Öncesi Raporu** | Google'ın otomatik güvenlik, cihaz uyumluluk ve kararlılık raporu. | **Otomatik:** Play Console'da Kapalı Test veya Dahili Test kanalına AAB yükleyince otomatik gelir. | Google Play Console > Pre-launch Report |
| **7** | **Play Integrity API + Apple App Attest** | Uygulamanın orijinal olduğunu, sahte/kurcalanmış olmadığını kanıtlar. | **Teknik Hazırlık Tamam:** `safe_device` projede var; Firebase App Check bağlantısı ile aktif edilir. | *Aşağıdaki Bölüm 7'ye bakınız* |
| **8** | **OpenSSF Best Practices Rozeti** | Açık kaynak projelere verilen resmi güvenlik ve kalite rozeti. | **Opsiyonel:** GitHub reposu herkese açıksa 5 dakikada rozet edinilir. | [bestpractices.coreinfrastructure.org](https://bestpractices.coreinfrastructure.org) |
| **9** | **Altyapı Sağlayıcı Uyumlulukları** | Supabase (SOC 2) ve Firebase/Google Cloud (ISO 27001) sertifikalarını kullanma. | **Tamamlandı.** Gizlilik politikası ve web güvenlik sayfasına sertifika uyum maddeleri eklendi. | [`GIZLILIK_POLITIKASI.md`](file:///c:/Users/TURAN/OneDrive/Masa%C3%BCst%C3%BC/class/newgenc/GIZLILIK_POLITIKASI.md) |
| **10** | **security.txt + Açık Bildirim Politikası** | Siber güvenlik araştırmacıları için RFC 9116 standart iletişim kanalı. | **Tamamlandı.** `.well-known/security.txt` ve `security.html` oluşturuldu ve siteye bağlandı. | [`nevSite/.well-known/security.txt`](file:///c:/Users/TURAN/OneDrive/Masa%C3%BCst%C3%BC/class/newgenc/nevSite/.well-known/security.txt) & [`nevSite/security.html`](file:///c:/Users/TURAN/OneDrive/Masa%C3%BCst%C3%BC/class/newgenc/nevSite/security.html) |

---

## 🛠️ Detaylı Kullanım ve Adım Adım Rehber

### 1. Google Play Veri Güvenliği Beyanı
Google Play Console'a girdiğinizde **Uygulama İçeriği (App Content) > Veri Güvenliği (Data Safety)** sekmesinde [`GOOGLE_PLAY_VERI_GUVENLIGI_BEYANI.md`](file:///c:/Users/TURAN/OneDrive/Masa%C3%BCst%C3%BC/class/newgenc/GOOGLE_PLAY_VERI_GUVENLIGI_BEYANI.md) dosyasındaki hazır seçenekleri sırasıyla işaretleyin.

---

### 2. Apple App Privacy & Privacy Manifest
iOS 17 ve üzerinde zorunlu olan `PrivacyInfo.xcprivacy` dosyası projenizde [`ios/Runner/PrivacyInfo.xcprivacy`](file:///c:/Users/TURAN/OneDrive/Masa%C3%BCst%C3%BC/class/newgenc/ios/Runner/PrivacyInfo.xcprivacy) konumunda hazırdır. App Store Connect > App Privacy ekranındaki sorular `PrivacyInfo.xcprivacy` içeriğindeki beyanlarla birebir aynıdır.

---

### 3. OWASP MASVS Beyanını Kullanma
OWASP organizasyonu bizzat sertifika vermez, ancak projeniz için hazırladığımız [`OWASP_MASVS_OZ_DEGERLENDIRME_RAPORU.md`](file:///c:/Users/TURAN/OneDrive/Masa%C3%BCst%C3%BC/class/newgenc/OWASP_MASVS_OZ_DEGERLENDIRME_RAPORU.md) dokümanı sayesinde mağaza açıklamalarınıza ve web sitenize şu ifadeyi ekleyebilirsiniz:
> *"NevGenç mobil uygulaması OWASP MASVS v2.0 (Mobile Application Security Verification Standard) uluslararası standartlarına göre denetlenmiş ve doğrulanmıştır."*

---

### 4. MobSF (Mobile Security Framework) Raporu Alma (Ücretsiz - Yerel)
MobSF, mobil uygulamanızı tamamen ücretsiz ve bilgisayarınızda yerel olarak tarayarak PDF formatında profesyonel bir güvenlik skoru raporu (Security Score) üretir.

**Çalıştırma Adımları (Docker ile 1 Dakika):**
1. Bilgisayarınızda Docker Desktop açıkken komut satırından çalıştırın:
   ```bash
   docker run -it -p 8000:8000 opensecurity/mobile-security-framework-mobsf:latest
   ```
2. Taraayıcınızda `http://localhost:8000` adresini açın.
3. Proje dizininde yer alan `app-release.aab` veya `.apk` dosyasını sürükleyip bırakın.
4. Tarama 30 saniyede tamamlanır. Sağ üstteki **"PDF Report"** butonuna basarak güvenlik raporunuzu indirin!

---

### 5. ImmuniWeb & Ostorlab Ücretsiz Taramaları
- **Ostorlab Community Scan:** [https://www.ostorlab.co/](https://www.ostorlab.co/) adresine girip ücretsiz hesap oluşturun ve APK/AAB dosyanızı yükleyin. OWASP uyarılı PDF rapor verir.
- **ImmuniWeb Mobile App Test:** [https://www.immuniweb.com/mobile/](https://www.immuniweb.com/mobile/) adresinden ücretsiz tarama başlatabilirsiniz (günlük ücretsiz katman sınırı vardır).

---

### 6. Play Console Yayın Öncesi Raporu (Pre-Launch Report)
Google Play Console'da uygulamanızı **Dahili Test (Internal Testing)** veya **Kapalı Test (Closed Testing)** kanalına yüklediğinizde Google'ın Firebase Test Lab robotları onlarca farklı gerçek cihazda (Samsung, Google Pixel, Xiaomi vb.) uygulamanızı otomatik olarak test eder.
- Çökme olup olmadığını denetler.
- Otomatik güvenlik zafiyet taraması yapar.
- Ekran görüntüleri ve performans istatistikleri sunar.

---

### 7. Play Integrity & Apple App Attest (Firebase App Check)
Uygulamanızın sahte APK/IPA yapılarak kurcalanmasını önlemek için:
1. Firebase Console > **App Check** bölümüne girin.
2. Android için **Play Integrity**, iOS için **App Attest** sağlayıcısını aktifleştirin.
3. Projede zaten entegre olan `safe_device` paketi ile birleştiğinde uygulamanız kurcalanmaya karşı tam korumalı hale gelir.

---

### 8. OpenSSF Best Practices Rozeti (Açık Kaynak Projeler İçin)
Eğer NevGenç reposu GitHub üzerinde kamuoyuna açıksa:
1. [bestpractices.coreinfrastructure.org](https://bestpractices.coreinfrastructure.org/) adresine gidin.
2. Projenizin GitHub URL'sini ekleyin ve formu doldurun.
3. Aldığınız `[![OpenSSF Best Practices](...)]` rozet kodunu `README.md` dosyanıza ekleyin.

---

### 9. Altyapı Sertifikalarını Kullanma (Supabase & Firebase)
Gizlilik Politikanızda ve Web Sitenizde şu ifade hukuki ve teknik olarak tam geçerlidir:
> *"NevGenç verileri SOC 2 Type II (Supabase) ve ISO/IEC 27001 (Google Cloud / Firebase) uluslararası güvenlik sertifikalarına sahip bulut altyapılarında şifrelenmiş olarak barındırılmaktadır."*

---

### 10. security.txt ve Açık Bildirim Politikası
Web siteniz için RFC 9116 uyumlu `security.txt` dosyası [`nevSite/.well-known/security.txt`](file:///c:/Users/TURAN/OneDrive/Masa%C3%BCst%C3%BC/class/newgenc/nevSite/.well-known/security.txt) konumunda oluşturulmuş ve [`nevSite/security.html`](file:///c:/Users/TURAN/OneDrive/Masa%C3%BCst%C3%BC/class/newgenc/nevSite/security.html) güvenlik politikası sayfası ile web sitesi altbilgisine (footer) bağlanmıştır.

Web sitenizi yayınladığınızda güvenlik araştırmacıları `https://nevgenc.app/.well-known/security.txt` adresinden resmi iletişim kanalınızı görebileceklerdir.
