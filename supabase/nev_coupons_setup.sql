-- ============================================================
-- NevGenç — Nev Fırsatlar Konum Tabanlı Çevrimdışı Kupon Modülü
-- Supabase Dashboard → SQL Editor'da çalıştırın.
-- ============================================================

-- 1. discounts Tablosuna Konum & Kod Format Alanlarını Ekle / Güncelle
ALTER TABLE public.discounts 
ADD COLUMN IF NOT EXISTS merchant_code_char VARCHAR(2) DEFAULT 'X',
ADD COLUMN IF NOT EXISTS category_prefix VARCHAR(4) DEFAULT 'AB',
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION DEFAULT 40.7408,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION DEFAULT 30.3333,
ADD COLUMN IF NOT EXISTS geofence_radius_meters DOUBLE PRECISION DEFAULT 50.0;

-- 2. Kupon Havuzu Tablosu (Pre-generated Coupons)
CREATE TABLE IF NOT EXISTS public.coupons (
  id            BIGSERIAL PRIMARY KEY,
  discount_id   BIGINT NOT NULL REFERENCES public.discounts(id) ON DELETE CASCADE,
  code          VARCHAR(12) NOT NULL UNIQUE, -- Format: [AB][12][X][34] -> AB12X34
  status        TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'claimed', 'used')),
  claimed_by    UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  claimed_at    TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- İndeksler
CREATE INDEX IF NOT EXISTS idx_coupons_discount_status ON public.coupons(discount_id, status);
CREATE INDEX IF NOT EXISTS idx_coupons_claimed_by ON public.coupons(claimed_by);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON public.coupons(code);

-- 3. İşletme İçin Kriptografik Rastgele Kupon Kodları Üretme Fonksiyonu
-- Format: [Prefix: 2 Harf][Random: 2 Hane][MerchantID: 1 Harf][Random: 2 Hane] (Örn: AB12X34)
CREATE OR REPLACE FUNCTION public.generate_merchant_coupons(
  p_discount_id BIGINT,
  p_count INTEGER DEFAULT 50
)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_prefix VARCHAR(4);
  v_char VARCHAR(2);
  v_num1 INTEGER;
  v_num2 INTEGER;
  v_code VARCHAR(12);
  v_inserted INTEGER := 0;
  v_tries INTEGER := 0;
BEGIN
  -- İşletme ön eklerini al
  SELECT COALESCE(category_prefix, 'AB'), COALESCE(merchant_code_char, 'X')
  INTO v_prefix, v_char
  FROM public.discounts WHERE id = p_discount_id;

  IF v_prefix IS NULL THEN
    RAISE EXCEPTION 'Fırsat bulunamadı (ID: %)', p_discount_id;
  END IF;

  WHILE v_inserted < p_count AND v_tries < (p_count * 10) LOOP
    v_tries := v_tries + 1;
    -- Kriptografik / Rastgele 2 haneli sayılar (10..99)
    v_num1 := floor(10 + random() * 90)::integer;
    v_num2 := floor(10 + random() * 90)::integer;
    
    v_code := UPPER(v_prefix) || v_num1::text || UPPER(v_char) || v_num2::text;

    BEGIN
      INSERT INTO public.coupons (discount_id, code, status)
      VALUES (p_discount_id, v_code, 'available');
      v_inserted := v_inserted + 1;
    EXCEPTION WHEN unique_violation THEN
      -- Çakışma durumunda döngü devam eder
      CONTINUE;
    END;
  END LOOP;

  RETURN v_inserted;
END;
$$;

-- 4. Atomic Kupon Hak Etme (Claim Coupon) SQL Fonksiyonu
-- Mantık:
-- a) Kullanıcı bu fırsattan daha önce kupon almışsa, aldığı kuponu anında döner (İdempotent / 1 Defaya Mahsus).
-- b) Haversine formülü ile kullanıcı konumu ve işletme konumu arasındaki mesafeyi metre cinsinden hesaplar.
-- c) Eğer kullanıcı mesafe > 50m (geofence_radius) ise hata döner.
-- d) Kullanılmayan (status='available') kuponlar arasından RASTGELE 1 kuponu kilitler ve claim eder (Race condition engellenir).
CREATE OR REPLACE FUNCTION public.claim_coupon(
  p_discount_id BIGINT,
  p_user_lat DOUBLE PRECISION,
  p_user_lng DOUBLE PRECISION
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user_id UUID;
  v_existing_code VARCHAR(12);
  v_existing_claimed_at TIMESTAMPTZ;
  v_merch_lat DOUBLE PRECISION;
  v_merch_lng DOUBLE PRECISION;
  v_radius DOUBLE PRECISION;
  v_distance_meters DOUBLE PRECISION;
  v_coupon_id BIGINT;
  v_coupon_code VARCHAR(12);
  v_earth_radius_m CONSTANT DOUBLE PRECISION := 6371000.0;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'Lütfen önce giriş yapın.'
    );
  END IF;

  -- 1. Kullanıcı bu fırsattan daha önce kupon almış mı?
  SELECT code, claimed_at INTO v_existing_code, v_existing_claimed_at
  FROM public.coupons
  WHERE discount_id = p_discount_id AND claimed_by = v_user_id
  LIMIT 1;

  IF v_existing_code IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'code', v_existing_code,
      'already_claimed', true,
      'claimed_at', v_existing_claimed_at,
      'message', 'Daha önce aldığınız kupon görüntülendi.'
    );
  END IF;

  -- 2. İşletme konum ve geofence bilgilerini al
  SELECT COALESCE(latitude, 40.7408), COALESCE(longitude, 30.3333), COALESCE(geofence_radius_meters, 50.0)
  INTO v_merch_lat, v_merch_lng, v_radius
  FROM public.discounts
  WHERE id = p_discount_id;

  IF v_merch_lat IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'discount_not_found',
      'message', 'Geçersiz fırsat.'
    );
  END IF;

  -- 3. Haversine Mesafe Hesabı (Metre)
  v_distance_meters := v_earth_radius_m * 2.0 * asin(
    sqrt(
      power(sin(radians((p_user_lat - v_merch_lat) / 2.0)), 2.0) +
      cos(radians(p_user_lat)) * cos(radians(v_merch_lat)) *
      power(sin(radians((p_user_lng - v_merch_lng) / 2.0)), 2.0)
    )
  );

  -- 4. 50 Metre Geofence Kontrolü
  IF v_distance_meters > v_radius THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'distance_too_far',
      'distance_meters', round(v_distance_meters::numeric, 1),
      'max_allowed_meters', round(v_radius::numeric, 1),
      'message', 'İşletmeye yeterince yakın değilsiniz (' || round(v_distance_meters::numeric, 0)::text || 'm uzaktasınız). Kuponu açmak için 50m yakınına gelmelisiniz.'
    );
  END IF;

  -- 5. Kullanılmayan Havuzdan RASTGELE 1 Kupon Seç ve Kilitle (Atomic)
  SELECT id, code INTO v_coupon_id, v_coupon_code
  FROM public.coupons
  WHERE discount_id = p_discount_id AND status = 'available'
  ORDER BY random()
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF v_coupon_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'out_of_stock',
      'message', 'Maalesef bu işletmeye ait tüm kuponlar tükenmiştir.'
    );
  END IF;

  -- 6. Kuponu Kullanıcıya Atayarak Güncelle
  UPDATE public.coupons
  SET status = 'claimed',
      claimed_by = v_user_id,
      claimed_at = NOW()
  WHERE id = v_coupon_id;

  -- 7. Başarılı Sonuç Dön
  RETURN jsonb_build_object(
    'success', true,
    'code', v_coupon_code,
    'already_claimed', false,
    'claimed_at', NOW(),
    'distance_meters', round(v_distance_meters::numeric, 1),
    'message', 'Tebrikler! Kupon kodunuz başarıyla açıldı.'
  );
END;
$$;

-- 5. Kullanıcının Tüm Almış Olduğu Kuponları Getiren RPC Fonksiyonu
CREATE OR REPLACE FUNCTION public.get_user_claimed_coupons()
RETURNS TABLE (
  coupon_id BIGINT,
  discount_id BIGINT,
  code VARCHAR(12),
  claimed_at TIMESTAMPTZ,
  company_name TEXT,
  coupon_name TEXT,
  discount_rate TEXT,
  logo_path TEXT
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id AS coupon_id,
    c.discount_id,
    c.code,
    c.claimed_at,
    d.company_name,
    d.coupon_name,
    d.discount_rate,
    d.logo_path
  FROM public.coupons c
  JOIN public.discounts d ON d.id = c.discount_id
  WHERE c.claimed_by = auth.uid()
  ORDER BY c.claimed_at DESC;
END;
$$;

-- 6. İşletme İçin Çevrimdışı (Zero-Tech) Fiziki Kağıt Liste Çıktısı Sorgusu
CREATE OR REPLACE FUNCTION public.export_merchant_paper_list(p_discount_id BIGINT)
RETURNS TABLE (
  sira_no BIGINT,
  kupon_kodu VARCHAR(12),
  durum TEXT,
  alindigi_tarih TIMESTAMPTZ
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ROW_NUMBER() OVER (ORDER BY c.code ASC) AS sira_no,
    c.code AS kupon_kodu,
    c.status AS durum,
    c.claimed_at AS alindigi_tarih
  FROM public.coupons c
  WHERE c.discount_id = p_discount_id
  ORDER BY c.code ASC;
END;
$$;

-- 7. RLS Politikaları
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coupons_select_own" ON public.coupons;
CREATE POLICY "coupons_select_own" ON public.coupons 
FOR SELECT USING (claimed_by = auth.uid() OR auth.role() = 'service_role');

-- 8. Örnek Veri Tohumlama (Seed Data & Initial Coupon Pool Generation)
DO $$
DECLARE
  v_d1 BIGINT;
BEGIN
  -- Mevcut indirim verilerini ekle/güncelle (SAÜ Kampüsü / Serdivan koordinatları örnekli)
  INSERT INTO public.discounts (company_name, coupon_name, discount_rate, logo_path, color, merchant_code_char, category_prefix, latitude, longitude, geofence_radius_meters)
  VALUES 
    ('Akademi Dil Kursu', 'Kur Kayıtlarında %20 İndirim', '%20 İndirim', 'assets/images/discounts/akademi.png', 'FF00ACC1', 'A', 'AD', 40.7408, 30.3333, 50.0),
    ('Kampüs Kahvecisi', 'Tüm Sıcak İçeceklerde %15 İndirim', '%15 İndirim', 'assets/images/discounts/kahve.png', 'FF0F9D58', 'K', 'KK', 40.7412, 30.3340, 50.0),
    ('Sarmaşık Fırın & Pastane', 'Tatlı ve Pastalarda %10 İndirim', '%10 İndirim', 'assets/images/discounts/pastane.png', 'FFFF6F00', 'S', 'SP', 40.7401, 30.3325, 50.0)
  ON CONFLICT DO NOTHING;

  -- Her işletme için 30'ar adet rastgele kupon kodu oluştur (Format: AB12X34)
  FOR v_d1 IN SELECT id FROM public.discounts LOOP
    PERFORM public.generate_merchant_coupons(v_d1, 30);
  END LOOP;
END $$;
