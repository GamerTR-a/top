-- ============================================================================
-- NevGenç — Storage bucket doğrulaması + claim_coupon rate limiting
-- ----------------------------------------------------------------------------
-- kontrol.md Bölüm 5.10 / 5.12: dosya yükleme yalnızca istemci tarafında
-- (FileValidator) doğrulanıyordu, sunucu/bucket seviyesinde bir sınır yoktu;
-- claim_coupon RPC'sinde de hiçbir rate limiting yoktu. Supabase Dashboard →
-- SQL Editor'da çalıştırın. İdempotent'tir.
-- ============================================================================

-- ── 1. post-images bucket'ında dosya tipi/boyutu sunucuda da sınırlanıyor ──
-- Önceden yalnızca lib/utils/file_validator.dart (istemci) kontrol ediyordu —
-- Storage REST API'sine doğrudan istekle bu kontrol atlanabilirdi.
UPDATE storage.buckets
SET
  file_size_limit = 5242880, -- 5 MB (FileValidator ile aynı sınır)
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
WHERE id = 'post-images';

-- ── 2. claim_coupon için basit rate limiting (dakikada en fazla 10 deneme) ─
-- Yalnızca SECURITY DEFINER fonksiyon içinden erişilir, doğrudan tablo
-- erişimi PUBLIC'ten alınmıştır.
CREATE TABLE IF NOT EXISTS public.claim_coupon_rate_limit (
  user_id      UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  call_count   INTEGER NOT NULL DEFAULT 0
);
ALTER TABLE public.claim_coupon_rate_limit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.claim_coupon_rate_limit FROM PUBLIC, anon, authenticated;

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
  v_call_count INTEGER;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized', 'message', 'Lütfen önce giriş yapın.');
  END IF;

  -- Rate limit: kayan 1 dakikalık pencerede en fazla 10 çağrı.
  INSERT INTO public.claim_coupon_rate_limit (user_id, window_start, call_count)
  VALUES (v_user_id, NOW(), 1)
  ON CONFLICT (user_id) DO UPDATE SET
    call_count = CASE
      WHEN public.claim_coupon_rate_limit.window_start < NOW() - INTERVAL '1 minute' THEN 1
      ELSE public.claim_coupon_rate_limit.call_count + 1
    END,
    window_start = CASE
      WHEN public.claim_coupon_rate_limit.window_start < NOW() - INTERVAL '1 minute' THEN NOW()
      ELSE public.claim_coupon_rate_limit.window_start
    END;

  SELECT call_count INTO v_call_count
  FROM public.claim_coupon_rate_limit WHERE user_id = v_user_id;

  IF v_call_count > 10 THEN
    RETURN jsonb_build_object(
      'success', false, 'error', 'rate_limited',
      'message', 'Çok fazla deneme yaptınız. Lütfen bir dakika sonra tekrar deneyin.'
    );
  END IF;

  SELECT code, claimed_at INTO v_existing_code, v_existing_claimed_at
  FROM public.coupons
  WHERE discount_id = p_discount_id AND claimed_by = v_user_id
  LIMIT 1;

  IF v_existing_code IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true, 'code', v_existing_code, 'already_claimed', true,
      'claimed_at', v_existing_claimed_at, 'message', 'Daha önce aldığınız kupon görüntülendi.'
    );
  END IF;

  SELECT COALESCE(latitude, 40.7408), COALESCE(longitude, 30.3333), COALESCE(geofence_radius_meters, 50.0)
  INTO v_merch_lat, v_merch_lng, v_radius
  FROM public.discounts WHERE id = p_discount_id;

  IF v_merch_lat IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'discount_not_found', 'message', 'Geçersiz fırsat.');
  END IF;

  v_distance_meters := v_earth_radius_m * 2.0 * asin(
    sqrt(
      power(sin(radians((p_user_lat - v_merch_lat) / 2.0)), 2.0) +
      cos(radians(p_user_lat)) * cos(radians(v_merch_lat)) *
      power(sin(radians((p_user_lng - v_merch_lng) / 2.0)), 2.0)
    )
  );

  IF v_distance_meters > v_radius THEN
    RETURN jsonb_build_object(
      'success', false, 'error', 'distance_too_far',
      'distance_meters', round(v_distance_meters::numeric, 1),
      'max_allowed_meters', round(v_radius::numeric, 1),
      'message', 'İşletmeye yeterince yakın değilsiniz (' || round(v_distance_meters::numeric, 0)::text || 'm uzaktasınız). Kuponu açmak için 50m yakınına gelmelisiniz.'
    );
  END IF;

  SELECT id, code INTO v_coupon_id, v_coupon_code
  FROM public.coupons
  WHERE discount_id = p_discount_id AND status = 'available'
  ORDER BY random()
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF v_coupon_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'out_of_stock', 'message', 'Maalesef bu işletmeye ait tüm kuponlar tükenmiştir.');
  END IF;

  UPDATE public.coupons SET status = 'claimed', claimed_by = v_user_id, claimed_at = NOW() WHERE id = v_coupon_id;

  RETURN jsonb_build_object(
    'success', true, 'code', v_coupon_code, 'already_claimed', false,
    'claimed_at', NOW(), 'distance_meters', round(v_distance_meters::numeric, 1),
    'message', 'Tebrikler! Kupon kodunuz başarıyla açıldı.'
  );
END;
$$;

-- ============================================================================
-- Doğrulama:
--   SELECT id, file_size_limit, allowed_mime_types FROM storage.buckets WHERE id = 'post-images';
--   SELECT prosrc FROM pg_proc WHERE proname = 'claim_coupon'; -- "rate_limited" görünmeli
-- ============================================================================
