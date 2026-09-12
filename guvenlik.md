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
