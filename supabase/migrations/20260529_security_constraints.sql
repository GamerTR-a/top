-- ============================================================================
-- NevGenç — Güvenlik & Veri Bütünlüğü Migration'ı (2026-05-29)
-- ----------------------------------------------------------------------------
-- Bu dosya, client tarafındaki kontrollerin SUNUCUDA da zorlanmasını sağlar.
-- Supabase Dashboard → SQL Editor'da çalıştırın veya `supabase db push` kullanın.
-- Her blok idempotent olacak şekilde yazılmıştır (tekrar çalıştırılabilir).
-- ============================================================================

-- ── 1. Haftalık destek limiti (2/2) — client bypass'ını engelle ─────────────
-- Aynı gönderiye iki kez destek verilmesini engelle:
ALTER TABLE public.post_supports
  DROP CONSTRAINT IF EXISTS post_supports_user_post_unique;
ALTER TABLE public.post_supports
  ADD CONSTRAINT post_supports_user_post_unique UNIQUE (user_id, post_id);

-- Haftada en fazla 2 destek (ISO hafta + yıl bazında):
CREATE OR REPLACE FUNCTION public.check_weekly_support_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (
    SELECT COUNT(*) FROM public.post_supports
    WHERE user_id = NEW.user_id
      AND week_number = NEW.week_number
      AND year = NEW.year
  ) >= 2 THEN
    RAISE EXCEPTION 'weekly_limit_exceeded'
      USING HINT = 'Haftalık destek hakkınız doldu (2/2).';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_weekly_limit ON public.post_supports;
CREATE TRIGGER enforce_weekly_limit
  BEFORE INSERT ON public.post_supports
  FOR EACH ROW EXECUTE FUNCTION public.check_weekly_support_limit();

-- ── 2. Uzunluk kısıtları (REST API üzerinden taşmaları engelle) ─────────────
ALTER TABLE public.community_messages
  DROP CONSTRAINT IF EXISTS community_messages_content_len;
ALTER TABLE public.community_messages
  ADD CONSTRAINT community_messages_content_len
  CHECK (char_length(content) BETWEEN 1 AND 2000);

ALTER TABLE public.posts
  DROP CONSTRAINT IF EXISTS posts_content_len;
ALTER TABLE public.posts
  ADD CONSTRAINT posts_content_len
  CHECK (char_length(content) BETWEEN 1 AND 5000);

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_name_len,
  DROP CONSTRAINT IF EXISTS profiles_dept_len,
  DROP CONSTRAINT IF EXISTS profiles_grade_len;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_name_len  CHECK (char_length(name) BETWEEN 1 AND 100),
  ADD CONSTRAINT profiles_dept_len  CHECK (department IS NULL OR char_length(department) <= 100),
  ADD CONSTRAINT profiles_grade_len CHECK (grade IS NULL OR char_length(grade) <= 20);

-- ── 3. Üye sayacı için atomik RPC'ler (client fallback'i kaldırıldı) ─────────
-- joinCommunity/leaveCommunity bu RPC'lere güveniyor; tanımlı olduklarından emin olun:
CREATE OR REPLACE FUNCTION public.increment_community_member(community_id BIGINT)
RETURNS void LANGUAGE sql AS $$
  UPDATE public.communities SET member_count = COALESCE(member_count, 0) + 1
  WHERE id = community_id;
$$;

CREATE OR REPLACE FUNCTION public.decrement_community_member(community_id BIGINT)
RETURNS void LANGUAGE sql AS $$
  UPDATE public.communities SET member_count = GREATEST(COALESCE(member_count, 0) - 1, 0)
  WHERE id = community_id;
$$;

-- ============================================================================
-- 4. RLS (Row Level Security) — ŞABLON / DENETİM LİSTESİ
-- ----------------------------------------------------------------------------
-- ÖNEMLİ: Anon key hem mobil APK'da hem web bundle'ında AÇIKTIR. Sistemin
-- gerçek güvenlik sınırı RLS'tir. Aşağıdaki politikaların her tabloda açık ve
-- doğru olduğunu DOĞRULAYIN. (Şema adlarınıza göre kolon adlarını uyarlayın.)
-- ============================================================================

-- profiles: herkes okuyabilir (liderlik/QR için), yalnızca sahibi günceller,
-- yalnızca admin siler (silme zaten delete-user Edge Function üzerinden yapılır).
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_select ON public.profiles;
CREATE POLICY profiles_select ON public.profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS profiles_insert_own ON public.profiles;
CREATE POLICY profiles_insert_own ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- post_supports: yalnızca sahibi kendi desteklerini ekler/siler.
ALTER TABLE public.post_supports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS post_supports_own ON public.post_supports;
CREATE POLICY post_supports_own ON public.post_supports
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- community_messages: giriş yapan okuyabilir, yalnızca yazarı INSERT eder.
ALTER TABLE public.community_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS community_messages_select ON public.community_messages;
CREATE POLICY community_messages_select ON public.community_messages
  FOR SELECT USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS community_messages_insert_own ON public.community_messages;
CREATE POLICY community_messages_insert_own ON public.community_messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- posts: herkes okur; yalnızca admin oluşturur (uygulamada da admin-gated).
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS posts_select ON public.posts;
CREATE POLICY posts_select ON public.posts FOR SELECT USING (true);
DROP POLICY IF EXISTS posts_insert_admin ON public.posts;
CREATE POLICY posts_insert_admin ON public.posts
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- fcm_tokens: yalnızca sahibi yönetir.
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fcm_tokens_own ON public.fcm_tokens;
CREATE POLICY fcm_tokens_own ON public.fcm_tokens
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- NOT: community_members, events, event_registrations, calendar_notes,
-- notifications, discounts, badges, user_badges tabloları için de benzer
-- "sahibi yönetir / herkes okur" politikalarını ekleyin. Hiçbir tablo
-- RLS'siz (public yazılabilir) kalmamalıdır.
