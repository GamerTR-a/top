-- ============================================================================
-- NevGenç — Yayın öncesi yetki/bütünlük düzeltmeleri (2026-10-03)
-- Supabase Dashboard → SQL Editor'da çalıştırın. İdempotent.
--
-- ÖNCE (isteğe bağlı) canlı durumu görmek için şu salt-okunur sorgular:
--   SELECT tablename, policyname, cmd, roles, qual, with_check FROM pg_policies
--   WHERE schemaname='public' AND tablename IN ('profiles','posts','user_badges') ORDER BY 1,3;
--   SELECT proname, proacl, prosrc FROM pg_proc WHERE pronamespace='public'::regnamespace
--     AND proname IN ('increment_post_support','decrement_post_support','add_user_xp');
--   SELECT event_object_table, trigger_name FROM information_schema.triggers
--   WHERE event_object_table IN ('posts','profiles');
--   SELECT conrelid::regclass, conname, confdeltype FROM pg_constraint
--   WHERE contype='f' AND confrelid='public.profiles'::regclass;
--   (confdeltype: a = NO ACTION → o tablodaki satır hesap silmeyi engeller)
--
-- Kapatılanlar:
--  1. (KRİTİK) profiles INSERT policy'si rolü kontrol etmiyordu; profil ilk
--     girişte istemciden oluşturulduğu için API ile kayıt olan biri kendi
--     profilini role='admin' ile yaratabilirdi.
--  2. (YÜKSEK) profiles_update_own yalnızca role'ü kilitliyordu — kullanıcı
--     kendi xp'sini PATCH ile değiştirip liderlik tablosunu ele geçirebilirdi;
--     add_user_xp kendine sınırsız çağrıyla XP veriyordu.
--  3. (YÜKSEK) increment/decrement_post_support tekrar tekrar çağrılarak
--     herhangi bir gönderinin support_count'u şişirilip sıfırlanabiliyordu.
--  4. (ORTA) profiles anon'a açıktı (doğum tarihi dahil) — artık yalnızca
--     giriş yapmış kullanıcılar okur.
-- ============================================================================

-- ── 1+2. role / xp: doğrudan REST isteklerinde değiştirilemez ─────────────
-- SECURITY INVOKER (bilerek): current_user çağıranın rolünü gösterir.
-- REST istekleri 'authenticated'/'anon' ile gelir; SECURITY DEFINER RPC'ler
-- (upsert_post_rating'in +10 XP'si vb.), SQL Editor ve service_role muaftır.
CREATE OR REPLACE FUNCTION public.profiles_guard_privileged()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.role := 'student';
    NEW.xp := 0;
  ELSIF NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  ) THEN
    NEW.role := OLD.role;
    NEW.xp := OLD.xp;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_guard_privileged ON public.profiles;
CREATE TRIGGER profiles_guard_privileged
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_guard_privileged();

-- Admin'in başkan atama/kaldırma akışı (assignChairman/removeChairman)
-- başka bir kullanıcının profilini günceller — bu policy canlıda yoksa o
-- güncelleme sessizce 0 satır etkiler.
DROP POLICY IF EXISTS profiles_update_admin ON public.profiles;
CREATE POLICY profiles_update_admin ON public.profiles
  FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- add_user_xp'yi yalnızca kodun ölü bir yolu çağırıyordu; dışarıya kapat.
DO $$
BEGIN
  IF to_regprocedure('public.add_user_xp(uuid, integer)') IS NOT NULL THEN
    REVOKE EXECUTE ON FUNCTION public.add_user_xp(uuid, integer) FROM PUBLIC, anon, authenticated;
  END IF;
END $$;

-- ── 3. support_count her çağrıda gerçek destek kayıtlarından hesaplanır ───
CREATE OR REPLACE FUNCTION public.increment_post_support(post_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  UPDATE public.posts p
  SET support_count = (
    SELECT COUNT(*) FROM public.post_supports s WHERE s.post_id = p.id
  )
  WHERE p.id = increment_post_support.post_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_post_support(post_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  UPDATE public.posts p
  SET support_count = (
    SELECT COUNT(*) FROM public.post_supports s WHERE s.post_id = p.id
  )
  WHERE p.id = decrement_post_support.post_id;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_post_support(BIGINT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.decrement_post_support(BIGINT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.increment_post_support(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decrement_post_support(BIGINT) TO authenticated;

-- Eski arşiv policy'si gönderi sahibinin (başkanın) support_count/quality_score
-- dahil her sütunu güncellemesine izin veriyordu; kodda doğrudan posts UPDATE
-- yok (gizleme set_post_status RPC'siyle yapılır).
DROP POLICY IF EXISTS posts_update ON public.posts;

-- Mevcut sayaçları bir kez gerçek değerle düzelt.
UPDATE public.posts p
SET support_count = sub.cnt
FROM (
  SELECT p2.id, COUNT(s.post_id) AS cnt
  FROM public.posts p2
  LEFT JOIN public.post_supports s ON s.post_id = p2.id
  GROUP BY p2.id
) sub
WHERE sub.id = p.id AND p.support_count IS DISTINCT FROM sub.cnt;

-- ── 4. Profiller yalnızca giriş yapmış kullanıcılara açık ─────────────────
DROP POLICY IF EXISTS profiles_select ON public.profiles;
CREATE POLICY profiles_select ON public.profiles
  FOR SELECT TO authenticated USING (true);

NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- DOĞRULAMA:
--   SELECT policyname, cmd, roles FROM pg_policies
--   WHERE tablename = 'profiles' AND cmd = 'SELECT';
--   -- roles yalnızca {authenticated} olmalı; başka bir SELECT policy'si
--   -- {public} ile görünüyorsa o da anon'a açıktır, kaldırılmalı.
--   SELECT tgname FROM pg_trigger WHERE tgname = 'profiles_guard_privileged';
-- ============================================================================
