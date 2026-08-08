-- ============================================================
-- NevGenç — Supabase Tüm Veritabanı ve Şema Kurulum Scripti
-- Supabase Dashboard → SQL Editor'da tek seferde çalıştırın.
-- ============================================================ne 

-- ── 1. Profiller (auth.users'ı genişletir) ──────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'student', -- 'student' | 'baskan' | 'admin'
  department    TEXT,
  grade         TEXT,
  xp            INTEGER NOT NULL DEFAULT 0,
  profile_photo TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 2. Topluluklar ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.communities (
  id             BIGSERIAL PRIMARY KEY,
  name           TEXT NOT NULL,
  logo_path      TEXT,
  category       TEXT NOT NULL,
  score          REAL NOT NULL DEFAULT 0,
  member_count   INTEGER NOT NULL DEFAULT 0,
  description    TEXT,
  chairman_name  TEXT,
  chairman_id    UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 3. Topluluk üyelikleri ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.community_members (
  user_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  community_id  BIGINT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  joined_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, community_id)
);

-- ── 4. Gönderiler ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.posts (
  id              BIGSERIAL PRIMARY KEY,
  community_id    BIGINT REFERENCES public.communities(id) ON DELETE CASCADE,
  community_name  TEXT NOT NULL,
  community_logo  TEXT,
  user_id         UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  content         TEXT NOT NULL CHECK (char_length(content) >= 1 AND char_length(content) <= 5000),
  image_url       TEXT,
  event_image     TEXT,
  support_count   INTEGER NOT NULL DEFAULT 0,
  quality_score   REAL NOT NULL DEFAULT 0.0,
  rating_avg      REAL NOT NULL DEFAULT 0,
  rating_count    INTEGER NOT NULL DEFAULT 0,
  status          TEXT NOT NULL DEFAULT 'published',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 5. Destek oyları ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.post_supports (
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id     BIGINT NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  week_number INTEGER NOT NULL,
  year        INTEGER NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, post_id)
);

-- ── 6. Etkinlikler ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.events (
  id            BIGSERIAL PRIMARY KEY,
  community_id  BIGINT REFERENCES public.communities(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  description   TEXT,
  event_date    TIMESTAMPTZ NOT NULL,
  image_url     TEXT,
  location      TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 7. Etkinlik kayıtları ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.event_registrations (
  user_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_id      BIGINT NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, event_id)
);

-- ── 8. Rozetler ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.badges (
  id          BIGSERIAL PRIMARY KEY,
  name        TEXT NOT NULL,
  icon        TEXT NOT NULL,
  description TEXT
);

CREATE TABLE IF NOT EXISTS public.user_badges (
  user_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  badge_id  BIGINT NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
  earned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, badge_id)
);

-- ── 9. Bildirimler ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  type       TEXT NOT NULL DEFAULT 'info',
  is_read    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 10. FCM token'ları ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token      TEXT NOT NULL,
  platform   TEXT NOT NULL DEFAULT 'android',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, platform)
);

-- ── 11. İndirim/kuponlar ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.discounts (
  id            BIGSERIAL PRIMARY KEY,
  company_name  TEXT NOT NULL,
  coupon_name   TEXT NOT NULL,
  discount_rate TEXT NOT NULL,
  logo_path     TEXT,
  color         TEXT
);

-- ── 12. Takvim notları ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.calendar_notes (
  id         BIGSERIAL PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  date       DATE NOT NULL,
  note       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 13. Topluluk mesajları ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.community_messages (
  id           BIGSERIAL PRIMARY KEY,
  community_id BIGINT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_name    TEXT NOT NULL,
  content      TEXT NOT NULL CHECK (char_length(content) >= 1 AND char_length(content) <= 2000),
  type         TEXT NOT NULL DEFAULT 'general',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 14. post_ratings & post_reports ─────────────────────────
CREATE TABLE IF NOT EXISTS public.post_ratings (
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id    BIGINT NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, post_id)
);

CREATE TABLE IF NOT EXISTS public.post_reports (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  post_id    BIGINT NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason     TEXT,
  status     TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewed', 'dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

-- ── 15. community_links (Faz D) ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.community_links (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  community_id BIGINT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  platform     TEXT NOT NULL CHECK (platform IN ('telegram', 'discord')),
  url          TEXT NOT NULL CHECK (url LIKE 'https://%'),
  label        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (community_id, platform)
);

-- ── İndeksler ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_posts_community      ON public.posts(community_id);
CREATE INDEX IF NOT EXISTS idx_posts_user           ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created        ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_supports_week   ON public.post_supports(user_id, year, week_number);
CREATE INDEX IF NOT EXISTS idx_notifications_user   ON public.notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_date          ON public.events(event_date);
CREATE INDEX IF NOT EXISTS idx_communities_category ON public.communities(category);
CREATE INDEX IF NOT EXISTS idx_calendar_notes_user  ON public.calendar_notes(user_id, date);
CREATE INDEX IF NOT EXISTS idx_community_messages   ON public.community_messages(community_id, type, created_at);
CREATE INDEX IF NOT EXISTS idx_post_ratings_post    ON public.post_ratings(post_id);
CREATE INDEX IF NOT EXISTS idx_post_reports_status  ON public.post_reports(status);
CREATE INDEX IF NOT EXISTS idx_community_links_comm ON public.community_links(community_id);

-- ── Fonksiyonlar & Trigger'lar ────────────────────────────────
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.enforce_posts_leader_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_role text;
BEGIN
  SELECT role::text INTO v_role FROM public.profiles WHERE id::text = NEW.user_id::text;
  IF v_role IS NULL OR v_role NOT IN ('admin', 'baskan') THEN
    RAISE EXCEPTION 'Yalnızca başkan veya admin gönderi oluşturabilir.';
  END IF;
  IF v_role = 'baskan' THEN
    IF (SELECT chairman_id::text FROM public.communities WHERE id = NEW.community_id)
       IS DISTINCT FROM NEW.user_id::text THEN
      RAISE EXCEPTION 'Başkan yalnızca kendi topluluğuna gönderi atabilir.';
    END IF;
  END IF;
  NEW.status := COALESCE(NEW.status, 'published');
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_posts_leader_insert ON public.posts;
CREATE TRIGGER trg_posts_leader_insert
  BEFORE INSERT ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.enforce_posts_leader_insert();

-- ── RPC Fonksiyonları ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.increment_post_support(post_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  UPDATE public.posts SET support_count = support_count + 1 WHERE id = post_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_post_support(post_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  UPDATE public.posts SET support_count = GREATEST(support_count - 1, 0) WHERE id = post_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_post_rating(p_post_id bigint, p_rating integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_avg     numeric(4,2);
  v_count   bigint;
  v_first   boolean;
BEGIN
  IF p_rating < 1 OR p_rating > 5 THEN RAISE EXCEPTION 'Puan 1-5 arasında olmalıdır.'; END IF;
  SELECT NOT EXISTS (SELECT 1 FROM post_ratings WHERE user_id = auth.uid() AND post_id = p_post_id) INTO v_first;
  INSERT INTO post_ratings (user_id, post_id, rating) VALUES (auth.uid(), p_post_id, p_rating)
  ON CONFLICT (user_id, post_id) DO UPDATE SET rating = excluded.rating;
  SELECT ROUND(AVG(rating)::numeric, 2)::numeric(4,2), COUNT(*)::bigint INTO v_avg, v_count FROM post_ratings WHERE post_id = p_post_id;
  UPDATE posts SET rating_avg = v_avg, rating_count = v_count WHERE id = p_post_id;
  IF v_first THEN UPDATE profiles SET xp = xp + 10 WHERE id = auth.uid(); END IF;
  RETURN jsonb_build_object('rating_avg', v_avg, 'rating_count', v_count, 'first_time', v_first);
END $$;

CREATE OR REPLACE FUNCTION public.report_post(p_post_id bigint, p_reason text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO post_reports (post_id, user_id, reason) VALUES (p_post_id, auth.uid(), NULLIF(TRIM(p_reason), ''))
  ON CONFLICT (post_id, user_id) DO NOTHING;
END $$;

CREATE OR REPLACE FUNCTION public.set_post_status(p_post_id bigint, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_status NOT IN ('published', 'hidden') THEN RAISE EXCEPTION 'Geçersiz durum.'; END IF;
  IF public.current_user_role() = 'admin' THEN UPDATE posts SET status = p_status WHERE id = p_post_id; END IF;
END $$;

-- ── RLS Aktifleştirme ─────────────────────────────────────────
ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.communities       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_supports     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.badges            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_badges       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fcm_tokens        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discounts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendar_notes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_ratings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_reports      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_links    ENABLE ROW LEVEL SECURITY;

-- ── RLS Politikaları ──────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
DROP POLICY IF EXISTS "profiles_insert" ON public.profiles;
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "communities_select" ON public.communities;
CREATE POLICY "communities_select" ON public.communities FOR SELECT USING (true);
DROP POLICY IF EXISTS "communities_write" ON public.communities;
CREATE POLICY "communities_write" ON public.communities FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "posts_select" ON public.posts;
CREATE POLICY "posts_select" ON public.posts FOR SELECT USING (true);
DROP POLICY IF EXISTS "posts_insert" ON public.posts;
CREATE POLICY "posts_insert" ON public.posts FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND auth.uid() = user_id);
DROP POLICY IF EXISTS "posts_update" ON public.posts;
CREATE POLICY "posts_update" ON public.posts FOR UPDATE USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

DROP POLICY IF EXISTS "community_links_public_select" ON public.community_links;
CREATE POLICY "community_links_public_select" ON public.community_links FOR SELECT USING (true);

-- ── Storage Bucket ───────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public) VALUES ('post-images', 'post-images', true) ON CONFLICT (id) DO NOTHING;
DROP POLICY IF EXISTS "post_images_public_read" ON storage.objects;
DROP POLICY IF EXISTS "post_images_auth_write" ON storage.objects;
CREATE POLICY "post_images_public_read" ON storage.objects FOR SELECT USING (bucket_id = 'post-images');
CREATE POLICY "post_images_auth_write" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'post-images' AND auth.role() = 'authenticated');

-- ── Realtime ─────────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.community_messages;

-- Seed rozet
INSERT INTO public.badges (name, icon, description) VALUES ('İlk Adım', '🎯', 'İlk kayıt rozeti') ON CONFLICT DO NOTHING;
