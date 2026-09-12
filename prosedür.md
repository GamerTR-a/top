1-Bu projede istemciye giden koda gömülmüş gizli değerleri bul.

Ara: API anahtarları, servis hesabı anahtarları, veritabanı bağlantı adresleri, özel token'lar, imzalama anahtarları.
Ayrıca NEXT_PUBLIC_ / VITE_/ REACT_APP_ önekli değişkenlerin hangilerinin GERÇEKTEN gizli olması gerektiğini işaretle — bu önekler değeri tarayıcıya açar.

Önce bulduklarını dosya:satır olarak listele, hiçbir şeyi değiştirme.
Sonra her biri için: bu değer sunucuya mı taşınmalı, yoksa gerçekten herkese açık olabilir mi — gerekçesiyle söyle.
Onayımı aldıktan sonra sunucu tarafına taşı ve istemcideki kullanımı sunucu üzerinden geçen bir çağrıyla değiştir.
2-Bu depoda git geçmişine girmiş gizli dosyaları ve değerleri bul.

1. .env, .env.local, credentials.json, serviceAccount.json, *.pem gibi dosyaların geçmişte commit'lenip commit'lenmediğini kontrol et.
2. Geçmişteki commit içeriklerinde anahtar biçimindeki dizeleri ara.
3. Bulduklarını hangi commit'te girdiğiyle birlikte listele.

Sonra bana iki şeyi ayrı ayrı anlat:

- geçmişi temizlemek için çalıştıracağım komutlar (ve bunun depoyu yeniden yazacağı uyarısı)
- hangi anahtarların artık YAKILMIŞ sayılması ve yenilenmesi gerektiği

.gitignore'a eklemenin geçmişi temizlemediğini varsayarak ilerle.
3-Bu projedeki veritabanı erişim kurallarını denetle (Firestore rules, Supabase RLS politikaları, veya kullandığım sistem hangisiyse).

1. Şu an yürürlükte olan kuralları çıkar ve düz Türkçe açıkla: kim neyi okuyabiliyor, kim neyi yazabiliyor?
2. "herkese açık" olan her tabloyu/koleksiyonu işaretle.
3. Uygulamanın veri modeline bakarak her tablo için doğru kuralın ne olması gerektiğini öner: kullanıcı yalnızca kendi kaydına erişsin, yazma alanları sınırlı olsun.

Kuralları yazarken varsayılanı REDDET yap, sonra gereken erişimi tek tek aç.
Değiştirmeden önce önerilen kural setini bana göster.
4-Bu projede yetki kontrolünün yalnızca arayüzde yapıldığı yerleri bul.

Ara: bir butonun/sayfanın role veya sahipliğe göre gizlendiği, ama arkasındaki API ucunun aynı kontrolü YAPMADIĞI durumlar.

Her bulgu için:

- arayüzdeki kontrol nerede (dosya:satır)
- karşılık gelen sunucu ucu nerede
- o uca başka bir kullanıcının kimliğiyle istek atılırsa ne olur

Sonra her uç için sunucu tarafında sahiplik/rol kontrolü ekle: isteği yapan kullanıcı gerçekten bu kaydın sahibi mi veya bu role sahip mi.
Kontrolü tek bir yardımcı fonksiyonda topla, her uçta ayrı ayrı yazma.
5-Bu projede hız sınırı olmayan uçları bul.

Özellikle bak: giriş, kayıt, şifre sıfırlama, doğrulama kodu gönderme, e-posta/SMS tetikleyen her uç, pahalı işlem yapan her uç (yapay zekâ çağrısı, dosya işleme).

Her uç için:

- şu an sınır var mı
- sınırsız bırakılırsa saldırganın ne kazanacağı (hesap ele geçirme mi, fatura mı)

Sonra IP ve hesap bazlı hız sınırı ekle. Giriş için 15 dakikada 5 deneme, kod gönderimi için saatte 3 gibi makul değerlerle başla ve bunları tek bir yapılandırma dosyasında topla.
Sınıra takılan kullanıcıya ne kadar bekleyeceğini söyleyen bir hata mesajı döndür.
6-Bu projede yalnızca istemcide doğrulanan girdileri bul.

Her API ucu için gövde/parametre alanlarını çıkar ve şunu söyle: sunucu bu alanın tipini, uzunluğunu, aralığını doğruluyor mu, yoksa geleni olduğu gibi mi kabul ediyor?

Özellikle işaretle:

- sayı beklenen ama negatif/çok büyük değer kabul eden alanlar
- fiyat, adet, rol, kullanıcı kimliği gibi istemciden gelmemesi gereken alanlar
- sınırsız uzunlukta metin kabul eden alanlar

Sonra her uca sunucu tarafı şema doğrulaması ekle (Zod/Pydantic veya projede zaten ne varsa).
Şemayı uç ile aynı dosyada değil, paylaşılan bir doğrulama katmanında tut.
7-Bu projedeki dosya yükleme akışlarını denetle.

Her yükleme noktası için kontrol et:

- dosya boyutu sınırı var mı (istemcide DEĞİL, sunucuda)
- izin verilen tür listesi var mı ve uzantıya mı yoksa gerçek içerik türüne mi bakıyor
- dosya adı kullanıcıdan geldiği gibi mi kullanılıyor (yol kaçışı riski)
- yüklenen dosyalar uygulamanın çalıştığı yerden mi servis ediliyor

Sonra: sunucu tarafında boyut ve tür sınırı, rastgele üretilen dosya adı, ve yüklenen dosyaların ayrı bir alan adından/kovadan servis edilmesi için gereken değişiklikleri yap.
Önce mevcut durumu raporla.
8-Bu projede CORS yapılandırmasını bul ve denetle.

Söyle:

- şu an hangi kaynaklara izin veriliyor
- kimlik bilgisi (cookie/authorization) taşıyan isteklere izin var mı
- hangi HTTP metodları ve başlıklar açık

Sonra izinli kaynakları yalnızca benim alan adlarımla sınırla (üretim ve geliştirme için ayrı liste), gereksiz metodları kapat.
Wildcard ile kimlik bilgisi taşıyan isteklerin birlikte kullanılamayacağını da not düş.
Değişiklikten sonra hangi isteklerin kırılabileceğini listele.
9-Bu projenin HTTP yanıt başlıklarını denetle.

Şunların var olup olmadığını kontrol et ve eksik olanları ekle:

- Strict-Transport-Security
- Content-Security-Policy
- X-Frame-Options (veya CSP frame-ancestors)
- X-Content-Type-Options: nosniff
- Referrer-Policy
- Permissions-Policy

Content-Security-Policy'yi yazarken önce RAPOR modunda kur, böylece siteyi kırmadan neyi engelleyeceğini görebileyim.
Projede kullandığım üçüncü taraf betikleri (analiz, ödeme, yazı tipi) tarayıp politikaya dahil et — hangilerini eklediğini listele.
10-Bu projede HTTP üzerinden gelen isteklerin ne olduğunu kontrol et.

- HTTP isteği HTTPS'e kalıcı (301) yönlendiriliyor mu
- Strict-Transport-Security başlığı var mı ve süresi ne
- uygulama içinde http:// ile başlayan sabit adresler var mı (API çağrıları, görseller, web soketleri)
- çerezler Secure bayrağıyla mı gönderiliyor

Eksikleri gider: yönlendirmeyi sunucu/barındırma katmanında kur, karışık içerik yaratan http:// adreslerini düzelt.
Değiştirdiğin her adresi listele.
11-Bu projede şifrelerin nasıl saklandığını denetle.

- şifreler hangi alanda ve hangi biçimde tutuluyor
- hash algoritması ne (bcrypt/argon2/scrypt mi, yoksa md5/sha1 veya elle yazılmış bir şey mi)
- salt ve maliyet (cost) ayarı ne

Düz metin veya zayıf algoritma bulursan: geçiş planını anlat — mevcut kullanıcıları bir sonraki girişlerinde yeniden hash'leyerek nasıl taşırım, bu sırada eski hash'leri nasıl geçersiz kılarım.

Ayrıca kimlik doğrulamayı kendim mi yazmışım yoksa hazır bir sağlayıcı mı kullanıyorum, onu da söyle; kendim yazdıysam hazır sağlayıcıya geçmenin maliyetini değerlendir.
12-Bu projedeki oturum yönetimini denetle.

- oturum bilgisi nerede tutuluyor (çerez, localStorage, bellek)
- çerezlerde HttpOnly, Secure, SameSite bayrakları var mı
- token'ın ömrü ne kadar, yenileme mekanizması var mı
- çıkış yapınca oturum sunucu tarafında gerçekten geçersiz kılınıyor mu

localStorage'da token tutuluyorsa bunun neden riskli olduğunu ve HttpOnly çereze taşımanın bu projede neyi değiştireceğini anlat.
Eksik bayrakları ekle ve makul bir oturum ömrü öner.
13-Bu projede kullanıcıya giden hata mesajlarını denetle.

- üretim ortamında yığın izi (stack trace) kullanıcıya gösteriliyor mu
- hata mesajları tablo adı, dosya yolu, sorgu veya yapılandırma değeri sızdırıyor mu
- 500 yanıtlarının gövdesinde ne var
- giriş hatalarında "kullanıcı yok" ile "şifre yanlış" ayrımı yapılıyor mu (yapılıyorsa hesap sayımına açıksın)

Sonra: kullanıcıya sade ve yardımcı bir mesaj, sunucu loguna tam detay gidecek şekilde ayır.
Her hataya bir referans kodu üret ki kullanıcı bana o kodu söyleyebilsin.
14-Bu projede loglara yazılan hassas veriyi bul.

Tara: console.log/logger çağrıları, hata yakalama blokları, istek/yanıt loglayan ara katmanlar, analiz olayları.

İşaretle: token, şifre, doğrulama kodu, kart bilgisi, TC kimlik, telefon, e-posta, adres.

Sonra:

- tüm istek gövdelerini olduğu gibi loglayan yerleri düzelt
- hassas alanları maskeleyen tek bir yardımcı fonksiyon ekle (ilk 4 karakter + …)
- hangi logların ne kadar süre saklandığını da söyle

Önce bulduklarını dosya:satır olarak listele.
15-Bu projede string birleştirmeyle kurulan veritabanı sorgularını bul.

Ara: SQL/NoSQL sorgu metnine değişken eklenen her yer — şablon dizeleri, + ile birleştirme, dinamik kolon/tablo adları, dinamik ORDER BY.

Her bulgu için:

- dosya:satır
- hangi girdi kullanıcıdan geliyor
- örnek bir kötü niyetli girdiyle ne olurdu

Sonra hepsini parametreli sorguya çevir. Kolon/tablo adı gibi parametrelenemeyen yerlerde beyaz liste kullan.
ORM kullanıyorsam ham sorguya düştüğüm yerleri ayrıca işaretle.
16-Bu projede kullanıcı içeriğinin kaçırılmadan sayfaya basıldığı yerleri bul.

Ara: innerHTML, dangerouslySetInnerHTML, v-html, üçüncü taraf markdown/HTML gömme, kullanıcıdan gelen URL'in href/src'ye konması.

Her bulgu için içeriğin nereden geldiğini ve temizlenip temizlenmediğini söyle.

Sonra:

- düz metin yeterliyse textContent'e çevir
- HTML gerçekten gerekiyorsa güvenilir bir temizleyici (DOMPurify vb.) ekle ve izin verilen etiket listesini dar tut
- kullanıcıdan gelen URL'lerde şema kontrolü yap (javascript: engellensin)
17-Bu projedeki webhook uçlarını denetle (ödeme, e-posta, depolama, hangi servis varsa).

Her uç için:

- imza/gizli anahtar doğrulaması yapılıyor mu, yoksa gövdeye olduğu gibi mi güveniliyor
- ham gövde mi imzalanıyor, yoksa ayrıştırılmış JSON üzerinden mi (ayrıştırılmışsa doğrulama bozulur)
- aynı olay iki kez gelirse ne olur (tekrar oynatma koruması var mı)
- zaman damgası kontrolü var mı

Sonra sağlayıcının resmi doğrulama yöntemiyle imza kontrolü ekle, olay kimliğini kaydederek tekrarı engelle.
Doğrulama başarısızsa 400 dön ve olayı işleme.
18-Bu projede yönetici/iç kullanım için olan her yolu ve ucu bul.

Ara: /admin, /dashboard, /debug, /internal, veritabanı arayüzleri, kuyruk panelleri, ölçüm uçları, geliştirme amaçlı bırakılmış test uçları.

Her biri için:

- kimlik doğrulaması var mı
- rol kontrolü SUNUCUDA yapılıyor mu
- üretimde açık kalması gerekiyor mu

Sonra: hepsine sunucu tarafı rol kontrolü ekle, üretimde gereksiz olanları tamamen kapat.
Geliştirme amaçlı bırakılmış her ucu ayrıca listele — bunlar en sık unutulanlar.
19-Bu projenin bağımlılıklarını denetle.

1. Bilinen açığı olan paketleri listele (kritik ve yüksek olanları ayır).
2. Kilit dosyası (lock file) var mı, sürümler sabitlenmiş mi?
3. Bağımlılıklardan hangileri gerçekten kullanılıyor — kullanılmayanları listele.
4. Paket adlarını tek tek kontrol et: gerçekten var olan, bakımlı, indirilme sayısı makul paketler mi? Ad benzerliğiyle taklit edilmiş olabilecekleri işaretle.

Sonra güvenli güncelleme planı çıkar: önce kırıcı olmayan yükseltmeler, sonra büyük sürüm atlamaları ayrı ayrı.
Hepsini birden güncelleme.
20-Bu projenin veri dayanıklılığını denetle.

- otomatik yedekleme açık mı, hangi sıklıkta, ne kadar geriye gidiyor
- yedekler veritabanıyla aynı hesapta/bölgede mi duruyor
- yüklenen dosyalar da yedekleniyor mu
- geri yükleme daha önce denenmiş mi

Sonra:

- yedeklemeyi kur veya eksik kalan tarafını tamamla
- geri yüklemeyi adım adım nasıl test edeceğimi yaz (üretime dokunmadan)
- yanlışlıkla silmeye karşı ne kadar koruma olduğunu söyle

Ayrıca yıkıcı komutların (drop, truncate, toplu silme) kod tabanında nerede geçtiğini listele.
21-Bu projede hesap ve veri silme akışını denetle.

- kullanıcı hesabını silebiliyor mu, nasıl
- silme işlemi veriyi gerçekten siliyor mu, yoksa yalnızca işaretliyor mu
- kullanıcıya ait veri kaç ayrı yerde duruyor (veritabanı, dosya depolama, e-posta listesi, analiz, üçüncü taraf servisler, loglar, yedekler)
- silinen kullanıcının kimliği başka kayıtlarda kalıyor mu

Sonra eksiksiz bir silme akışı öner: kullanıcıya makul bir geri alma süresi (örneğin 30 gün), sonra tüm sistemlerden kalıcı silme.
Silinemeyecek olanları (yasal saklama, yedekler) ayrıca listele — bunlar gizlilik metnimde yazmalı.
22-Bu projenin maliyet risklerini çıkar.

1. Kullanıma göre ücretlenen her servisi listele (bulut işlevleri, veritabanı okuma/yazma, depolama, yapay zekâ çağrıları, SMS/e-posta, bant genişliği).
2. Her biri için: kötü niyetli veya hatalı bir döngü bu kalemi ne kadar şişirebilir?
3. Kod tabanında sınırsız döngüye girebilecek yerleri bul (yeniden deneme mantığı, kuyruk işleyicileri, kendini tetikleyen işlevler).

Sonra:

- bütçe uyarısı kurmam için adımları yaz (%50, %90, %100)
- yapay zekâ ve SMS gibi pahalı çağrılara kullanıcı başına günlük tavan ekle
- tavana çarpınca ne olacağını (sıraya al / reddet) sen öner
23-Şimdi saldırgan rolüne geç ve bu uygulamayı kırmayı dene.

İki kullanıcı hesabım olduğunu varsay: A ve B.

Sırayla dene ve her biri için sonucu yaz:

1. A olarak giriş yap, B'nin kayıtlarına kimliği değiştirerek eriş
2. Giriş yapmadan korumalı uçlara istek at
3. Fiyat, adet, rol gibi alanları istemciden değiştirerek gönder
4. Başkasının kimliğiyle üretilmiş bir token'ı kullan
5. Yönetici uçlarına normal kullanıcı olarak eriş
6. Aynı isteği çok hızlı tekrarla
7. Beklenmedik tür ve boyutta veri gönder

Her deneme için: hangi uç, ne gönderdim, ne döndü, bu bir açık mı.
Açık bulduklarını risk sırasına koy. Bulamadıklarını da yaz — neyi denediğini bilmem gerekiyor.
özetle;Bu projede yayına çıkmadan önceki güvenlik denetimini yapmanı istiyorum.

Aşağıdaki 23 başlığın HER BİRİ için kod tabanını tara ve bana tek bir rapor ver.
Bu adımda HİÇBİR DOSYAYI DEĞİŞTİRME — sadece bul ve raporla.

1. İstemciye giden kodda duran API anahtarı, token, gizli değer
2. Git geçmişine girmiş .env veya kimlik bilgisi dosyası
3. Veritabanı erişim kuralları (herkese açık okuma/yazma)
4. Yetki kontrolünün yalnızca arayüzde yapıldığı yerler
5. Giriş ve şifre sıfırlama uçlarında hız sınırı olmaması
6. Yalnızca istemcide doğrulanan, sunucuda doğrulanmayan girdiler
7. Dosya yüklemede tür ve boyut sınırı olmaması
8. CORS'un tüm kaynaklara açık bırakılması
9. Eksik güvenlik başlıkları (HSTS, CSP, X-Frame-Options, X-Content-Type-Options)
10. HTTP'nin HTTPS'e yönlendirilmemesi
11. Düz metin veya zayıf algoritmayla saklanan şifreler
12. Oturum çerezlerinde HttpOnly / Secure / SameSite eksikliği
13. Kullanıcıya iç detay sızdıran hata mesajları
14. Loglara yazılan token, şifre, kişisel veri
15. String birleştirmeyle kurulan veritabanı sorguları
16. Kullanıcı içeriğinin kaçırılmadan HTML'e basıldığı yerler
17. İmzası doğrulanmayan webhook uçları
18. Sunucu tarafında rol kontrolü olmayan yönetici uçları
19. Bilinen açığı olan veya sabitlenmemiş bağımlılıklar
20. Yedekleme ve geri yükleme yapılandırmasının olmaması
21. Hesap silmenin veriyi gerçekten silmemesi
22. Harcama/kota sınırı ve uyarısı olmaması
23. Yetkisiz erişimle denenmemiş uçlar

Rapor formatı — her bulgu için:

- başlık numarası
- dosya:satır
- neyin yanlış olduğu (tek cümle)
- risk: kritik / yüksek / orta
- önerilen düzeltme (tek cümle)

Raporun sonunda hangi başlıkların TEMİZ çıktığını da yaz.
Emin olmadığın yerde "emin değilim" yaz, tahmin etme.
