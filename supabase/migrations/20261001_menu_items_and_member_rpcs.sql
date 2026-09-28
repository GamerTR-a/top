-- ============================================================================
-- NevGenç — Menüde Ne Var? tablosu + Başkan paneli üye/katılımcı RPC'leri
-- (2026-10-01). İdempotent — birden fazla kez çalıştırılabilir.
--
-- ÖNCE 20260926_news_jobs_community_notifications.sql çalıştırılmış olmalı
-- (news_bulletins / job_listings / community_notifications tabloları).
-- ============================================================================

-- ── 1. menu_items (Nev Plus > Menüde Ne Var?) ──────────────────────────────
-- Kod: lib/services/supabase_data_service.dart -> getMenuItems/createMenuItem/...
-- job_listings ile aynı yapı ve aynı RLS: herkes okur, yalnızca admin yazar.
CREATE TABLE IF NOT EXISTS public.menu_items (
  id           BIGSERIAL PRIMARY KEY,
  title        TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 200),
  description  TEXT NOT NULL CHECK (char_length(description) BETWEEN 1 AND 5000),
  published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_menu_items_published ON public.menu_items(published_at DESC);

ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "menu_items_select_all" ON public.menu_items;
CREATE POLICY "menu_items_select_all" ON public.menu_items
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "menu_items_admin_write" ON public.menu_items;
CREATE POLICY "menu_items_admin_write" ON public.menu_items
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- ── 2. Başkan paneli: üye listesi (ad + e-posta) ────────────────────────────
-- E-posta profiles'ta değil auth.users'ta durur; istemci auth şemasını
-- okuyamaz. Bu yüzden SECURITY DEFINER + açık yetki kontrolü: yalnızca o
-- topluluğun başkanı veya admin çağırabilir.
CREATE OR REPLACE FUNCTION public.get_community_members_detailed(p_community_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
    OR EXISTS (SELECT 1 FROM public.communities c WHERE c.id = p_community_id AND c.chairman_id = auth.uid())
  ) THEN
    RAISE EXCEPTION 'Bu topluluğun üyelerini görme yetkiniz yok.' USING ERRCODE = '42501';
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'user_id',       cm.user_id,
             'joined_at',     cm.joined_at,
             'name',          p.name,
             'email',         u.email,
             'profile_photo', p.profile_photo,
             'xp',            p.xp,
             'role',          p.role,
             'department',    to_jsonb(p.department)
           ) ORDER BY cm.joined_at)
    FROM public.community_members cm
    LEFT JOIN public.profiles p ON p.id = cm.user_id
    LEFT JOIN auth.users u      ON u.id = cm.user_id
    WHERE cm.community_id = p_community_id
  ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.get_community_members_detailed(BIGINT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_community_members_detailed(BIGINT) TO authenticated;

-- ── 3. Başkan paneli: etkinlik katılımcıları (ad + e-posta) ─────────────────
-- Yalnızca gönderinin ait olduğu topluluğun başkanı veya admin.
CREATE OR REPLACE FUNCTION public.get_event_participants_detailed(p_post_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
    OR EXISTS (
      SELECT 1 FROM public.posts po
      JOIN public.communities c ON c.id = po.community_id
      WHERE po.id = p_post_id AND c.chairman_id = auth.uid()
    )
  ) THEN
    RAISE EXCEPTION 'Bu etkinliğin katılımcılarını görme yetkiniz yok.' USING ERRCODE = '42501';
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'user_id',       ep.user_id,
             'created_at',    ep.created_at,
             'name',          p.name,
             'email',         u.email,
             'profile_photo', p.profile_photo,
             'role',          p.role,
             'department',    to_jsonb(p.department)
           ) ORDER BY ep.created_at)
    FROM public.event_participants ep
    LEFT JOIN public.profiles p ON p.id = ep.user_id
    LEFT JOIN auth.users u      ON u.id = ep.user_id
    WHERE ep.post_id = p_post_id
  ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.get_event_participants_detailed(BIGINT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_event_participants_detailed(BIGINT) TO authenticated;

-- PostgREST şema önbelleğini yenile (yeni tablo/fonksiyonlar hemen görünsün).
NOTIFY pgrst, 'reload schema';

-- ── Doğrulama (isteğe bağlı) ────────────────────────────────────────────────
-- SELECT to_regclass('public.menu_items'), to_regclass('public.news_bulletins'),
--        to_regclass('public.job_listings'), to_regclass('public.community_notifications');
-- SELECT proname FROM pg_proc WHERE proname IN
--   ('get_community_members_detailed', 'get_event_participants_detailed');
