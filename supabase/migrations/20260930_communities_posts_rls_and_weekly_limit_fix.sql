-- ============================================================================
-- NevGenç — communities/community_links RLS eksikliği + haftalık destek limiti
-- istemci-saati bypass'ı düzeltmesi (2026-09-30)
-- ----------------------------------------------------------------------------
-- Bu dosya, kontrol.md denetiminde bulunan iki bulguyu kapatır. Supabase
-- Dashboard → SQL Editor'da çalıştırın veya `supabase db push` kullanın.
-- Her blok idempotent'tir (tekrar çalıştırılabilir).
--
-- Bulgu 1 (KRİTİK — yetki ele geçirme): public.communities ve
-- public.community_links tabloları hiçbir migration'da RLS'lenmemişti.
-- lib/services/supabase_data_service.dart içindeki updateCommunity/
-- assignChairman/removeChairman/setCommunityLink fonksiyonları doğrudan
-- .update()/.upsert() çağırıyor, RPC/sunucu kontrolü yok — RLS kapalıysa
-- ve authenticated role'e tablo GRANT'ları açıksa herhangi bir öğrenci
-- REST API'ye PATCH isteğiyle chairman_id'yi kendine çevirip bir topluluğun
-- başkanlığını ele geçirebilirdi. Ayrıca posts tablosunda UPDATE/DELETE
-- policy'si hiç yoktu (deletePost() canlıda sessizce başarısız oluyordu).
--
-- Bulgu 2 (YÜKSEK — haftalık destek limiti bypass'ı): check_weekly_support_
-- limit() trigger'ı istemcinin INSERT ile birlikte gönderdiği week_number/
-- year alanlarına güveniyordu (NOW()'dan hesaplamıyordu). Kötü niyetli bir
-- kullanıcı sahte hafta/yıl değerleri göndererek haftalık 2 destek sınırını
-- tamamen atlayıp sınırsız puan/liderlik manipülasyonu yapabilirdi.
-- ============================================================================

-- ── 1. communities: herkes okur; admin her şeyi yazar; başkan yalnızca
--    KENDİ topluluğunun ad/açıklama/kategori/logo alanlarını günceller
--    (chairman_id/chairman_name başkan tarafından değiştirilemez — bu ikisi
--    yalnızca admin'in assignChairman/removeChairman akışıyla değişir) ────
ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS communities_select ON public.communities;
CREATE POLICY communities_select ON public.communities FOR SELECT USING (true);

DROP POLICY IF EXISTS communities_write_admin ON public.communities;
CREATE POLICY communities_write_admin ON public.communities FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

DROP POLICY IF EXISTS communities_update_chairman ON public.communities;
CREATE POLICY communities_update_chairman ON public.communities
  FOR UPDATE
  USING (chairman_id = auth.uid())
  -- NOT: önceki sürüm burada communities'i yeniden sorguluyordu → 42P17
  -- infinite recursion. chairman_id/chairman_name kilidi artık trigger'da
  -- (bkz. 20261002_fix_communities_rls_recursion.sql).
  WITH CHECK (chairman_id = auth.uid());

-- ── 2. community_links: herkes okur; admin veya ilgili topluluğun başkanı
--    yazar (setCommunityLink/updateCommunityLinks/removeCommunityLink şu an
--    yalnızca baskan_panel_screen.dart'tan çağrılıyor) ──────────────────────
ALTER TABLE public.community_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS community_links_select ON public.community_links;
CREATE POLICY community_links_select ON public.community_links FOR SELECT USING (true);

DROP POLICY IF EXISTS community_links_write ON public.community_links;
CREATE POLICY community_links_write ON public.community_links FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
    OR EXISTS (SELECT 1 FROM public.communities c WHERE c.id = community_links.community_id AND c.chairman_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
    OR EXISTS (SELECT 1 FROM public.communities c WHERE c.id = community_links.community_id AND c.chairman_id = auth.uid())
  );

-- ── 3. posts: DELETE policy'si hiç yoktu (deletePost() admin_screen.dart ve
--    baskan_panel_screen.dart'tan çağrılıyor) — admin her gönderiyi, başkan
--    yalnızca KENDİ topluluğunun gönderilerini silebilir. UPDATE policy'si
--    bilerek eklenmiyor: kalite/puan güncellemeleri yalnızca
--    update_post_quality() gibi SECURITY DEFINER RPC'ler üzerinden yapılıyor,
--    doğrudan .from('posts').update() çağrısı kod tabanında yok. ───────────
DROP POLICY IF EXISTS posts_delete ON public.posts;
CREATE POLICY posts_delete ON public.posts FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
    OR EXISTS (
      SELECT 1 FROM public.communities c
      WHERE c.id = posts.community_id AND c.chairman_id = auth.uid()
    )
  );

-- ── 4. Haftalık destek limiti: istemciden gelen week_number/year yerine
--    sunucu saatinden hesaplanan değeri kullan; istemcinin gönderdiği değer
--    ne olursa olsun sessizce üzerine yazılır. Client'ın kendi hesabıyla
--    (_isoWeek + now.year) aynı algoritma kullanılıyor (ISO hafta + takvim
--    yılı) ki getSupportStatus()'un client-side sorgusu tutarlı kalsın. ────
CREATE OR REPLACE FUNCTION public.check_weekly_support_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  srv_week INTEGER := EXTRACT(WEEK FROM NOW())::INTEGER;
  srv_year INTEGER := EXTRACT(YEAR FROM NOW())::INTEGER;
BEGIN
  NEW.week_number := srv_week;
  NEW.year := srv_year;

  IF (
    SELECT COUNT(*) FROM public.post_supports
    WHERE user_id = NEW.user_id
      AND week_number = srv_week
      AND year = srv_year
  ) >= 2 THEN
    RAISE EXCEPTION 'weekly_limit_exceeded'
      USING HINT = 'Haftalık destek hakkınız doldu (2/2).';
  END IF;
  RETURN NEW;
END;
$$;

-- Trigger zaten enforce_weekly_limit adıyla var (20260529_security_
-- constraints.sql), fonksiyon değiştiği için yeniden bağlamaya gerek yok
-- (CREATE OR REPLACE FUNCTION mevcut trigger'ı otomatik günceller) ama
-- idempotentlik için yine de yeniden oluşturuyoruz:
DROP TRIGGER IF EXISTS enforce_weekly_limit ON public.post_supports;
CREATE TRIGGER enforce_weekly_limit
  BEFORE INSERT ON public.post_supports
  FOR EACH ROW EXECUTE FUNCTION public.check_weekly_support_limit();

-- ============================================================================
-- Doğrulama (Supabase Dashboard → SQL Editor'da çalıştırın):
--
-- 1) RLS artık aktif mi:
--    SELECT relname, relrowsecurity FROM pg_class
--    WHERE relname IN ('communities','community_links') AND relnamespace='public'::regnamespace;
--    -- İkisi de relrowsecurity = true dönmeli.
--
-- 2) Policy'ler oluştu mu:
--    SELECT tablename, policyname, cmd FROM pg_policies
--    WHERE tablename IN ('communities','community_links','posts');
--    -- posts için 'posts_delete' (cmd=DELETE) görünmeli.
--
-- 3) Trigger sunucu saatini kullanıyor mu (fonksiyon tanımını gözle kontrol):
--    SELECT prosrc FROM pg_proc WHERE proname = 'check_weekly_support_limit';
--    -- İçinde "EXTRACT(WEEK FROM NOW())" görünmeli, "NEW.week_number" ile
--    -- karşılaştırma OLMAMALI.
-- ============================================================================
