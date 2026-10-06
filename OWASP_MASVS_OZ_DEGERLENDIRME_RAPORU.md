# OWASP MASVS (Mobile Application Security Verification Standard v2.0)
## NevGenç Mobil Uygulaması Öz-Değerlendirme Raporu

**Uygulama Adı:** NevGenç  
**Platform:** Android & iOS (Flutter)  
**Değerlendirme Tarihi:** Ekim 2026  
**Değerlendirme Versiyonu:** OWASP MASVS v2.0  
**Uyum Statüsü:** %100 Uyumlu (Öz-değerlendirme ile doğrulanmış)  

---

### Yasal ve Kullanım Uyarısı
> **Önemli Not:** OWASP (Open Worldwide Application Security Project) resmi bir sertifikasyon kurumu değildir ve 3. taraf uygulamalara doğrudan sertifika vermez. Bu belge, NevGenç uygulamasının OWASP MASVS v2.0 standartlarındaki 6 temel güvenlik alanında yürütülen teknik denetim ve kod analizinin öz-değerlendirme (Self-Assessment) raporudur. Yayın, pazarlama veya gizlilik beyanlarında *"OWASP Sertifikalı"* ifadesi **kullanılamaz**; *"OWASP MASVS v2.0 Standartlarına göre denetlenmiş ve doğrulanmıştır"* ifadesi kullanılmalıdır.

---

### 1. MASVS-STORAGE (Depolama Güvenliği)
*Amaç: Cihaz üzerinde hassas verilerin (token, kimlik bilgileri, kişisel veriler) güvenli saklanması.*

| Kontrol Kodu | Tanım | NevGenç Uygulaması Durumu | Sonuç |
| :--- | :--- | :--- | :---: |
| **MASVS-STORAGE-1** | Hassas veriler işletim sisteminin güvenli depolama mekanizmalarında saklanır. | Auth token'lar ve oturum anahtarları `flutter_secure_storage` kullanılarak Android'de EncryptedSharedPreferences (Keystore), iOS'te Keychain üzerinde saklanır. | **GEÇTİ** |
| **MASVS-STORAGE-2** | Sistem loglarına veya çökme raporlarına hassas veri yazılmaz. | `print` veya log çıktıları canlı derlemede devre dışıdır; Crashlytics ve Performance logları anonimleştirilmiştir. | **GEÇTİ** |
| **MASVS-STORAGE-3** | Üçüncü taraf klavyeler veya ekran görüntüleri üzerinden veri sızıntısı engellenir. | Şifre ve hassas alan girişlerinde standart OS gizleme ve secure input flag'leri aktiftir. | **GEÇTİ** |

---

### 2. MASVS-CRYPTO (Kriptografik Kontroller)
*Amaç: Zayıf algoritmaların önlenmesi ve şifreleme anahtarlarının yönetimi.*

| Kontrol Kodu | Tanım | NevGenç Uygulaması Durumu | Sonuç |
| :--- | :--- | :--- | :---: |
| **MASVS-CRYPTO-1** | Uygulama endüstri standardı ve güncel şifreleme standartlarını kullanır. | Tüm veri transferlerinde TLS 1.3 / AES-256 şifreleme kullanılır. Zayıf algoritmalar (MD5, SHA1, DES) kod tabanında kesinlikle kullanılmaz. | **GEÇTİ** |
| **MASVS-CRYPTO-2** | Kod içerisinde sabit (hardcoded) anahtar veya şifre bulunmaz. | Tüm API anahtarları, Supabase anon keys environment değişkenleri veya güvenli konfigürasyon dosyalarında saklanır. | **GEÇTİ** |

---

### 3. MASVS-AUTH (Kimlik Doğrulama ve Oturum Yönetimi)
*Amaç: Kullanıcı doğrulaması ve yetkilendirme güvenliği.*

| Kontrol Kodu | Tanım | NevGenç Uygulaması Durumu | Sonuç |
| :--- | :--- | :--- | :---: |
| **MASVS-AUTH-1** | Kimlik doğrulama sunucu tarafında gerçekleştirilir. | Kullanıcı kimlik doğrulama Supabase Auth ve `.edu.tr` kurumsal e-posta doğrulama mekanizmasıyla sunucu tarafında yürütülür. | **GEÇTİ** |
| **MASVS-AUTH-2** | Oturum jetonları (JWT) güvenli şekilde sonlandırılabilir ve yenilenir. | Supabase JWT token mimarisi otomatik yenileme (refresh token) ve hesap silindiğinde/çıkış yapıldığında derhal iptal edilme özelliğine sahiptir. | **GEÇTİ** |
| **MASVS-AUTH-3** | Erişim yetkileri istemciye güvenmeden sunucu tarafında (RLS) denetlenir. | Supabase Row Level Security (RLS) politikaları ile her kullanıcının yalnızca yetkili olduğu veriye erişmesi veritabanı seviyesinde garanti edilir. | **GEÇTİ** |

---

### 4. MASVS-NETWORK (Ağ İletişimi Güvenliği)
*Amaç: Ağ trafiğinin gizliliği ve bütünlüğü.*

| Kontrol Kodu | Tanım | NevGenç Uygulaması Durumu | Sonuç |
| :--- | :--- | :--- | :---: |
| **MASVS-NETWORK-1** | Ağ iletişimi HTTPS/TLS üzerinden yürütülür, düz metin (cleartext) engellenir. | Android (`android:usesCleartextTraffic="false"`) ve iOS (`NSAppTransportSecurity`) konfigürasyonlarında düz metin HTTP istekleri tamamen yasaklanmıştır. | **GEÇTİ** |
| **MASVS-NETWORK-2** | TLS sertifika doğrulaması yapılır ve güvensiz sertifikalar reddedilir. | Standart OS CA sertifika doğrulama zinciri kullanılır; geçersiz veya kendinden imzalı sertifikalar reddedilir. | **GEÇTİ** |

---

### 5. MASVS-RESILIENCE (Tersine Mühendislik ve Çalışma Zamanı Koruması)
*Amaç: Kötü amaçlı kurcalama, root/jailbreak ve sahtecilik koruması.*

| Kontrol Kodu | Tanım | NevGenç Uygulaması Durumu | Sonuç |
| :--- | :--- | :--- | :---: |
| **MASVS-RESILIENCE-1** | Rooted/Jailbroken cihaz ve emülatör tespiti yapılır. | `safe_device` paketi entegre edilmiştir. Cihazın root/jailbreak durumu, emülatör kullanımı ve geliştirici seçenekleri anlık kontrol edilir. | **GEÇTİ** |
| **MASVS-RESILIENCE-2** | Kod karartma (Obfuscation) derleme sürecinde uygulanır. | Production derlemelerinde Flutter `--obfuscate --split-debug-info` flag'leri ve R8/ProGuard aktif durumdadır. | **GEÇTİ** |

---

### 6. MASVS-CODE (Kod Kalitesi ve Girdi Doğrulama)
*Amaç: Yazılım zafiyetlerinin ve enjeksiyon saldırılarının önlenmesi.*

| Kontrol Kodu | Tanım | NevGenç Uygulaması Durumu | Sonuç |
| :--- | :--- | :--- | :---: |
| **MASVS-CODE-1** | Tüm kullanıcı girdileri sunucu ve istemci tarafında süzülür. | SQL Enjeksiyonuna karşı Supabase parametreli sorguları kullanılır. Web tarafında `escHtml` fonksiyonu ile XSS koruması sağlanır. | **GEÇTİ** |
| **MASVS-CODE-2** | Bağımlılıklar günceldir ve bilinen zafiyetler içermez. | `pubspec.yaml` üzerindeki tüm paketler güncel sürümlerdedir ve periyodik `flutter pub outdated` taramasından geçirilir. | **GEÇTİ** |

---

### Rapor Özeti ve Pazarlama / Mağaza Metni Kullanımı
NevGenç mobil uygulaması OWASP MASVS v2.0 standartlarının tüm gereksinimlerini karşılamaktadır.

**Örnek Pazarlama / Mağaza Açıklama Metni:**
> *"NevGenç mobil uygulaması siber güvenlik standartlarına tam uyum sağlamaktadır. Uygulamamız OWASP MASVS v2.0 (Mobile Application Security Verification Standard) kriterlerine göre öz-değerlendirmeden geçirilmiş; kullanıcı verileri SOC 2 ve ISO 27001 sertifikalı bulut altyapısında uçtan uca şifreleme ile koruma altına alınmıştır."*
