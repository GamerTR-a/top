-- ============================================================================
-- NevGenç — Eksik tablo/sütun/RPC denetimi (2026-09-25)
-- ----------------------------------------------------------------------------
-- Bağlam: Yeni Supabase projesine taşıma sonrası, uygulama kodunun (Dart)
-- beklediği ama canlı veritabanında (hem eski hem yeni projede) HİÇ
-- oluşturulmamış nesneler tespit edildi — kod tabanındaki tüm .from()/.rpc()
-- çağrıları taranarak (bkz. sohbet geçmişi) mevcut şemayla karşılaştırıldı.
-- Bu dosya tüm eksikleri tek seferde tamamlar. İdempotent.
-- ============================================================================

-- ── 1. user_tickets (Kullanıcı Talepleri/Şikayetleri) ───────────────────────
-- Kod: lib/services/supabase_data_service.dart -> createTicket/getAllTickets vb.
-- Tanım supabase_schema.sql'den birebir alındı, hiç uygulanmamıştı.
CREATE TABLE IF NOT EXISTS public.user_tickets (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type        TEXT NOT NULL CHECK (type IN ('complaint', 'request', 'suggestion')),
  subject     TEXT NOT NULL,
  description TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  admin_notes TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_tickets_user ON public.user_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_user_tickets_status ON public.user_tickets(status);

ALTER TABLE public.user_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tickets_select_own" ON public.user_tickets;
CREATE POLICY "tickets_select_own" ON public.user_tickets FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "tickets_insert_own" ON public.user_tickets;
CREATE POLICY "tickets_insert_own" ON public.user_tickets FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "tickets_admin_all" ON public.user_tickets;
CREATE POLICY "tickets_admin_all" ON public.user_tickets FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- ── 2. event_participants (Gönderi-içi "Etkinliğe Katıl" butonu) ───────────
-- Kod: lib/services/supabase_data_service.dart -> joinEvent/leaveEvent/getEventParticipants
-- NOT: public.events + event_registrations'tan AYRI bir özellik — posts.is_event=true
-- gönderilerine "katılıyorum" diyen kullanıcıları tutar. Hiç tanımlanmamıştı.
CREATE TABLE IF NOT EXISTS public.event_participants (
  post_id    BIGINT NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_event_participants_post ON public.event_participants(post_id);

ALTER TABLE public.event_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "event_participants_select" ON public.event_participants;
CREATE POLICY "event_participants_select" ON public.event_participants
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "event_participants_insert_own" ON public.event_participants;
CREATE POLICY "event_participants_insert_own" ON public.event_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "event_participants_delete_own" ON public.event_participants;
CREATE POLICY "event_participants_delete_own" ON public.event_participants
  FOR DELETE USING (auth.uid() = user_id);

-- ── 3. post_supports.community_id (analitik sorguları için) ───────────────
-- Kod: getCommunityStats/getTopActiveMembers .eq('community_id', ...) ile
-- filtreliyor ama sütun hiç yoktu, insert de etmiyordu. Sütun eklenip
-- mevcut satırlar posts.community_id'den doldurulur; yeni satırlar için
-- trigger otomatik doldurur (Dart tarafı değişmesin diye).
ALTER TABLE public.post_supports ADD COLUMN IF NOT EXISTS community_id BIGINT REFERENCES public.communities(id) ON DELETE CASCADE;

UPDATE public.post_supports ps
SET community_id = p.community_id
FROM public.posts p
WHERE ps.post_id = p.id AND ps.community_id IS NULL;

CREATE OR REPLACE FUNCTION public.fill_post_supports_community_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.community_id IS NULL THEN
    SELECT community_id INTO NEW.community_id FROM public.posts WHERE id = NEW.post_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_fill_post_supports_community_id ON public.post_supports;
CREATE TRIGGER trg_fill_post_supports_community_id
  BEFORE INSERT ON public.post_supports
  FOR EACH ROW EXECUTE FUNCTION public.fill_post_supports_community_id();

CREATE INDEX IF NOT EXISTS idx_post_supports_community ON public.post_supports(community_id);

-- ── 4. delete_account() — Apple App Store 5.1.1(v) uyumluluğu için zorunlu ─
-- Kod: lib/services/supabase_auth_service.dart -> _db.rpc('delete_account')
-- supabase/delete_account.sql'deki GÜNCEL/doğrulanmış sürüm kullanıldı
-- (supabase_schema.sql'deki eski sürüm geçersiz `auth.admin.delete_user(...)`
-- SQL çağrısı içeriyordu — o syntax plpgsql'den çağrılamaz).
CREATE OR REPLACE FUNCTION public.delete_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  DELETE FROM public.profiles WHERE id = uid;
  DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_account() FROM public;
GRANT EXECUTE ON FUNCTION public.delete_account() TO authenticated;

-- ── 5. update_post_quality / add_user_xp — RPC eksikti, kod fallback'e
-- düşüyordu (daha az güvenli, doğrudan tablo update). Doğru RPC'ler eklendi.
-- NOT (2026-09-29 güncellemesi): yalnızca "giriş yapmış mı" kontrolü vardı —
-- sahiplik/rol kontrolü yoktu, herhangi bir authenticated kullanıcı herhangi
-- bir gönderinin quality_score'unu sınırsız kez manipüle edebiliyordu (bkz.
-- 20260929_fix_update_post_quality_rpc.sql). Admin kontrolü + PUBLIC'ten
-- REVOKE burada da uygulanıyor — dosya tek başına yeniden çalıştırılırsa
-- açığı geri getirmesin diye.
CREATE OR REPLACE FUNCTION public.update_post_quality(post_id BIGINT, new_score REAL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekir.' USING ERRCODE = '42501';
  END IF;
  IF new_score < 0 OR new_score > 5 THEN
    RAISE EXCEPTION 'Invalid score: must be between 0 and 5';
  END IF;
  UPDATE public.posts
  SET quality_score = (quality_score + new_score) / 2.0
  WHERE id = post_id;
END;
$$;

REVOKE ALL ON FUNCTION public.update_post_quality(BIGINT, REAL) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_post_quality(BIGINT, REAL) TO authenticated;

CREATE OR REPLACE FUNCTION public.add_user_xp(user_id UUID, xp_amount INTEGER)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF auth.uid() != add_user_xp.user_id THEN
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin') THEN
      RAISE EXCEPTION 'Unauthorized: cannot add XP to other users';
    END IF;
  END IF;
  IF xp_amount <= 0 OR xp_amount > 100 THEN
    RAISE EXCEPTION 'Invalid XP amount: must be 1–100';
  END IF;
  UPDATE public.profiles SET xp = profiles.xp + xp_amount WHERE profiles.id = add_user_xp.user_id;
END;
$$;

-- ── 6. Kupon modülü (Nev Fırsatlar — konum tabanlı kupon hak etme) ─────────
-- Kod: lib/services/supabase_data_service.dart -> claim_coupon RPC,
-- lib/widgets/flip_coupon_card.dart. Tüm modül (discounts ek sütunları +
-- coupons tablosu + claim_coupon fonksiyonu) hiç uygulanmamıştı.
-- supabase/nev_coupons_setup.sql'den — DEMO SEED VERİSİ (bölüm 8) HARİÇ
-- alındı, çünkü gerçek discount verisi zaten taşındı.
ALTER TABLE public.discounts
ADD COLUMN IF NOT EXISTS merchant_code_char VARCHAR(2) DEFAULT 'X',
ADD COLUMN IF NOT EXISTS category_prefix VARCHAR(4) DEFAULT 'AB',
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION DEFAULT 40.7408,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION DEFAULT 30.3333,
ADD COLUMN IF NOT EXISTS geofence_radius_meters DOUBLE PRECISION DEFAULT 50.0;

CREATE TABLE IF NOT EXISTS public.coupons (
  id            BIGSERIAL PRIMARY KEY,
  discount_id   BIGINT NOT NULL REFERENCES public.discounts(id) ON DELETE CASCADE,
  code          VARCHAR(12) NOT NULL UNIQUE,
  status        TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'claimed', 'used')),
  claimed_by    UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  claimed_at    TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_coupons_discount_status ON public.coupons(discount_id, status);
CREATE INDEX IF NOT EXISTS idx_coupons_claimed_by ON public.coupons(claimed_by);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON public.coupons(code);

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
  -- NOT (2026-09-28 güncellemesi): admin kontrolü yoktu, PUBLIC'ten REVOKE
  -- edilmemişti — bkz. 20260928_security_hardening_v2.sql. Dosya tek başına
  -- yeniden çalıştırılırsa açığı geri getirmesin diye burada da uygulanıyor.
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
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized', 'message', 'Lütfen önce giriş yapın.');
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

CREATE OR REPLACE FUNCTION public.get_user_claimed_coupons()
RETURNS TABLE (
  coupon_id BIGINT, discount_id BIGINT, code VARCHAR(12), claimed_at TIMESTAMPTZ,
  company_name TEXT, coupon_name TEXT, discount_rate TEXT, logo_path TEXT
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  SELECT c.id, c.discount_id, c.code, c.claimed_at, d.company_name, d.coupon_name, d.discount_rate, d.logo_path
  FROM public.coupons c JOIN public.discounts d ON d.id = c.discount_id
  WHERE c.claimed_by = auth.uid()
  ORDER BY c.claimed_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.export_merchant_paper_list(p_discount_id BIGINT)
RETURNS TABLE (sira_no BIGINT, kupon_kodu VARCHAR(12), durum TEXT, alindigi_tarih TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- NOT (2026-09-28 güncellemesi): admin kontrolü yoktu, PUBLIC'ten REVOKE
  -- edilmemişti — bkz. 20260928_security_hardening_v2.sql. Dosya tek başına
  -- yeniden çalıştırılırsa açığı geri getirmesin diye burada da uygulanıyor.
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekir.' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT ROW_NUMBER() OVER (ORDER BY c.code ASC), c.code, c.status, c.claimed_at
  FROM public.coupons c WHERE c.discount_id = p_discount_id ORDER BY c.code ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.export_merchant_paper_list(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.export_merchant_paper_list(BIGINT) TO authenticated;

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coupons_select_own" ON public.coupons;
CREATE POLICY "coupons_select_own" ON public.coupons
  FOR SELECT USING (claimed_by = auth.uid() OR auth.role() = 'service_role');

-- Her mevcut fırsat için (henüz kupon havuzu yoksa) 30'ar kupon üret —
-- gerçek taşınan discount verisi için gerekli, demo seed DEĞİL.
DO $$
DECLARE
  v_d RECORD;
BEGIN
  FOR v_d IN SELECT id FROM public.discounts LOOP
    IF NOT EXISTS (SELECT 1 FROM public.coupons WHERE discount_id = v_d.id) THEN
      PERFORM public.generate_merchant_coupons(v_d.id, 30);
    END IF;
  END LOOP;
END $$;

-- ── 7. Realtime yayını — yeni projede hiçbir tablo etkin değildi ───────────
-- Kod: notification_service.dart (notifications), socket_service.dart
-- (posts, community_messages) Supabase Realtime aboneliği bekliyor. Hata
-- vermez ama sessizce çalışmaz (canlı güncelleme gelmez) — bu yüzden fark
-- edilmesi zor bir eksikti.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='posts') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='community_messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.community_messages;
  END IF;
END $$;
