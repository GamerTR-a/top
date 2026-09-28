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

-- NOT (2026-09-28 güncellemesi): rol sütununun WITH CHECK'te kilitlenmemesi
-- canlıda bir rol-yükseltme açığına yol açmıştı (bkz. 20260928_security_
-- hardening_v2.sql). Bu dosya tek başına yeniden çalıştırılırsa açığı geri
-- getirmesin diye kilit burada da uygulanıyor — 928 dosyasındaki tanımla
-- aynı olmalı.
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND role = (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid())
  );

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

-- ============================================================================
-- 5. Eksik RLS politikaları — güvenlik denetiminde bulundu (2026-09-24)
-- ----------------------------------------------------------------------------
-- Bu tablolarda ALTER ... ENABLE ROW LEVEL SECURITY çalıştırılmış olabilir
-- ama (hangi kurulum dosyasının canlıda çalıştığına bağlı olarak) hiç
-- policy tanımlanmamış olabilir — bu durumda Postgres varsayılanı
-- "hiç kimse erişemez" olur (anon/authenticated dahil), admin API/service
-- role hariç. Aşağıdaki politikalar supabase_schema.sql ile aynı sahiplik
-- kurallarını uygular ve idempotent'tir (tekrar çalıştırılabilir).
-- ============================================================================

-- community_members: giriş yapan herkes üyelik listesini görebilir,
-- yalnızca kendi üyeliğini ekleyip silebilir.
ALTER TABLE public.community_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS community_members_select ON public.community_members;
CREATE POLICY community_members_select ON public.community_members
  FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS community_members_insert_own ON public.community_members;
CREATE POLICY community_members_insert_own ON public.community_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS community_members_delete_own ON public.community_members;
CREATE POLICY community_members_delete_own ON public.community_members
  FOR DELETE USING (auth.uid() = user_id);

-- events: herkes okuyabilir, yalnızca admin yazabilir.
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS events_select ON public.events;
CREATE POLICY events_select ON public.events FOR SELECT USING (true);
DROP POLICY IF EXISTS events_write_admin ON public.events;
CREATE POLICY events_write_admin ON public.events FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- event_registrations: yalnızca sahibi kendi kaydını ekler/görür/siler.
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS event_reg_select ON public.event_registrations;
CREATE POLICY event_reg_select ON public.event_registrations
  FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS event_reg_insert_own ON public.event_registrations;
CREATE POLICY event_reg_insert_own ON public.event_registrations
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS event_reg_delete_own ON public.event_registrations;
CREATE POLICY event_reg_delete_own ON public.event_registrations
  FOR DELETE USING (auth.uid() = user_id);

-- calendar_notes: tamamen kişisel — yalnızca sahibi görür/ekler/siler.
ALTER TABLE public.calendar_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS calendar_select_own ON public.calendar_notes;
CREATE POLICY calendar_select_own ON public.calendar_notes
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS calendar_insert_own ON public.calendar_notes;
CREATE POLICY calendar_insert_own ON public.calendar_notes
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS calendar_delete_own ON public.calendar_notes;
CREATE POLICY calendar_delete_own ON public.calendar_notes
  FOR DELETE USING (auth.uid() = user_id);

-- notifications: yalnızca sahibi görür/günceller(okundu işaretler)/siler;
-- yalnızca admin (veya service_role ile çalışan send-notification Edge
-- Function) yeni bildirim ekleyebilir.
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
CREATE POLICY notifications_select_own ON public.notifications
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS notifications_update_own ON public.notifications;
CREATE POLICY notifications_update_own ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS notifications_delete_own ON public.notifications;
CREATE POLICY notifications_delete_own ON public.notifications
  FOR DELETE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS notifications_insert_admin ON public.notifications;
CREATE POLICY notifications_insert_admin ON public.notifications
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- discounts: herkes okuyabilir, yalnızca admin yazabilir.
ALTER TABLE public.discounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS discounts_select ON public.discounts;
CREATE POLICY discounts_select ON public.discounts FOR SELECT USING (true);
DROP POLICY IF EXISTS discounts_write_admin ON public.discounts;
CREATE POLICY discounts_write_admin ON public.discounts FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- badges: herkes görebilir (katalog).
ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS badges_select ON public.badges;
CREATE POLICY badges_select ON public.badges FOR SELECT USING (true);

-- user_badges: herkes görebilir (profil rozetleri herkese açık gösterilir);
-- yalnızca kendine veya admin başkasına rozet ekleyebilir.
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_badges_select ON public.user_badges;
CREATE POLICY user_badges_select ON public.user_badges FOR SELECT USING (true);
DROP POLICY IF EXISTS user_badges_insert ON public.user_badges;
CREATE POLICY user_badges_insert ON public.user_badges
  FOR INSERT WITH CHECK (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- post_ratings: yalnızca kendi verdiği puanı görebilir. INSERT/UPDATE
-- bilerek buraya EKLENMEDİ — puan verme yalnızca upsert_post_rating() RPC'si
-- (SECURITY DEFINER) üzerinden yapılır; bu RPC ortalama/XP güncellemesini de
-- atomik yapar, doğrudan tablo erişimiyle bu iş mantığı bypass edilebilir.
ALTER TABLE public.post_ratings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS post_ratings_select_own ON public.post_ratings;
CREATE POLICY post_ratings_select_own ON public.post_ratings
  FOR SELECT USING (auth.uid() = user_id);

-- post_reports: raporlama yalnızca report_post() RPC'si (SECURITY DEFINER)
-- üzerinden yapılır. Raporları görme/durum güncelleme yalnızca admin
-- panelinde kullanılıyor (bkz. getPostReports/updateReportStatus) — bu
-- yüzden SELECT/UPDATE admin ile sınırlandı.
ALTER TABLE public.post_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS post_reports_select_admin ON public.post_reports;
CREATE POLICY post_reports_select_admin ON public.post_reports
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );
DROP POLICY IF EXISTS post_reports_update_admin ON public.post_reports;
CREATE POLICY post_reports_update_admin ON public.post_reports
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- ── post-images Storage bucket: eksik UPDATE/DELETE policy'leri ────────────
-- Şu ana kadar yalnızca SELECT (public) + INSERT (authenticated) vardı;
-- kullanıcılar kendi yükledikleri görseli değiştiremiyor/silemiyordu.
DROP POLICY IF EXISTS post_images_owner_update ON storage.objects;
CREATE POLICY post_images_owner_update ON storage.objects FOR UPDATE
  USING (bucket_id = 'post-images' AND auth.uid() = owner)
  WITH CHECK (bucket_id = 'post-images' AND auth.uid() = owner);
DROP POLICY IF EXISTS post_images_owner_delete ON storage.objects;
CREATE POLICY post_images_owner_delete ON storage.objects FOR DELETE
  USING (bucket_id = 'post-images' AND auth.uid() = owner);

-- ============================================================================
-- DOĞRULAMA: Bu sorguyu çalıştırıp RLS açık ama policy sayısı 0 olan tablo
-- kalmadığından emin olun (boş sonuç dönmeli):
--
-- SELECT c.relname AS table_name
-- FROM pg_class c
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity = true
--   AND NOT EXISTS (
--     SELECT 1 FROM pg_policies p
--     WHERE p.schemaname = 'public' AND p.tablename = c.relname
--   );
-- ============================================================================
