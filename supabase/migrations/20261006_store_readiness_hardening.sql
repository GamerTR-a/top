-- ============================================================================
-- NevGenç — Mağaza öncesi sertleştirme (2026-10-06)
-- Supabase Dashboard → SQL Editor'da çalıştırın. İdempotent; tek transaction
-- içinde çalışır, herhangi bir adım hata verirse hiçbir şey uygulanmaz.
--
-- Kapatılanlar:
--  1. (YÜKSEK) .edu / .edu.tr kısıtı yalnızca istemcideydi; Auth API'ye
--     doğrudan istekle herhangi bir e-postayla hesap açılabiliyordu.
--  2. (ORTA) profiles.birth_date her giriş yapmış kullanıcıya açıktı. Doğum
--     tarihi artık yalnızca sahibinin okuyabildiği auth user_metadata'da.
--  3. (ORTA) anon, post-images bucket'ının içeriğini listeleyebiliyordu
--     (klasör adları kullanıcı kimlikleri).
--  4. (ÖLÇEK) sık kullanılan sorgular için eksik indeksler.
--
-- SIRA: 2. madde, doğum tarihini auth metadata'dan okuyan uygulama sürümüyle
-- (1.0.29+30 sonrası) birlikte anlamlıdır. Eski sürümler bu SQL'den sonra
-- kendi profilinde doğum tarihini boş/varsayılan görür; başka etkisi yoktur.
-- ============================================================================

BEGIN;

-- ── 1. Kayıt e-postası sunucuda da .edu / .edu.tr olmalı ──────────────────
-- İstisnalar (mağaza inceleme hesabı, admin vb.) için izin listesi. Yalnızca
-- SQL Editor / service_role erişir:
--   INSERT INTO public.signup_email_allowlist (email) VALUES ('ornek@gmail.com');
CREATE TABLE IF NOT EXISTS public.signup_email_allowlist (
  email      TEXT PRIMARY KEY CHECK (email = lower(email)),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.signup_email_allowlist ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.signup_email_allowlist FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.enforce_edu_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email TEXT := lower(NEW.email);
BEGIN
  IF v_email IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND v_email IS NOT DISTINCT FROM lower(OLD.email) THEN
    RETURN NEW;
  END IF;
  IF v_email ~ '^[^@\s]+@[^@\s]+\.edu(\.tr)?$' THEN
    RETURN NEW;
  END IF;
  IF EXISTS (SELECT 1 FROM public.signup_email_allowlist a WHERE a.email = v_email) THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'edu_email_required' USING ERRCODE = '23514';
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_edu_email() FROM PUBLIC, anon, authenticated;

-- UPDATE OF email: .edu ile kaydolup e-postayı sonradan değiştirmeyi de kapatır.
-- Mevcut .edu dışı hesaplar etkilenmez (e-postalarını değiştirmedikçe).
DROP TRIGGER IF EXISTS enforce_edu_email ON auth.users;
CREATE TRIGGER enforce_edu_email
  BEFORE INSERT OR UPDATE OF email ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.enforce_edu_email();

-- ── 2. Doğum tarihi profiles'tan auth user_metadata'ya taşınır ────────────
UPDATE auth.users u
SET raw_user_meta_data =
      COALESCE(u.raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('birth_date', p.birth_date)
FROM public.profiles p
WHERE p.id = u.id
  AND p.birth_date IS NOT NULL
  AND btrim(p.birth_date) <> ''
  AND NOT (COALESCE(u.raw_user_meta_data, '{}'::jsonb) ? 'birth_date');

UPDATE public.profiles SET birth_date = NULL WHERE birth_date IS NOT NULL;

-- Eski uygulama sürümleri kayıt/ilk girişte sütunu yeniden dolduramasın.
-- (SQL Editor ve service_role muaf — profiles_guard_privileged ile aynı desen.)
CREATE OR REPLACE FUNCTION public.profiles_strip_birth_date()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF current_user IN ('authenticated', 'anon') THEN
    NEW.birth_date := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_strip_birth_date ON public.profiles;
CREATE TRIGGER profiles_strip_birth_date
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_strip_birth_date();

-- ── 3. post-images: listeleme kapatılır ───────────────────────────────────
-- Bucket public olduğu için görsel URL'leri (/object/public/...) SELECT
-- policy'si olmadan çalışmaya devam eder; policy yalnızca listeleme/arama
-- API'sini açıyordu. Canlıdaki policy adı bilinmediğinden, post-images'e
-- dokunan (ya da koşulsuz `true` olan) tüm SELECT policy'leri kaldırılıp
-- yerine "yalnızca kendi klasörün" policy'si konur. Yazma/silme policy'lerine
-- dokunulmaz. Projede başka bucket varsa ve herkese açık listeleme
-- gerekiyorsa bu bloğu çalıştırmadan önce gözden geçirin.
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND cmd = 'SELECT'
      AND (qual ILIKE '%post-images%' OR btrim(qual) = 'true')
  LOOP
    EXECUTE format('DROP POLICY %I ON storage.objects', pol.policyname);
    RAISE NOTICE 'Kaldırılan storage policy: %', pol.policyname;
  END LOOP;
END $$;

DROP POLICY IF EXISTS post_images_owner_select ON storage.objects;
CREATE POLICY post_images_owner_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'post-images'
    AND (storage.foldername(name))[1] = 'posts'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- ── 4. İndeksler ──────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_community ON public.posts (community_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_members_user ON public.community_members (user_id);
CREATE INDEX IF NOT EXISTS idx_community_members_community
  ON public.community_members (community_id);
CREATE INDEX IF NOT EXISTS idx_post_supports_post ON public.post_supports (post_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_user
  ON public.event_registrations (user_id);
CREATE INDEX IF NOT EXISTS idx_post_reports_status ON public.post_reports (status);
CREATE INDEX IF NOT EXISTS idx_community_notifications_sender_created
  ON public.community_notifications (sender_id, created_at DESC);

COMMIT;

NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- DOĞRULAMA:
--   -- 1) .edu dışı kayıt reddedilmeli (hata: edu_email_required). Dashboard →
--   --    Authentication → Add user ile bir gmail adresi deneyin.
--   SELECT tgname FROM pg_trigger WHERE tgname = 'enforce_edu_email';
--   -- 2) Sütun boş, veri metadata'da:
--   SELECT count(*) FROM public.profiles WHERE birth_date IS NOT NULL;  -- 0
--   SELECT count(*) FROM auth.users WHERE raw_user_meta_data ? 'birth_date';
--   -- 3) Yalnızca post_images_owner_select kalmalı:
--   SELECT policyname, cmd, roles FROM pg_policies
--   WHERE schemaname='storage' AND tablename='objects' AND cmd='SELECT';
--   --    Uygulamada: mevcut gönderi görselleri görünmeye, yeni görsel
--   --    yükleme çalışmaya devam etmeli.
-- ============================================================================
