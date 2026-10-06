-- ============================================================================
-- NevGenç — Üyelik gizliliği ve bütünlük düzeltmeleri (2026-10-09)
-- Supabase Dashboard → SQL Editor'da çalıştırın. İdempotent; tek transaction
-- içinde çalışır, herhangi bir adım hata verirse hiçbir şey uygulanmaz.
--
-- Kapatılanlar (canlı pg_policies / pg_trigger çıktısıyla doğrulandı):
--  1. (ORTA) post_supports_own FOR ALL olduğundan kullanıcı kendi destek
--     satırının week_number'ını UPDATE edip haftalık 2 destek sınırını
--     aşabiliyordu (sınır tetikleyicisi yalnızca INSERT'te çalışır).
--  2. (ORTA) community_members / event_participants / event_registrations
--     giriş yapmış herkese açıktı: kimin hangi topluluğa üye olduğu ve hangi
--     etkinliğe katıldığı listelenebiliyordu.
--  3. (ORTA) Admin'in gizlediği gönderiler (status='hidden') API'den
--     okunabiliyordu; filtre yalnızca istemcideydi.
--  4. (ORTA) Başkan gönderi eklerken community_name / community_logo /
--     support_count / rating_* / created_at alanlarını kendisi belirliyordu.
--  5. (ORTA) profiles.profile_photo ve başkanın communities.logo_path alanına
--     herhangi bir URL yazılabiliyordu (liderlik tablosunda herkese yüklenir).
--  6. (DÜŞÜK) Kullanıcı kendine her rozeti ekleyebiliyordu.
--  7. (DÜŞÜK) Talep/şikayet metinlerinde uzunluk sınırı yoktu; oturum
--     gerektiren RPC'ler anon rolüne de açıktı.
--
-- İstemci değişikliği gerekmez; mağazadaki sürümler çalışmaya devam eder.
-- ============================================================================

BEGIN;

-- ── 1. post_supports: UPDATE yolu kapatılır ───────────────────────────────
DROP POLICY IF EXISTS post_supports_own ON public.post_supports;

DROP POLICY IF EXISTS post_supports_select_own ON public.post_supports;
CREATE POLICY post_supports_select_own ON public.post_supports
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS post_supports_insert_own ON public.post_supports;
CREATE POLICY post_supports_insert_own ON public.post_supports
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS post_supports_delete_own ON public.post_supports;
CREATE POLICY post_supports_delete_own ON public.post_supports
  FOR DELETE USING (auth.uid() = user_id);

-- ── 2. Üyelik / katılım listeleri: kendi satırın, o topluluğun başkanı, admin
-- Üye sayıları communities.member_count'tan okunur (SECURITY DEFINER
-- tetikleyici günceller), başkan listeleri RPC ile gelir; etkilenmezler.
DROP POLICY IF EXISTS community_members_select ON public.community_members;
CREATE POLICY community_members_select ON public.community_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.communities c
      WHERE c.id = community_members.community_id AND c.chairman_id = auth.uid()
    )
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

DROP POLICY IF EXISTS event_participants_select ON public.event_participants;
CREATE POLICY event_participants_select ON public.event_participants
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.posts po
      JOIN public.communities c ON c.id = po.community_id
      WHERE po.id = event_participants.post_id AND c.chairman_id = auth.uid()
    )
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

DROP POLICY IF EXISTS event_reg_select ON public.event_registrations;
CREATE POLICY event_reg_select ON public.event_registrations
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.events e
      JOIN public.communities c ON c.id = e.community_id
      WHERE e.id = event_registrations.event_id AND c.chairman_id = auth.uid()
    )
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- ── 3. Gizlenen gönderiler yalnızca admin ve o topluluğun başkanına görünür
DROP POLICY IF EXISTS posts_select ON public.posts;
CREATE POLICY posts_select ON public.posts
  FOR SELECT
  USING (
    status IS DISTINCT FROM 'hidden'
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
    OR EXISTS (
      SELECT 1 FROM public.communities c
      WHERE c.id = posts.community_id AND c.chairman_id = auth.uid()
    )
  );

-- ── 4. Gönderi eklerken türetilen/sayaç alanları sunucuda belirlenir ──────
-- SECURITY INVOKER (bilerek): REST istekleri 'authenticated'/'anon' ile gelir;
-- SQL Editor ve service_role muaftır (profiles_guard_privileged ile aynı desen).
-- Kimin gönderi atabileceğini trg_posts_leader_insert denetlemeye devam eder.
CREATE OR REPLACE FUNCTION public.posts_sanitize_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_name TEXT;
  v_logo TEXT;
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  SELECT c.name, c.logo_path INTO v_name, v_logo
  FROM public.communities c WHERE c.id = NEW.community_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Topluluk bulunamadı.' USING ERRCODE = '23503';
  END IF;

  NEW.community_name := v_name;
  NEW.community_logo := v_logo;
  NEW.support_count := 0;
  NEW.rating_avg := 0;
  NEW.rating_count := 0;
  NEW.quality_score := 0;
  NEW.status := 'published';
  NEW.created_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS posts_sanitize_insert ON public.posts;
CREATE TRIGGER posts_sanitize_insert
  BEFORE INSERT ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.posts_sanitize_insert();

-- ── 5a. profiles.profile_photo: yalnızca uygulamayla gelen görseller ──────
-- Profil fotoğrafı cihazda tutulur; güncel istemci bu sütuna yazmaz. Başka
-- bir değer (harici URL, cihaz yolu) sessizce boşaltılır. CHECK yerine
-- tetikleyici: eski sürümler bu sütunu diğer alanlarla birlikte gönderirse
-- güncellemenin tamamı reddedilmesin.
CREATE OR REPLACE FUNCTION public.profiles_sanitize_photo()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.profile_photo IS NOT NULL AND NOT starts_with(NEW.profile_photo, 'assets/') THEN
    NEW.profile_photo := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_sanitize_photo ON public.profiles;
CREATE TRIGGER profiles_sanitize_photo
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_sanitize_photo();

UPDATE public.profiles
SET profile_photo = NULL
WHERE profile_photo IS NOT NULL AND profile_photo NOT LIKE 'assets/%';

-- ── 5b. Başkan logoyu yalnızca uygulama görseli ya da kendi depolamamız
--    olarak ayarlayabilir (20261007'deki fonksiyonun üzerine logo kontrolü).
-- Proje taşınırsa aşağıdaki depolama adresi güncellenmelidir.
CREATE OR REPLACE FUNCTION public.communities_lock_chairman_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  ) THEN
    RETURN NEW;
  END IF;

  IF NEW.chairman_id IS DISTINCT FROM OLD.chairman_id THEN
    RAISE EXCEPTION 'Başkan ataması yalnızca admin tarafından değiştirilebilir.'
      USING ERRCODE = '42501';
  END IF;
  IF NEW.logo_path IS DISTINCT FROM OLD.logo_path
     AND NEW.logo_path IS NOT NULL
     AND NOT starts_with(NEW.logo_path, 'assets/')
     AND NOT starts_with(
       NEW.logo_path,
       'https://vvfdcxeewqcgbcpeabac.supabase.co/storage/v1/object/public/post-images/'
     )
  THEN
    RAISE EXCEPTION 'Logo yalnızca uygulamadan yüklenen bir görsel olabilir.'
      USING ERRCODE = '23514';
  END IF;
  NEW.score := OLD.score;
  NEW.member_count := OLD.member_count;
  NEW.category := OLD.category;
  RETURN NEW;
END;
$$;

-- ── 6. Rozet: kullanıcı kendine yalnızca kayıt rozetini ekleyebilir ───────
DROP POLICY IF EXISTS user_badges_insert ON public.user_badges;
CREATE POLICY user_badges_insert ON public.user_badges
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
    OR (
      auth.uid() = user_id
      AND badge_id IN (SELECT b.id FROM public.badges b WHERE b.name = 'İlk Adım')
    )
  );

-- ── 7a. Uzunluk sınırları ─────────────────────────────────────────────────
-- NOT VALID: mevcut satırlar taranmaz, yeni/güncellenen satırlara uygulanır.
ALTER TABLE public.user_tickets DROP CONSTRAINT IF EXISTS user_tickets_text_lengths;
ALTER TABLE public.user_tickets ADD CONSTRAINT user_tickets_text_lengths CHECK (
  char_length(subject) BETWEEN 1 AND 200
  AND char_length(description) BETWEEN 1 AND 5000
  AND (admin_notes IS NULL OR char_length(admin_notes) <= 5000)
) NOT VALID;

ALTER TABLE public.post_reports DROP CONSTRAINT IF EXISTS post_reports_reason_len;
ALTER TABLE public.post_reports ADD CONSTRAINT post_reports_reason_len
  CHECK (reason IS NULL OR char_length(reason) <= 1000) NOT VALID;

-- ── 7b. Oturum gerektiren RPC'ler anon rolüne kapatılır ───────────────────
-- Supabase, public şemasındaki fonksiyonlara anon için ayrıca EXECUTE verir;
-- yalnızca PUBLIC'ten REVOKE yetmez.
DO $$
DECLARE
  f RECORD;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace
      AND p.proname IN (
        'upsert_post_rating', 'report_post', 'set_post_status',
        'claim_coupon', 'get_user_claimed_coupons', 'delete_account'
      )
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f.sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f.sig);
  END LOOP;
END $$;

-- Günlük temizlik yalnızca pg_cron tarafından çalıştırılır.
DO $$
BEGIN
  IF to_regprocedure('public.cleanup_old_content()') IS NOT NULL THEN
    REVOKE EXECUTE ON FUNCTION public.cleanup_old_content() FROM PUBLIC, anon, authenticated;
  END IF;
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- DOĞRULAMA:
--   -- post_supports'ta cmd = ALL ya da UPDATE olan policy kalmamalı:
--   SELECT policyname, cmd FROM pg_policies WHERE tablename = 'post_supports';
--   -- İki tetikleyici de görünmeli:
--   SELECT tgname FROM pg_trigger
--   WHERE tgname IN ('posts_sanitize_insert', 'trg_posts_leader_insert');
--
-- UYGULAMADA DENEYİN:
--   Öğrenci : topluluğa katıl/ayrıl, gönderiye destek ver/geri al, puan ver,
--             şikayet et, etkinliğe katıl, kupon al.
--   Başkan  : gönderi at (görselli), üye listesi ve etkinlik katılımcıları,
--             Bilgiler sekmesinden logo değiştir.
--   Admin   : bir gönderiyi gizle → öğrenci hesabında akıştan kaybolmalı,
--             Şikayetler sekmesinde görünmeye devam etmeli.
-- ============================================================================
