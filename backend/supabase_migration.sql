-- ============================================================================
-- NevGenç — Supabase SQL Migrasyonu
-- ----------------------------------------------------------------------------
-- Amaç: "Başkan gönderisi + 1-5 yıldız puan + şikayet moderasyonu + görsel
--       yükleme" özelliklerini Supabase tarafında kurar.
--
-- Nasıl çalıştırılır: Supabase Dashboard → SQL Editor → yeni sorgu açıp
-- bu dosyanın tamamını yapıştırın → RUN.
--
-- Not: Script idempotenttir (tekrar çalıştırılabilir).
-- NOT-2: Bu dosya backend/src/db/migrate.js'deki Express şemasının Postgres
--        kolunun birebir karşılığıdır (referans olarak saklanır).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) Yardımcı: mevcut kullanıcının rolünü döndürür (RLS policy'lerinde güvenli)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM profiles WHERE id = auth.uid()
$$;

-- ----------------------------------------------------------------------------
-- 1) posts tablosuna yeni kolonlar (idempotent)
-- ----------------------------------------------------------------------------
ALTER TABLE posts ADD COLUMN IF NOT EXISTS rating_avg   REAL    NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS rating_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS status       TEXT    NOT NULL DEFAULT 'published';

-- ----------------------------------------------------------------------------
-- 2) communities tablosuna başkan alanı (yoksa)
-- ----------------------------------------------------------------------------
ALTER TABLE communities ADD COLUMN IF NOT EXISTS chairman_id uuid REFERENCES profiles(id);

-- ----------------------------------------------------------------------------
-- 3) Başkan gönderi kuralı — TRIGGER (RLS'den bağımsız, her durumda çalışır)
--    • Yalnızca role='admin' veya 'baskan' gönderi oluşturabilir
--    • Başkan yalnızca kendi (chairman_id) topluluğuna gönderi atabilir
--    • Admin her topluluğa atabilir
--    • status boşsa 'published' yapılır
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_posts_leader_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
BEGIN
  SELECT role::text INTO v_role FROM profiles WHERE id::text = NEW.user_id::text;

  IF v_role IS NULL OR v_role NOT IN ('admin', 'baskan') THEN
    RAISE EXCEPTION 'Yalnızca başkan veya admin gönderi oluşturabilir.';
  END IF;

  IF v_role = 'baskan' THEN
    IF (SELECT chairman_id::text FROM communities WHERE id = NEW.community_id)
       IS DISTINCT FROM NEW.user_id::text THEN
      RAISE EXCEPTION 'Başkan yalnızca kendi topluluğuna gönderi atabilir.';
    END IF;
  END IF;

  NEW.status := COALESCE(NEW.status, 'published');
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_posts_leader_insert ON posts;
CREATE TRIGGER trg_posts_leader_insert
  BEFORE INSERT ON posts
  FOR EACH ROW EXECUTE FUNCTION public.enforce_posts_leader_insert();

-- ----------------------------------------------------------------------------
-- 4) post_ratings — kişi başı tek puan (1-5), upsert ile güncellenebilir
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS post_ratings (
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id    bigint NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  rating     integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_post_ratings_post ON post_ratings(post_id);

ALTER TABLE post_ratings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS post_ratings_own_select ON post_ratings;
DROP POLICY IF EXISTS post_ratings_own_insert ON post_ratings;
DROP POLICY IF EXISTS post_ratings_own_update ON post_ratings;
DROP POLICY IF EXISTS post_ratings_own_delete ON post_ratings;
CREATE POLICY post_ratings_own_select ON post_ratings FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY post_ratings_own_insert ON post_ratings FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY post_ratings_own_update ON post_ratings FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY post_ratings_own_delete ON post_ratings FOR DELETE USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 5) post_reports — UGC moderasyon (çift şikayet engelli)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS post_reports (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  post_id    bigint NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason     text,
  status     text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewed', 'dismissed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_reports_status ON post_reports(status);

ALTER TABLE post_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS post_reports_admin_select ON post_reports;
DROP POLICY IF EXISTS post_reports_own_insert ON post_reports;
DROP POLICY IF EXISTS post_reports_admin_update ON post_reports;
CREATE POLICY post_reports_admin_select ON post_reports FOR SELECT USING (public.current_user_role() = 'admin');
CREATE POLICY post_reports_own_insert ON post_reports FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY post_reports_admin_update ON post_reports FOR UPDATE USING (public.current_user_role() = 'admin');

-- ----------------------------------------------------------------------------
-- 6) RPC: upsert_post_rating — puan verir, ortalamayı günceller, ilk puanda XP
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.upsert_post_rating(p_post_id bigint, p_rating integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_avg     numeric(4,2);
  v_count   bigint;
  v_first   boolean;
BEGIN
  IF p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'Puan 1-5 arasında olmalıdır.';
  END IF;

  SELECT NOT EXISTS (
    SELECT 1 FROM post_ratings WHERE user_id = auth.uid() AND post_id = p_post_id
  ) INTO v_first;

  INSERT INTO post_ratings (user_id, post_id, rating)
  VALUES (auth.uid(), p_post_id, p_rating)
  ON CONFLICT (user_id, post_id) DO UPDATE SET rating = excluded.rating;

  SELECT ROUND(AVG(rating)::numeric, 2)::numeric(4,2), COUNT(*)::bigint
    INTO v_avg, v_count
  FROM post_ratings WHERE post_id = p_post_id;

  UPDATE posts SET rating_avg = v_avg, rating_count = v_count WHERE id = p_post_id;

  IF v_first THEN
    UPDATE profiles SET xp = xp + 10 WHERE id = auth.uid();
  END IF;

  RETURN jsonb_build_object('rating_avg', v_avg, 'rating_count', v_count, 'first_time', v_first);
END $$;

-- ----------------------------------------------------------------------------
-- 7) RPC: report_post — şikayet oluşturur (aynı kullanıcı tekrar bildiremez)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.report_post(p_post_id bigint, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO post_reports (post_id, user_id, reason)
  VALUES (p_post_id, auth.uid(), NULLIF(TRIM(p_reason), ''))
  ON CONFLICT (post_id, user_id) DO NOTHING;
END $$;

-- ----------------------------------------------------------------------------
-- 8) RPC: set_post_status — admin gönderiyi gizler / geri getirir
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_post_status(p_post_id bigint, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_status NOT IN ('published', 'hidden') THEN
    RAISE EXCEPTION 'Geçersiz durum.';
  END IF;
  IF public.current_user_role() = 'admin' THEN
    UPDATE posts SET status = p_status WHERE id = p_post_id;
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 9) Storage: post-images bucket (public okuma, giriş yapan yazma)
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('post-images', 'post-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "post_images_public_read" ON storage.objects;
DROP POLICY IF EXISTS "post_images_auth_write" ON storage.objects;
CREATE POLICY "post_images_public_read" ON storage.objects FOR SELECT USING (bucket_id = 'post-images');
CREATE POLICY "post_images_auth_write" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'post-images' AND auth.role() = 'authenticated');

-- ============================================================================
-- Bitti. Aşağıdakileri doğrulayın:
--   SELECT * FROM post_ratings LIMIT 0;      (tablo var)
--   SELECT * FROM post_reports LIMIT 0;      (tablo var)
--   SELECT upsert_post_rating(1, 5);         (test — kendi hesabınızla)
-- ============================================================================
