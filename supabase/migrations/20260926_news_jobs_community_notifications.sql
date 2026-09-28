-- ============================================================================
-- NevGenç — Görev 1/4/5/6 için yeni tablolar (2026-09-26)
-- ----------------------------------------------------------------------------
-- Bağlam: "10 görev" kapsamında tamamlanan özellikler için gereken şema.
-- İdempotent — birden fazla kez çalıştırılabilir.
-- ============================================================================

-- ── 1. fcm_tokens (Görev 1) ──────────────────────────────────────────────────
-- Kod: lib/services/fcm_service.dart -> upsert('fcm_tokens', {user_id, token, ...})
-- Bu tablo daha önce yalnızca Supabase panelinden elle oluşturulmuştu, hiçbir
-- migration dosyasında tanımı yoktu — repoyla yeniden üretilebilir hale
-- getirmek için buraya eklendi.
--
-- ÖNEMLİ: `token` PRIMARY KEY olmalı. Dart tarafındaki upsert() çağrısı
-- `onConflict` belirtmiyor ve `id` göndermiyor — eğer PK ayrı bir `id`
-- sütunu olsaydı, upsert her seferinde INSERT'e düşer ve aynı token ikinci
-- kez kaydedilmeye çalışıldığında (ör. uygulama yeniden açıldığında) ayrı
-- bir UNIQUE(token) kısıtlaması `ON CONFLICT (id)` tarafından yakalanamayıp
-- sessizce başarısız olurdu (token bir daha asla güncellenmez). `token`'ı
-- doğrudan PK yapmak, upsert'in doğal olarak "ON CONFLICT (token) DO UPDATE"
-- gibi davranmasını sağlar.
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  token      TEXT PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  platform   TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user ON public.fcm_tokens(user_id);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fcm_tokens_owner_all" ON public.fcm_tokens;
CREATE POLICY "fcm_tokens_owner_all" ON public.fcm_tokens
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── 2. news_bulletins (Görev 3+4 — Anasayfa haber akışı) ────────────────────
-- Kod: lib/services/supabase_data_service.dart -> getNews/createNews/...
CREATE TABLE IF NOT EXISTS public.news_bulletins (
  id           BIGSERIAL PRIMARY KEY,
  title        TEXT NOT NULL,
  summary      TEXT NOT NULL,
  content      TEXT NOT NULL,
  image_url    TEXT,
  published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_news_bulletins_published ON public.news_bulletins(published_at DESC);

ALTER TABLE public.news_bulletins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "news_select_all" ON public.news_bulletins;
CREATE POLICY "news_select_all" ON public.news_bulletins
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "news_admin_write" ON public.news_bulletins;
CREATE POLICY "news_admin_write" ON public.news_bulletins
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- ── 3. job_listings (Görev 6 — Nev Plus İş İlanları) ────────────────────────
-- Kod: lib/services/supabase_data_service.dart -> getJobListings/createJobListing/...
CREATE TABLE IF NOT EXISTS public.job_listings (
  id           BIGSERIAL PRIMARY KEY,
  title        TEXT NOT NULL,
  description  TEXT NOT NULL,
  published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_job_listings_published ON public.job_listings(published_at DESC);

ALTER TABLE public.job_listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "job_listings_select_all" ON public.job_listings;
CREATE POLICY "job_listings_select_all" ON public.job_listings
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "job_listings_admin_write" ON public.job_listings;
CREATE POLICY "job_listings_admin_write" ON public.job_listings
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- ── 4. community_notifications (Görev 5 — Başkan bildirim log/audit) ───────
-- Kod: supabase/functions/send-community-notification (service role ile
-- yazar, bu yüzden yazma politikası yalnızca savunma amaçlıdır).
CREATE TABLE IF NOT EXISTS public.community_notifications (
  id               BIGSERIAL PRIMARY KEY,
  community_id     BIGINT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  sender_id        UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title            TEXT NOT NULL,
  body             TEXT NOT NULL,
  recipient_count  INTEGER NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_community_notifications_community ON public.community_notifications(community_id);

ALTER TABLE public.community_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "community_notifications_select_own" ON public.community_notifications;
CREATE POLICY "community_notifications_select_own" ON public.community_notifications
  FOR SELECT USING (
    sender_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- İstemciden doğrudan insert edilmez (Edge Function service_role ile yazar);
-- yine de savunma amaçlı: başkan yalnızca kendi topluluğu için, admin serbest.
DROP POLICY IF EXISTS "community_notifications_insert_own" ON public.community_notifications;
CREATE POLICY "community_notifications_insert_own" ON public.community_notifications
  FOR INSERT WITH CHECK (
    sender_id = auth.uid()
    AND (
      EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
      OR EXISTS (
        SELECT 1 FROM public.communities c
        WHERE c.id = community_id AND c.chairman_id = auth.uid()
      )
    )
  );
