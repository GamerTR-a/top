-- ============================================================================
-- NevGenç — Güvenlik denetimi düzeltmeleri (2026-09-28)
-- ----------------------------------------------------------------------------
-- Kapsamlı A-Z mobil güvenlik denetiminde bulunan 3 canlı-DB açığını kapatır.
-- Supabase Dashboard → SQL Editor'da çalıştırın (veya Management API SQL
-- endpoint'i ile). İdempotent — birden fazla kez çalıştırılabilir.
--
-- Bulgu 1 (KRİTİK — rol yükseltme): supabase/migrations/20260529_security_
-- constraints.sql içindeki `profiles_update_own` policy'si `WITH CHECK
-- (auth.uid() = id)` kullanıyor — rol sütununun değişmediğini KONTROL ETMİYOR.
-- Bu, supabase_security_patch.sql ile Ağustos 2026'da uygulanmış olan rol
-- kilidinin üzerine yazıyor olabilir (dosya adı Mayıs tarihli olsa da,
-- 2026-09-24 taşımasında canlıya İLK KEZ uygulandığı doğrulandı — bkz. proje
-- hafızası). Sonuç: herhangi bir öğrenci kendi rolünü 'admin'/'baskan' yapıp
-- tüm admin panelini (kullanıcı silme, haber/iş ilanı ekleme, moderasyon)
-- ele geçirebilirdi. Bu dosya rol kilidini KOŞULSUZ olarak yeniden kurar.
--
-- Bulgu 2 (KRİTİK — yetkisiz kupon üretimi/sızıntısı): `generate_merchant_
-- coupons` ve `export_merchant_paper_list` (nev_coupons_setup.sql +
-- 20260925_missing_tables_and_rpcs.sql) SECURITY DEFINER ama içeride HİÇ rol
-- kontrolü yok ve PUBLIC'ten REVOKE edilmemiş — herhangi bir authenticated
-- kullanıcı sınırsız kupon üretebilir veya tüm kupon kodlarını dökebilirdi
-- (geofence kontrolünü tamamen anlamsız kılar). Admin kontrolü eklenip
-- PUBLIC yetkisi geri alınıyor.
--
-- Bulgu 3 (ORTA — depolama klasör izolasyonu yok): `post_images_auth_write`
-- storage.objects INSERT policy'si herhangi bir authenticated kullanıcının
-- BAŞKA bir kullanıcının `posts/<uid>/...` klasörüne dosya yazmasına izin
-- veriyordu (path'te sahiplik kontrolü yoktu). Artık yalnızca kendi
-- `posts/<kendi-uid>/...` klasörüne yazabiliyor.
-- ============================================================================

-- ── 1. profiles: rol yükseltme koruması (KOŞULSUZ yeniden uygula) ──────────
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND role = (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid())
  );

-- ── 2a. generate_merchant_coupons: yalnızca admin çağırabilir ──────────────
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
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekir.' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(category_prefix, 'AB'), COALESCE(merchant_code_char, 'X')
  INTO v_prefix, v_char
  FROM public.discounts WHERE id = p_discount_id;

  IF v_prefix IS NULL THEN
    RAISE EXCEPTION 'Fırsat bulunamadı (ID: %)', p_discount_id;
  END IF;

  WHILE v_inserted < p_count AND v_tries < (p_count * 10) LOOP
    v_tries := v_tries + 1;
    v_num1 := floor(10 + random() * 90)::integer;
    v_num2 := floor(10 + random() * 90)::integer;

    v_code := UPPER(v_prefix) || v_num1::text || UPPER(v_char) || v_num2::text;

    BEGIN
      INSERT INTO public.coupons (discount_id, code, status)
      VALUES (p_discount_id, v_code, 'available');
      v_inserted := v_inserted + 1;
    EXCEPTION WHEN unique_violation THEN
      CONTINUE;
    END;
  END LOOP;

  RETURN v_inserted;
END;
$$;

REVOKE ALL ON FUNCTION public.generate_merchant_coupons(BIGINT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_merchant_coupons(BIGINT, INTEGER) TO authenticated;

-- ── 2b. export_merchant_paper_list: yalnızca admin çağırabilir ─────────────
CREATE OR REPLACE FUNCTION public.export_merchant_paper_list(p_discount_id BIGINT)
RETURNS TABLE (
  sira_no BIGINT,
  kupon_kodu VARCHAR(12),
  durum TEXT,
  alindigi_tarih TIMESTAMPTZ
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekir.' USING ERRCODE = '42501';
  END IF;

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

REVOKE ALL ON FUNCTION public.export_merchant_paper_list(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.export_merchant_paper_list(BIGINT) TO authenticated;

-- ── 3. post-images Storage: INSERT'i kendi klasörüyle sınırla ──────────────
DROP POLICY IF EXISTS post_images_auth_write ON storage.objects;
CREATE POLICY post_images_auth_write ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'post-images'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = 'posts'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- ============================================================================
-- DOĞRULAMA (çalıştırdıktan sonra elle teyit edin):
--
-- 1) Rol kilidi aktif mi:
--    SELECT policyname, with_check FROM pg_policies
--    WHERE tablename='profiles' AND policyname='profiles_update_own';
--    (with_check ifadesinde "role" karşılaştırması görünmeli)
--
-- 2) Fonksiyonlar artık PUBLIC'e açık değil:
--    SELECT proname, proacl FROM pg_proc
--    WHERE proname IN ('generate_merchant_coupons','export_merchant_paper_list');
--
-- 3) Storage policy'si klasör kısıtlı mı:
--    SELECT policyname, with_check FROM pg_policies
--    WHERE schemaname='storage' AND tablename='objects'
--      AND policyname='post_images_auth_write';
-- ============================================================================
