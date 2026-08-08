-- ============================================================
-- NevGenç — Supabase PostgreSQL Şeması
-- Supabase SQL Editor'da çalıştırın.
-- ============================================================

-- ── 1. Profiller (auth.users'ı genişletir) ──────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'student', -- 'student' | 'admin'
  department    TEXT,
  grade         TEXT,
  xp            INTEGER NOT NULL DEFAULT 0,
  profile_photo TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Yeni kullanıcı kaydında otomatik profil oluşturmaz; uygulama tarafından oluşturulur.

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

-- ── RPC: Güvenli sayaç ve XP fonksiyonları ──────────────────
CREATE OR REPLACE FUNCTION public.increment_post_support(post_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.post_supports s
    WHERE s.user_id = auth.uid() AND s.post_id = increment_post_support.post_id
  ) THEN
    RAISE EXCEPTION 'Unauthorized: no support record found';
  END IF;
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

CREATE OR REPLACE FUNCTION public.increment_community_member(community_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.community_members m
    WHERE m.user_id = auth.uid() AND m.community_id = increment_community_member.community_id
  ) THEN
    RAISE EXCEPTION 'Unauthorized: not a member';
  END IF;
  UPDATE public.communities SET member_count = member_count + 1 WHERE id = community_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_community_member(community_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  UPDATE public.communities SET member_count = GREATEST(member_count - 1, 0) WHERE id = community_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_post_quality(post_id BIGINT, new_score REAL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF new_score < 0 OR new_score > 5 THEN
    RAISE EXCEPTION 'Invalid score: must be between 0 and 5';
  END IF;
  UPDATE public.posts
  SET quality_score = (quality_score + new_score) / 2.0
  WHERE id = post_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_user_xp(user_id UUID, xp_amount INTEGER)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
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

-- ── Row Level Security ───────────────────────────────────────
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

-- Profiller: herkes okuyabilir; insert sadece role='student'; update rol değişikliğine izin vermez
CREATE POLICY "profiles_select"        ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert"        ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id AND role = 'student');
CREATE POLICY "profiles_update_own"    ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id AND role = (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()));
CREATE POLICY "profiles_update_admin"  ON public.profiles FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));
CREATE POLICY "profiles_delete_admin"  ON public.profiles FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- Topluluklar: herkes okuyabilir, admin değiştirebilir
CREATE POLICY "communities_select" ON public.communities FOR SELECT USING (true);
CREATE POLICY "communities_write"  ON public.communities FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Üyelikler: giriş yapmış herkes okuyabilir/yazabilir (kendi kaydı)
CREATE POLICY "members_select" ON public.community_members FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "members_insert" ON public.community_members FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "members_delete" ON public.community_members FOR DELETE USING (auth.uid() = user_id);

-- Gönderiler: herkes okuyabilir; yazar veya admin değiştirebilir/silebilir
CREATE POLICY "posts_select" ON public.posts FOR SELECT USING (true);
CREATE POLICY "posts_insert" ON public.posts FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND auth.uid() = user_id);
CREATE POLICY "posts_update" ON public.posts FOR UPDATE
  USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));
CREATE POLICY "posts_delete" ON public.posts FOR DELETE
  USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- Destek oyları
CREATE POLICY "supports_select" ON public.post_supports FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "supports_insert" ON public.post_supports FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "supports_delete" ON public.post_supports FOR DELETE USING (auth.uid() = user_id);

-- Etkinlikler: herkes okuyabilir
CREATE POLICY "events_select" ON public.events FOR SELECT USING (true);
CREATE POLICY "events_write"  ON public.events FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Etkinlik kayıtları
CREATE POLICY "event_reg_select" ON public.event_registrations FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "event_reg_insert" ON public.event_registrations FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "event_reg_delete" ON public.event_registrations FOR DELETE USING (auth.uid() = user_id);

-- Rozetler: herkes görebilir; sadece kendine veya admin rozet ekleyebilir
CREATE POLICY "badges_select"      ON public.badges FOR SELECT USING (true);
CREATE POLICY "user_badges_select" ON public.user_badges FOR SELECT USING (true);
CREATE POLICY "user_badges_insert" ON public.user_badges FOR INSERT
  WITH CHECK (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- Bildirimler: sadece sahibi görebilir/silebilir; sadece admin ekleyebilir
CREATE POLICY "notifications_select" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "notifications_update" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "notifications_delete" ON public.notifications FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "notifications_insert" ON public.notifications FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- FCM token'ları: sadece sahibi
CREATE POLICY "fcm_select" ON public.fcm_tokens FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "fcm_upsert" ON public.fcm_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "fcm_update" ON public.fcm_tokens FOR UPDATE USING (auth.uid() = user_id);

-- İndirimler: herkes okuyabilir
CREATE POLICY "discounts_select" ON public.discounts FOR SELECT USING (true);
CREATE POLICY "discounts_write"  ON public.discounts FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Takvim notları: sadece sahibi
CREATE POLICY "calendar_select" ON public.calendar_notes FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "calendar_insert" ON public.calendar_notes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "calendar_delete" ON public.calendar_notes FOR DELETE USING (auth.uid() = user_id);

-- Topluluk mesajları: giriş yapmış herkes okuyabilir/yazabilir; sadece sahibi silebilir
CREATE POLICY "messages_select" ON public.community_messages FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "messages_insert" ON public.community_messages FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "messages_delete" ON public.community_messages FOR DELETE USING (auth.uid() = user_id);

-- ── Realtime Aktivasyonu ─────────────────────────────────────
-- posts ve community_messages için anlık değişiklik yayını açılır.
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.community_messages;

-- ── İlk rozet (opsiyonel seed) ───────────────────────────────
INSERT INTO public.badges (name, icon, description) VALUES
  ('İlk Adım', '🎯', 'İlk kayıt rozeti')
ON CONFLICT DO NOTHING;
