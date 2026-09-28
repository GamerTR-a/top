# Supabase — dizin haritası ve tek doğru kaynak

Bu proje geçmişinde aynı tabloları/politikaları farklı kurallarla tanımlayan
birden fazla "temel şema" dosyası birikmişti (`supabase_schema.sql`,
`supabase_security_patch.sql`, `combined_supabase_setup.sql`,
`nev_coupons_setup.sql`) — hangisinin canlı veritabanını yansıttığı belirsizdi
ve bu, 2026-09-26 güvenlik denetiminde bulunan bir RLS regresyonunun
(`profiles_update_own` rol kilidinin kaybolması) kök nedeniydi. Bu dördü artık
`archive/` altında, her birinin başında "artık çalıştırma" uyarısıyla duruyor.

## Tek doğru kaynak

**`migrations/*.sql`** — dosya adındaki tarih sırasıyla, canlı projeye
(`vvfdcxeewqcgbcpeabac`, bkz. proje belleği) uygulanmış gerçek değişiklik
geçmişi. Her dosya idempotenttir (tekrar çalıştırılabilir: `DROP POLICY IF
EXISTS` + `CREATE POLICY`, `CREATE OR REPLACE FUNCTION`, `ADD COLUMN IF NOT
EXISTS`). **Yeni bir RLS/RPC/şema değişikliği yapılacaksa buraya, tarihli yeni
bir dosya olarak eklenir — var olan bir migration dosyası geriye dönük
değiştirilmez.**

Diğer dosyalar:
- `delete_account.sql` — güncel/tek geçerli `delete_account()` RPC'si (Apple
  5.1.1(v) hesap silme). `archive/`'daki eski sürümler GEÇERSİZDİR.
- `functions/` — Edge Functions (`delete-user`, `send-notification`,
  `send-community-notification`). Deploy: `supabase functions deploy <ad>
  --project-ref vvfdcxeewqcgbcpeabac`.
- `insert_dijital_firsatlar.sql`, `verify_insert.sql` — tek seferlik veri
  ekleme/doğrulama scriptleri (şema tanımlamaz), referans olarak kalıyor.
- `archive/` — **çalıştırmayın.** Tarihsel bootstrap script'leri; orijinal
  tablo tanımlarının en kapsamlı hali `archive/supabase_schema.sql`'de ama RLS
  kuralları migrations/ tarafından ezilmiş/güncellenmiştir.

## Sıfırdan yeni bir proje kurulacaksa

Bugüne kadar bu senaryo yaşanmadı (tek canlı proje var), ama gerekirse sıra:
1. `archive/supabase_schema.sql` (en kapsamlı tablo seti + RLS)
2. `archive/combined_supabase_setup.sql`'den yalnızca `community_links` tablosu,
   `enforce_posts_leader_insert` trigger'ı ve `post-images` storage bucket
   kurulumu (dosyanın geri kalanı 1. adımla çakışır, atlanır)
3. `migrations/*.sql`, dosya adı sırasıyla, baştan sona
4. `delete_account.sql`

Her adımdan sonra `pg_policies`/`pg_proc` ile canlı durumu doğrulayın —
statik dosyaların canlı DB ile senkron olduğunu varsaymayın (bu projede
defalarca senkron çıkmadığı görüldü).
