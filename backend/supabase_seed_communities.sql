-- ============================================================================
-- NevGenç — Topluluk Seed Scripti (yeni Supabase projesi için)
-- ----------------------------------------------------------------------------
-- Supabase Dashboard → SQL Editor'a yapıştırıp RUN çalıştırın.
-- Kaynak: assets/data/newgenc_data.json (32 gerçek SAÜ topluluğu + gerçek logolar)
--   logo_path   → uygulamanın AppNetworkImage'i hem 'assets/...' hem https URL kabul eder
--   score       → liderlik tablosu 0-100 ölçeğinde (JSON puanı ×20: 4.8→96.0)
--   chairman_name → şimdilik JSON'daki görüntü adı; başkan hesabı kaydolunca
--                 aşağıdaki UPDATE ile gerçek başkanla değiştirilir.
-- ============================================================================

TRUNCATE communities RESTART IDENTITY CASCADE;

INSERT INTO public.communities
  (name, logo_path, category, score, member_count, description, chairman_name)
VALUES
  ('21 Gün 37 Derece',      'assets/21gun_37derece.png', 'Sosyal Sorumluluk',          96.0, 150, 'Yeni bir alışkanlık kazanmak için sadece 21 güne ihtiyacın var. Sınırlarını aş!',                    'Ahmet Yılmaz'),
  ('Altay Topluluğu',        'assets/altay.png',          'Kültür',                    90.0, 120, 'Köklerini tanı, geleceğini inşa et! Tarihine sahip çıkıp kültürel mirasını yaşatmaya hazır mısın?', 'Metehan Bayraktar'),
  ('Atom Topluluğu',         'assets/atom.png',           'Bilim ve Teknoloji',        98.0, 210, 'Atomu parçalamıyoruz, ama projelerimizle dünyayı sarsıyoruz! Sınırların ötesini düşün.',              'Zeynep Erdem'),
  ('Avrupa Birliği',         'assets/avrupa_birligi.png', 'Uluslararası İlişkiler',    84.0, 85,  'Sınırları kaldır, dünyaya açıl! Küresel projelerde yer alıp vizyonunu genişlet.',                    'Caner Demir'),
  ('Avrupa Türk',            'assets/avrupa_t.jpg',       'Uluslararası İlişkiler',    80.0, 60,  'Mesafeleri kapatıyoruz! Kültürel köprüler kurarak gücümüzü tüm dünyaya taşıyalım.',                 'Elif Turan'),
  ('Beton Kano',             'assets/beton_kano.png',     'Mühendislik',               94.0, 180, 'İmkansız diye bir şey yoktur! Betonu bile yüzdürebiliyorsan, her şeyi başarabilirsin.',             'Burak Çelik'),
  ('Biandora',               'assets/biandora.jpg',       'Teknoloji',                 88.0, 95,  'Girişimci ruhunu serbest bırak! Parlak fikirlerini yenilikçi çözümlere dönüştürme vakti.',          'Selim Aras'),
  ('Bilgisayar',             'assets/bilgisayar.png',     'Bilişim',                   100.0, 350, 'Kod satırlarıyla geleceği inşa et! Teknolojinin mutfağında ustalaşıp dünyaya yön ver.',             'Abdurrahman Genç'),
  ('Blockchain',             'assets/blokchain.png',      'Teknoloji',                 96.0, 220, 'Merkeziyetsiz bir devrime var mısın? Web3 dünyasının inşasında senin de imzan olsun.',               'Emre Can'),
  ('BSMT',                   'assets/bsmt.png',           'Bilim ve Teknoloji',        86.0, 110, 'Merak et, sorgula, keşfet! Bilimin ışığında sınırları zorlayan araştırmalar yap.',                  'Derya Deniz'),
  ('Euro Youth',             'assets/euro_youth.jpg',     'Uluslararası İlişkiler',    82.0, 75,  'Avrupa''yı keşfet, gönüllü ol! Farklı kültürlerle etkileşime girerek kendini geliştir.',             'Onur Saylan'),
  ('IHH',                    'assets/ihh.png',            'İnsani Yardım',             92.0, 280, 'İyilik bulaşıcıdır! Dünyanın herhangi bir yerindeki bir gülümsemenin sebebi sen ol.',               'Fatih Sultan'),
  ('İklim Değişikliği',      'assets/iklim_degisikligi.jpg', 'Çevre',                  90.0, 130, 'Dünyamızın sana ihtiyacı var! Sürdürülebilir ve yeşil bir gelecek için harekete geç.',              'Gülşah Yeşil'),
  ('Lifemesh',               'assets/lifemesh.jpg',       'Teknoloji',                 84.0, 80,  'Yaşam ve teknolojiyi harmanla! Biyoteknolojik çözümlerle geleceğin dünyasında fark yarat.',         'Hakan Bal'),
  ('Makine Müh.',            'assets/makine_muhendisligi.jpg', 'Mühendislik',          94.0, 260, 'Geleceğin mekanizmasını sen üret! Hayalindeki sistemleri çelik ve teknolojiyle gerçeğe dönüştür.',  'İbrahim Öz'),
  ('MİLTEG',                 'assets/milteg.png',          'Kültür',                   88.0, 140, 'Milli Teknoloji hamlesine katıl! Gençliğin enerjisiyle değer üreten büyük bir takımın parçası ol.',  'Kemal Ak'),
  ('MÜDEF',                  'assets/mudef.jpg',           'Sosyal Sorumluluk',        86.0, 105, 'Dayanışma yaşatır! Eğitime ve yardımlaşmaya destek olarak yarınlara umut taşıyalım.',               'Leyla Mecnun'),
  ('Oyun Geliştirme',        'assets/oyun_gelistirme.jpg', 'Teknoloji',                98.0, 310, 'Sadece oynama, kendi dünyanı sen tasarla! Sanal evrenlerin hükümdarı olmak için ekibe katıl.',      'Murat Oyun'),
  ('SAero Tech',             'assets/saero_tech.png',      'Havacılık ve Teknoloji',   96.0, 190, 'Gözünü gökyüzüne dik! İHA''lar ve roketlerle havacılık tarihine kendi imzanı at.',                   'Nihat Gök'),
  ('Sanat Tarihi',           'assets/sanat_tarihi.png',    'Sanat',                    82.0, 70,  'Geçmişin estetiğini keşfet! Tarihin tozlu sayfalarındaki sanatı günümüze taşımaya var mısın?',      'Oya Çizgi'),
  ('SAÜ Siber',              'assets/sau_siber.png',       'Bilişim',                  100.0, 420, 'Görünmez ordunun komutanı ol! Siber fırtınalarda beyaz şapkanla sistemleri sen savun.',             'Ömer Faruk'),
  ('SAÜ İHA',                'assets/sauiha.png',          'Havacılık ve Teknoloji',   98.0, 250, 'Otonom gökyüzü ustaları burada! Tasarla, kodla ve şampiyonluk için motoru ateşle.',                 'Pınar Bulut'),
  ('SAURO',                  'assets/sauro.jpg',           'Mühendislik',              92.0, 175, 'Robotik devrimini yakala! Mekatroniğin zirvesinde geleceğin zeki mekanizmalarını tasarla.',         'Ramazan Robot'),
  ('SEIS',                   'assets/seis.png',            'Mühendislik',              90.0, 160, 'Profesyoneller kulübüne hoş geldin! Liderlik vizyonu edinerek sektörün aranan mühendisi ol.',      'Selin Sahne'),
  ('SETT',                   'assets/sett.jpg',            'Teknoloji',                88.0, 135, 'Yazılım dünyasına meydan oku! Takım arkadaşlarınla gerçek projeler geliştirerek zirveye tırman.',  'Tarık Yaz'),
  ('Sky Ray',                'assets/sky_ray.jpg',         'Havacılık ve Teknoloji',   94.0, 185, 'Yıldızlara göz kırp! Havacılık tutkusunu uzayın sınırlarına kadar ulaştırmak için uçuşa geç.',      'Uğur Işık'),
  ('Suffe Hadis',            'assets/suffe_hadis.png',     'Dini İlimler',             84.0, 120, 'Gönülleri aydınlat! İslami ilimlerin derinliğine yolculuk ederek hakikatin ışığında yürü.',         'Veli Can'),
  ('Tarih',                  'assets/tarih.png',           'Sosyal Bilimler',          86.0, 145, 'Geçmişin sırları seni bekliyor! Arşivlerin tozlu ama efsanevi dünyasında hakikati keşfet.',         'Yaman Tarih'),
  ('TOG',                    'assets/tog.png',             'Sosyal Sorumluluk',        96.0, 290, 'Dünyayı gençlik ve iyilik değiştirecek! Gönül ver, projeler üret, kalplere dokun.',                 'Zehra Kalp'),
  ('ULİT',                   'assets/ulit.png',            'Uluslararası İlişkiler',   90.0, 165, 'Diplomasi sanatında ustalaş! Küresel politikaları yönlendiren lider oyunculardan biri sen ol.',     'Alparslan Sencer'),
  ('Veri Bilimi',            'assets/veri_bilimi.png',     'Bilişim',                  98.0, 340, 'Veri yığınlarını değerli birer elmasa çevir! Analizin gücüyle geleceği baştan kurgula.',            'Buse Data'),
  ('Yapay Zeka',             'assets/yapay_zeka.png',      'Bilişim',                  100.0, 480, 'Makinelere öğrettiğin şeyler insanlığın kaderini belirleyecek. Yapay zeka devrimine liderlik et!',  'Cihan Akıl');

-- ============================================================================
-- BAŞKAN HESAPLARI (uygulamadan kaydolduktan SONRA çalıştır)
-- ----------------------------------------------------------------------------
-- Her başkan uygulamadan kayıt olduktan sonra email adresine göre rolünü
-- 'baskan' yap ve topluluğuna bağla. Örnek (e-postaları gerçekleriyle değiştir):
-- ============================================================================
-- UPDATE profiles SET role = 'baskan'
--   WHERE email IN ('baskan1@ornek.com','baskan2@ornek.com');
--
-- UPDATE communities c SET chairman_id = p.id
--   FROM profiles p
--   WHERE p.email = 'baskan1@ornek.com' AND c.name = 'Yapay Zeka';
--
-- UPDATE communities c SET chairman_id = p.id, chairman_name = p.name
--   FROM profiles p
--   WHERE p.email = 'baskan2@ornek.com' AND c.name = 'SAÜ Siber';

-- Doğrulama:
--   SELECT id, name, logo_path, score, member_count FROM communities ORDER BY score DESC;
