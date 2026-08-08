const MAP_DATA = {
  categories: {
    dorms: {
      id: "dorms",
      name: "Devlet Yurtları (KYK)",
      icon: "hotel",
      color: "#f39c12" // Altın Sarısı
    },
    study: {
      id: "study",
      name: "Çalışma Alanları & Kafeler",
      icon: "graduation-cap",
      color: "#e74c3c" // Kırmızı
    },
    routes: {
      id: "routes",
      name: "Yürüyüş ve Bisiklet Rotaları",
      icon: "bicycle",
      color: "#2ecc71" // Yeşil
    },
    transport: {
      id: "transport",
      name: "Ulaşım Hatları & Duraklar",
      icon: "bus",
      color: "#3498db" // Mavi
    },
    wifi: {
      id: "wifi",
      name: "Ücretsiz Wi-Fi Noktaları",
      icon: "wifi",
      color: "#9b59b6" // Mor
    }
  },
  
  // --- KONUMLAR (POIs) ---
  locations: [
    // --- DEVLET ÖĞRENCİ YURTLARI (KYK) ---
    {
      id: "dorms_sabahattin_zaim",
      category: "dorms",
      name: "Sabahattin Zaim Erkek Öğrenci Yurdu (KYK)",
      coords: [40.7445, 30.3420],
      address: "Esentepe Mah. Akademiyolu Sok. No:5, Serdivan/Sakarya",
      details: "Esentepe sırtlarında, kampüs doğu girişine en yakın konumdaki büyük devlet erkek yurdu. Kampüse ulaşım genellikle yürüyerek veya KYK ring servisleriyle sağlanır.",
      features: ["Kampüse Çok Yakın", "Erkek Yurdu", "Spor Sahaları", "Kütüphane & Etüt Odası"],
      hours: "Giriş: 23:00 (KYK Standartı)"
    },
    {
      id: "dorms_rahime_sultan",
      category: "dorms",
      name: "Rahime Sultan Kız Öğrenci Yurdu (KYK)",
      coords: [40.7510, 30.3450],
      address: "Kemalpaşa Mah. Üniversite Cad. No:86, Serdivan/Sakarya",
      details: "Üniversite Caddesi (yokuş) üzerinde yer alan, binlerce kız öğrenciye ev sahipliği yapan ana yurt yerleşkesi. Kampüse giden tüm otobüs ve dolmuşlar hemen önündeki duraktan geçer.",
      features: ["Üniversite Caddesi Üzerinde", "Kız Yurdu", "Geniş Yemekhane", "Etüt ve Sosyal Alanlar"],
      hours: "Giriş: 23:00 (KYK Standartı)"
    },
    {
      id: "dorms_serdivan_erkek",
      category: "dorms",
      name: "Serdivan Erkek Öğrenci Yurdu (KYK)",
      coords: [40.7515, 30.3455],
      address: "Kemalpaşa Mah. Üniversite Cad. No:84/1, Serdivan/Sakarya",
      details: "Üniversite Caddesi üzerinde, Rahime Sultan Yurdu'nun hemen çaprazında yer alan erkek yurdu. Ulaşım aksının merkezindedir.",
      features: ["Ana Cadde Üzerinde", "Erkek Yurdu", "Sosyal Tesisler", "Etüt Odaları"],
      hours: "Giriş: 23:00 (KYK Standartı)"
    },
    {
      id: "dorms_sakarya_kiz",
      category: "dorms",
      name: "Sakarya Kız Öğrenci Yurdu (KYK)",
      coords: [40.7570, 30.3540],
      address: "Kemalpaşa Mah. Üniversite Cad. 185. Sk. No:3, Serdivan/Sakarya",
      details: "Üniversite Caddesi'nin alt kısımlarında, Mavi Durak sosyal alanlarına ve kafelere en yakın konumdaki kız öğrenci yurdu. Hem kampüse hem de sosyal hayata erişimi çok rahattır.",
      features: ["Mavi Durak Yakını", "Kız Yurdu", "Çamaşırhane", "Geniş Dinlenme Bahçesi"],
      hours: "Giriş: 23:00 (KYK Standartı)"
    },
    {
      id: "dorms_arif_nihat",
      category: "dorms",
      name: "Arif Nihat Asya Kız Öğrenci Yurdu (KYK)",
      coords: [40.7540, 30.3415],
      address: "Kemalpaşa Mah. 4. Cadde No:1, Serdivan/Sakarya",
      details: "Üniversite Caddesi'nin bir paralel caddesinde, sakin bir mahalle dokusu içerisinde yer alan kız öğrenci yurdu. Üniversite caddesindeki duraklara kısa bir yürüyüş mesafesindedir.",
      features: ["Sakin Konum", "Kız Yurdu", "Çalışma Salonu", "Kantin & Kafeterya"],
      hours: "Giriş: 23:00 (KYK Standartı)"
    },

    // --- KORİDOR ULAŞIM DURAKLARI ---
    {
      id: "transport_stop_zaim",
      category: "transport",
      name: "Sabahattin Zaim Yurt Durağı",
      coords: [40.7446, 30.3418],
      address: "Esentepe Mah. Akademiyolu Sok. (Yurt Önü)",
      details: "Sabahattin Zaim Yurdu çıkışındaki durak noktası. Buradan kampüs merkezine ve kütüphaneye giden ücretsiz ring araçları ve dolmuşlar geçer.",
      features: ["Sabahattin Zaim Yurt Önü", "KYK Kampüs Ringi", "Dolmuş Geçiş Noktası"],
      hours: "Ring: Sınav haftaları yoğunlaştırılmış"
    },
    {
      id: "transport_stop_rahime",
      category: "transport",
      name: "Rahime Sultan & Serdivan Yurt Durağı",
      coords: [40.7512, 30.3452],
      address: "Kemalpaşa Mah. Üniversite Cad. (Yurtlar Önü)",
      details: "Üniversite caddesi yokuşunun ortasında, iki yurdun ortak kullandığı en yoğun öğrenci durağı. Tüm kampüs otobüsleri ve dolmuşları durur.",
      features: ["Yurtların Hemen Önü", "Belediye Otobüsleri (16K, 20A, 28B)", "Mavi Durak Dolmuşları"],
      hours: "06:30 - 23:30"
    },
    {
      id: "transport_stop_sakarya_kiz",
      category: "transport",
      name: "Sakarya Kız Yurt Durağı",
      coords: [40.7572, 30.3538],
      address: "Kemalpaşa Mah. Üniversite Cad. 185. Sk. Kesişimi",
      details: "Sakarya Kız Yurdu'na giden ara sokak girişindeki Üniversite Caddesi durağı. Hem kampüse çıkışta hem de şehre inişte kullanılır.",
      features: ["Sakarya Kız Yurdu Yolu", "16K ve Kampüs Doluşları", "Yoğun Öğrenci Aksı"],
      hours: "06:30 - 23:30"
    },
    {
      id: "transport_stop_arif_nihat",
      category: "transport",
      name: "Arif Nihat Asya Yurt Durağı",
      coords: [40.7540, 30.3410],
      address: "Kemalpaşa Mah. 4. Cadde (Yurt Önü)",
      details: "Arif Nihat Asya yurdu önündeki durak. Öğrenciler genellikle buradan ringlere biner veya Üniversite caddesine yürüyerek ana durakları kullanır.",
      features: ["Arif Nihat Asya Yurt Önü", "Mahalle İçi Ring Hattı"],
      hours: "Sefer saatlerine göre"
    },
    {
      id: "transport_stop_nizamiye",
      category: "transport",
      name: "SAÜ Nizamiye Kampüs Giriş Durağı",
      coords: [40.7441, 30.3370],
      address: "Kemalpaşa Mah. Üniversite Yolu (Kampüs Giriş Kapısı)",
      details: "Sakarya Üniversitesi Esentepe Kampüsü giriş kontrol noktası. Ulaşım hatlarının kampüse giriş yaptığı ilk karşılama durağıdır.",
      features: ["Güvenlik Girişi", "Taksi Entegrasyonu", "Ring Aktarma Noktası"],
      hours: "7/24 Aktif"
    },
    {
      id: "transport_stop_sau_lib",
      category: "transport",
      name: "SAÜ Merkez Kütüphane / Ring İstasyonu",
      coords: [40.7418, 30.3342],
      address: "Esentepe Kampüsü Kütüphane Önü, Serdivan/Sakarya",
      details: "Yurtlardan gelen tüm otobüs ve dolmuşların son varış noktası. Kampüs içi ringlerin de ana düğüm noktasıdır.",
      features: ["Ana Varış Noktası", "Dijital Saat Paneli", "Merkez Kütüphane Yanı"],
      hours: "07:00 - 00:00"
    },
    {
      id: "transport_sakbis_mavi",
      category: "transport",
      name: "SAKBİS - Mavi Durak Bisiklet İstasyonu",
      coords: [40.7654, 30.3667],
      address: "Mavi Durak Meydanı, Serdivan/Sakarya",
      details: "Yurtlar bölgesinin hemen aşağısında yer alan akıllı bisiklet kiralama noktası. Buradan bisiklet alıp kampüs bisiklet yolundan yukarı çıkabilirsiniz.",
      features: ["Kart54 / Kredi Kartı", "12 Bisiklet Kapasitesi", "Bisiklet Yolu Başlangıcı"],
      hours: "24 Saat Hizmet"
    },
    {
      id: "transport_sakbis_campus",
      category: "transport",
      name: "SAKBİS - SAÜ Kampüs Bisiklet İstasyonu",
      coords: [40.7415, 30.3338],
      address: "Esentepe Kampüsü Kafeterya Yanı, Serdivan/Sakarya",
      details: "Kütüphane ve yemekhane yanındaki akıllı bisiklet istasyonu. Yurtlardan bisikletle gelen öğrencilerin teslim noktasıdır.",
      features: ["Yemekhane Yanı", "15 Bisiklet Kapasitesi", "Kampüs İçi Teslim Noktası"],
      hours: "24 Saat Hizmet"
    },

    // --- DERS ÇALIŞMA ALANLARI / KAFELER ---
    {
      id: "study_sau_lib",
      category: "study",
      name: "SAÜ Merkez Kütüphanesi",
      coords: [40.7418, 30.3342],
      address: "Sakarya Üniversitesi Esentepe Kampüsü, Serdivan/Sakarya",
      details: "Yurtlarda kalan öğrencilerin en çok kullandığı ana çalışma alanı. A Blok 7/24 kesintisiz hizmet vermektedir.",
      features: ["7/24 Açık", "Sessiz Çalışma Salonları", "Zengin Kaynak Arşivi", "Priz & Şarj"],
      hours: "7/24 (A Blok)"
    },
    {
      id: "study_the_council",
      category: "study",
      name: "The Council Coffee Co.",
      coords: [40.7650, 30.3630],
      address: "İstiklal Mah. Üniversite Cad. No:31, Serdivan/Sakarya",
      details: "Üniversite Caddesi başlangıcında, Sakarya Kız Yurdu'na çok yakın konumda. Ders çalışmaya uygun büyük masaları ve prizleri bulunur.",
      features: ["Geniş Masalar", "Priz İstasyonları", "Laptop Çalışma Odaklı", "Hızlı Wi-Fi"],
      hours: "08:30 - 01:30"
    },
    {
      id: "study_coffee_study",
      category: "study",
      name: "Coffee & Study",
      coords: [40.7662, 30.3655],
      address: "İstiklal Mah. Çark Cad. No:292 (Mavi Durak)",
      details: "Mavi Durak meydanına ve Sakarya Kız Yurdu'na yürüme mesafesinde, tamamen ders çalışma odaklı, sessiz salonları olan kafe.",
      features: ["Gece 02:00'ye kadar açık", "Sessiz Odalar", "Hızlı İnternet", "Rahat Sandalyeler"],
      hours: "08:00 - 02:00"
    },
    {
      id: "study_anka_coffee",
      category: "study",
      name: "Study Anka Coffee",
      coords: [40.7635, 30.3670],
      address: "İstiklal Mah. Bağlar Cad. No:63, Serdivan/Sakarya",
      details: "Yurtlar bölgesinin alt çıkışında yer alan sessiz ders çalışma kafesi. Bireysel çalışma locaları ile yüksek odaklanma sağlar.",
      features: ["Bireysel Localar", "Yüksek Odaklanma", "Priz İmkanı", "Sessiz Ortam"],
      hours: "08:30 - 01:00"
    },
    {
      id: "study_ideas_academy",
      category: "study",
      name: "Serdivan Fikir ve Sanat Akademisi",
      coords: [40.7610, 30.3700],
      address: "Bahçelievler Mah. Muhsin Yazıcıoğlu Blv. No:41",
      details: "Yazlık ve Bahçelievler yurtlarından gelen öğrencilerin tercih ettiği, belediyeye bağlı son derece prestijli ve sessiz kütüphane.",
      features: ["Sakin Çalışma Alanı", "Akademik Kaynaklar", "Rezervasyonlu Giriş"],
      hours: "09:00 - 18:00 (Pazar kapalı)"
    },

    // --- WI-FI NOKTALARI ---
    {
      id: "wifi_sau_campus",
      category: "wifi",
      name: "SAÜ Kampüs Wi-Fi (Eduroam & Kampus_Misafir)",
      coords: [40.7410, 30.3340],
      address: "Sakarya Üniversitesi Esentepe Kampüsü, Serdivan/Sakarya",
      details: "Tüm üniversite alanı, kütüphane ve fakültelerde aktif olan, KYK yurtlarından kampüse gelen öğrencilerin doğrudan bağlandığı internet ağı.",
      features: ["Eduroam (Öğrenci Girişli)", "Kampus_Misafir (SMS Doğrulama)", "Yüksek Bant Genişliği"],
      hours: "24 Saat Aktif"
    },
    {
      id: "wifi_belediye_caybahcesi",
      category: "wifi",
      name: "Wi-Free - Serdivan Aile Çay Bahçesi",
      coords: [40.7675, 30.3685],
      address: "İstiklal Mah. Çark Cad. (Mavi Durak Civarı)",
      details: "Sakarya Kız Yurdu öğrencilerinin ve bölgedeki öğrencilerin sıkça kullandığı belediyeye ait ücretsiz internet alanı.",
      features: ["SMS Doğrulama", "Belediye Wi-Free", "Açık Hava Erişimi"],
      hours: "08:30 - 23:30"
    },
    {
      id: "wifi_belediye_akademi",
      category: "wifi",
      name: "Wi-Free - Serdivan Fikir Sanat Akademisi",
      coords: [40.7608, 30.3698],
      address: "Bahçelievler Mah. Muhsin Yazıcıoğlu Blv.",
      details: "Akademi binasında çalışma yapan öğrencilere sunulan ücretsiz yüksek hızlı internet erişim noktası.",
      features: ["Hızlı Bağlantı", "Öğrenci Kullanımına Açık", "Belediye Ağı"],
      hours: "Akademi Açık Saatlerde"
    }
  ],

  // --- TRANSIT VE REKREASYONEL ROTALAR ---
  routesData: [
    // --- YURT - KAMPÜS TRANSIT HATLARI ---
    {
      id: "route_transit_corridor",
      category: "transport",
      name: "Üniversite Caddesi Ana Yurt-Kampüs Transit Güzergahı",
      color: "#3498db", // Mavi
      path: [
        [40.7570, 30.3540], // Sakarya Kız Yurdu yakını
        [40.7555, 30.3510], 
        [40.7512, 30.3452], // Rahime Sultan / Serdivan Yurt önü
        [40.7485, 30.3425],
        [40.7441, 30.3370], // Kampüs Nizamiye Girişi
        [40.7418, 30.3342]  // SAÜ Merkez Kütüphane
      ],
      details: "Rahime Sultan, Serdivan Erkek, Sakarya Kız ve Arif Nihat Asya yurtlarında kalan öğrencilerin kampüse ulaşımda kullandığı ana karayolu transit koridorudur. Hat 16K, 20A, 28B otobüsleri ve Mavi Durak-Kampüs dolmuşları bu güzergahı kullanır.",
      length: "Yaklaşık 2.6 km",
      difficulty: "Ulaşım Güzergahı",
      type: "Belediye Otobüsü & Dolmuş Hattı",
      linkedDorms: ["dorms_rahime_sultan", "dorms_serdivan_erkek", "dorms_sakarya_kiz", "dorms_arif_nihat"],
      intervals: "Hafta içi yoğun saatlerde (07:30 - 09:30 / 16:30 - 18:30) her 8-10 dakikada bir, diğer saatlerde 15-20 dakikada bir kalkar.",
      sakusUrls: [
        { name: "16K Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/16K" },
        { name: "20A Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/20A" },
        { name: "28B Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/28B" }
      ]
    },
    {
      id: "route_zaim_corridor",
      category: "transport",
      name: "Sabahattin Zaim Yurt-Kampüs Bağlantı Yolu",
      color: "#e67e22", // Turuncu (Alternatif Transit)
      path: [
        [40.7445, 30.3420], // Sabahattin Zaim Yurdu
        [40.7446, 30.3418], // Zaim Durağı
        [40.7443, 30.3375], // Doğu Kampüs Giriş Alanı
        [40.7418, 30.3342]  // SAÜ Merkez Kütüphane / Ring kalkış noktası
      ],
      details: "Sabahattin Zaim Erkek Yurdu'nda kalan öğrencilerin kampüs içine (özellikle Merkez Kütüphane ve Yemekhane) doğrudan geçiş yaptığı kısa yaya ve ring güzergahıdır.",
      length: "Yaklaşık 850 metre",
      difficulty: "Kolay / Kısa Mesafe",
      type: "Yaya & KYK Ring Hattı",
      linkedDorms: ["dorms_sabahattin_zaim"],
      intervals: "Hafta içi ders başlangıç saatlerinde (08:30 - 10:30) her 10 dakikada bir yurdun önünden kütüphaneye ring servis kalkar."
    },
    {
      id: "route_arif_nihat_link",
      category: "transport",
      name: "Arif Nihat Asya Yurt-Kampüs Bağlantı Hattı",
      color: "#9b59b6", // Mor (Transit Bağlantı)
      path: [
        [40.7540, 30.3415], // Arif Nihat Asya Yurdu
        [40.7540, 30.3410], // Arif Nihat Asya Durağı
        [40.7512, 30.3452], // Üniversite caddesi bağlantı (Rahime Sultan Önü)
        [40.7485, 30.3425],
        [40.7441, 30.3370], // Kampüs Nizamiye
        [40.7418, 30.3342]  // SAÜ Kütüphane
      ],
      details: "Arif Nihat Asya Kız Yurdu'ndan başlayıp 4. Cadde üzerinden ana Üniversite Yolu transit koridoruna bağlanan otobüs ve ring güzergahıdır.",
      length: "Yaklaşık 2.1 km",
      difficulty: "Ulaşım Hattı",
      type: "Belediye Otobüsü & Öğrenci Servisi",
      linkedDorms: ["dorms_arif_nihat"],
      intervals: "Hafta içi her yarım saatte bir (07:30 - 22:30 arası) yurt önünden kampüse otobüs kalkar.",
      sakusUrls: [
        { name: "16K Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/16K" },
        { name: "28B Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/28B" }
      ]
    },
    {
      id: "route_29",
      category: "transport",
      name: "Hat 29: Adapazarı Merkez - Mavi Durak - Kampüs",
      color: "#9b59b6",
      path: [
        [40.7760, 30.4010],
        [40.7725, 30.3850],
        [40.7656, 30.3664],
        [40.7512, 30.3452],
        [40.7441, 30.3370],
        [40.7418, 30.3342]
      ],
      details: "Adapazarı Demokrasi Meydanı (Merkez) ile SAÜ Esentepe Kampüsü arasında çalışan, Serdivan Mavi Durak ve Üniversite caddesi yurt duraklarından geçen, öğrencilerin en yoğun kullandığı ana hattır.",
      length: "Yaklaşık 7.2 km",
      difficulty: "Çok Yoğun / Sık Seferler",
      type: "Belediye Otobüs Hattı",
      linkedDorms: ["dorms_rahime_sultan", "dorms_serdivan_erkek", "dorms_sakarya_kiz", "dorms_arif_nihat"],
      intervals: "Günün her saati son derece yoğundur. Hafta içi 07:00 - 23:00 arası her 5-7 dakikada bir, gece ise 30 dakikada bir sefer düzenlenir.",
      sakusUrls: [
        { name: "29 Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/29" }
      ]
    },
    {
      id: "route_15",
      category: "transport",
      name: "Hat 15: Erenler - Çarşı - Serdivan - Kampüs",
      color: "#16a085",
      path: [
        [40.7595, 30.3955],
        [40.7635, 30.3802],
        [40.7656, 30.3664],
        [40.7512, 30.3452],
        [40.7441, 30.3370],
        [40.7418, 30.3342]
      ],
      details: "Erenler ilçesinden kalkıp şehir merkezi (Çarşı) ve Serdivan üzerinden kampüse ulaşan, yurtlar koridorunu kullanan bir diğer önemli otobüs hattı.",
      length: "Yaklaşık 9.5 km",
      difficulty: "Standart Ulaşım",
      type: "Belediye Otobüs Hattı",
      linkedDorms: ["dorms_rahime_sultan", "dorms_serdivan_erkek", "dorms_sakarya_kiz", "dorms_arif_nihat"],
      intervals: "Hafta içi ve hafta sonu 07:00 - 22:00 saatleri arasında her 20 dakikada bir düzenli sefer yapılmaktadır.",
      sakusUrls: [
        { name: "15 Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/15" }
      ]
    },
    {
      id: "route_4",
      category: "transport",
      name: "Hat 4: Sakarya Park - Hızırtepe - Çarşı - Kampüs",
      color: "#34495e",
      path: [
        [40.7720, 30.3920],
        [40.7656, 30.3664],
        [40.7512, 30.3452],
        [40.7441, 30.3370],
        [40.7418, 30.3342]
      ],
      details: "Sakarya Park mesire alanından kalkarak Hızırtepe mahallesi, merkez (Çarşı) ve Mavi Durak üzerinden üniversiteye ulaşım sağlayan belediye otobüs hattı.",
      length: "Yaklaşık 8.2 km",
      difficulty: "Standart Ulaşım",
      type: "Belediye Otobüs Hattı",
      linkedDorms: ["dorms_rahime_sultan", "dorms_serdivan_erkek", "dorms_sakarya_kiz", "dorms_arif_nihat"],
      intervals: "Hafta içi saat başı ve buçuklarda (her 30 dakikada bir) kalkış yapar. Hafta sonu ise saat başlarında seferleri vardır.",
      sakusUrls: [
        { name: "4 Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/4" }
      ]
    },
    {
      id: "route_19k",
      category: "transport",
      name: "Hat 19K: Sakarya Park - Çevre Yolu - Kampüs",
      color: "#27ae60",
      path: [
        [40.7720, 30.3920],
        [40.7694, 30.3725],
        [40.7656, 30.3664],
        [40.7512, 30.3452],
        [40.7441, 30.3370],
        [40.7418, 30.3342]
      ],
      details: "Sakarya Park ve Çevre yolu üzerinden gelip Serdivan AVM durakları ve Üniversite Caddesi üzerinden kampüse çıkan ekspres hatlardan biridir.",
      length: "Yaklaşık 10.1 km",
      difficulty: "Ekspres Ulaşım",
      type: "Belediye Otobüs Hattı",
      linkedDorms: ["dorms_rahime_sultan", "dorms_serdivan_erkek", "dorms_sakarya_kiz", "dorms_arif_nihat"],
      intervals: "Hafta içi ders giriş-çıkış saatlerinde sabah 07:15 - 10:00 ve akşam 16:00 - 19:00 arası her 15 dakikada bir ekspres sefer yapar.",
      sakusUrls: [
        { name: "19K Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/19K" }
      ]
    },
    {
      id: "route_yenikent",
      category: "transport",
      name: "Yenikent (Karaman-Camili-Korucuk) Kampüs Bağlantı Hatları (21K - 22K - 24K)",
      color: "#f1c40f",
      path: [
        [40.8250, 30.3480],
        [40.8010, 30.3550],
        [40.7678, 30.3695],
        [40.7441, 30.3370],
        [40.7418, 30.3342]
      ],
      details: "Yenikent yerleşim bölgelerinden (Karaman, Camili, Korucuk) direkt olarak SAÜ Esentepe Kampüsü'ne çıkan ekspres hatlar grubudur. Serdivan Belediyesi önündeki duraklardan geçerler.",
      length: "Yaklaşık 18.5 km",
      difficulty: "Uzak Mesafe / Ekspres",
      type: "Belediye Ekspres Otobüs Hatları",
      linkedDorms: ["dorms_sabahattin_zaim"],
      intervals: "Ortak çalışma çizelgesindedirler. Sabah 07:00 - 09:30 arası her 15 dakikada bir, günün geri kalanında ise her 30 dakikada bir seferleri düzenlenir.",
      sakusUrls: [
        { name: "21K Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/21K" },
        { name: "22K Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/22K" },
        { name: "24K Saatleri", url: "https://ulasim.sakarya.bel.tr/Hat-Saatleri/24K" }
      ]
    },

    // --- KORİDORDAKİ BİSİKLET VE DOĞA ROTALARI ---
    {
      id: "route_sau_yokus",
      category: "routes",
      name: "Mavi Durak - SAÜ Kampüs Bisiklet Yolu",
      color: "#2ecc71", // Yeşil
      path: [
        [40.7656, 30.3664], // Mavi Durak
        [40.7630, 30.3580],
        [40.7570, 30.3540], // Sakarya Kız Yurdu yanı
        [40.7512, 30.3452], // Rahime Sultan & Serdivan Erkek önü
        [40.7441, 30.3370], // Kampüs Giriş
        [40.7435, 30.3340]  // Kampüs Bisiklet Teslim Noktası
      ],
      details: "Yurtlar bölgesinin tam içinden geçerek Mavi Durak ile SAÜ Kampüsünü birbirine bağlayan, öğrencilerin bisikletle ulaşım yapmasını sağlayan özel koruma şeritli bisiklet yoludur. Çıkış yokuşlu olup iniş oldukça akıcıdır.",
      length: "3.8 km (Tek Yön)",
      difficulty: "Orta-Zor (Yokuş Eğimli)",
      type: "Ulaşım ve Spor Bisiklet Yolu",
      linkedDorms: ["dorms_rahime_sultan", "dorms_serdivan_erkek", "dorms_sakarya_kiz"]
    },
    {
      id: "route_cark_deresi",
      category: "routes",
      name: "Yazlık Çark Deresi Rekreasyonel Parkuru",
      color: "#27ae60", // Koyu Yeşil
      path: [
        [40.7895, 30.3768],
        [40.7780, 30.3748],
        [40.7620, 30.3725],
        [40.7380, 30.3710]
      ],
      details: "Yurtların aşağısında yer alan Çark Deresi kıyısı boyunca uzanan bisiklet ve koşu parkuru. Boş zamanlarda kafa dinlemek ve spor yapmak için idealdir.",
      length: "8.5 km",
      difficulty: "Çok Kolay (Düz Zemin)",
      type: "Egzersiz Bisiklet & Yürüyüş Yolu",
      linkedDorms: []
    }
  ]
};
