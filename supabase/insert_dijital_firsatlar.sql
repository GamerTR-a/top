-- Nev Fırsatlar → "atozcan1.6" başvuru kutucuğu (konum/kupon yok, sadece link)
-- Supabase Dashboard → SQL Editor'da çalıştırın
-- Sadece temel sütunlar kullanılıyor (location/kupon sütunları migration ile eklenir)

INSERT INTO public.discounts (
  company_name,
  coupon_name,
  discount_rate,
  logo_path,
  color
) VALUES (
  'atozcan1.6',
  'Yeni Ürünlerimizi deneyimlemek için başvur',
  'Başvuru',
  NULL,
  'FF2196F3'
) ON CONFLICT DO NOTHING;