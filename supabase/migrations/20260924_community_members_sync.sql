-- ============================================================================
-- NevGenç — Topluluk Üyelik Senkronizasyonu (2026-09-24)
-- ----------------------------------------------------------------------------
-- Bağlam: "Katıl" butonu artık community_members tablosuna gerçekten yazıyor
-- (bkz. lib/services/joined_communities_service.dart, joinCommunity/leaveCommunity).
-- Bu migration, member_count sayacının bu satırlarla her zaman tutarlı kalmasını
-- garanti altına alır — mevcut increment/decrement RPC'leri istemciden en iyi
-- çaba (best-effort) ile çağrılıyor ve ağ hatasında sessizce atlanabiliyordu;
-- burada eklenen trigger, gerçek satır sayısından yeniden hesaplayarak RPC'lerin
-- kaçırdığı durumları da telafi eder. İdempotent — tekrar çalıştırılabilir.
-- Supabase Dashboard → SQL Editor'da çalıştırın veya `supabase db push` kullanın.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.recompute_community_member_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  affected_community_id BIGINT;
BEGIN
  affected_community_id := COALESCE(NEW.community_id, OLD.community_id);
  UPDATE public.communities
  SET member_count = (
    SELECT COUNT(*) FROM public.community_members
    WHERE community_id = affected_community_id
  )
  WHERE id = affected_community_id;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS community_members_count_sync ON public.community_members;
CREATE TRIGGER community_members_count_sync
  AFTER INSERT OR DELETE ON public.community_members
  FOR EACH ROW EXECUTE FUNCTION public.recompute_community_member_count();

-- ── community_members RLS — üyelik senkronizasyonunun ve (ileride) başkan
-- üye listesinin çalışabilmesi için gerekli asgari politikalar ─────────────
ALTER TABLE public.community_members ENABLE ROW LEVEL SECURITY;

-- Herkes (kimliği doğrulanmış kullanıcı) üyelik satırlarını okuyabilir —
-- topluluk üye sayıları ve başkan panelindeki üye listesi buna dayanır.
DROP POLICY IF EXISTS community_members_select ON public.community_members;
CREATE POLICY community_members_select ON public.community_members
  FOR SELECT USING (auth.role() = 'authenticated');

-- Bir kullanıcı yalnızca kendi üyelik satırını ekleyebilir/silebilir.
DROP POLICY IF EXISTS community_members_insert_self ON public.community_members;
CREATE POLICY community_members_insert_self ON public.community_members
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS community_members_delete_self_or_chairman ON public.community_members;
CREATE POLICY community_members_delete_self_or_chairman ON public.community_members
  FOR DELETE USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.communities c
      WHERE c.id = community_members.community_id AND c.chairman_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- Bir kerelik veri düzeltmesi: bu migration çalıştırıldığı anda tüm
-- topluluklar için member_count'u gerçek satır sayısıyla senkronlar
-- (increment/decrement RPC'lerinin geçmişte kaçırmış olabileceği sapmaları giderir).
UPDATE public.communities c
SET member_count = (
  SELECT COUNT(*) FROM public.community_members m WHERE m.community_id = c.id
);
