-- ============================================================================
-- NevGenç — communities UPDATE "infinite recursion" düzeltmesi (2026-10-02)
-- İdempotent — birden fazla kez çalıştırılabilir.
--
-- SORUN: 20260930_communities_posts_rls_and_weekly_limit_fix.sql içindeki
-- communities_update_chairman policy'si WITH CHECK içinde yine
-- public.communities tablosunu sorguluyordu. Postgres bunu RLS özyinelemesi
-- sayar ve communities üzerindeki HER UPDATE (admin dahil) şu hatayla düşer:
--   42P17 infinite recursion detected in policy for relation "communities"
-- Etkilenenler: admin başkan atama/kaldırma, topluluk bilgisi düzenleme,
-- increment/decrement_community_member RPC'leri.
--
-- ÇÖZÜM: Policy yalnızca "kendi topluluğun" kontrolünü yapar; chairman_id /
-- chairman_name kilidi (başkan kendini değiştiremesin / devredemesin) bir
-- BEFORE UPDATE trigger'ına taşınır — trigger OLD/NEW'i doğrudan görür,
-- tabloyu yeniden sorgulamaz.
-- ============================================================================

-- ── 1. Özyinelemesiz başkan UPDATE policy'si ───────────────────────────────
DROP POLICY IF EXISTS communities_update_chairman ON public.communities;
CREATE POLICY communities_update_chairman ON public.communities
  FOR UPDATE
  USING (chairman_id = auth.uid())
  WITH CHECK (chairman_id = auth.uid());

-- ── 2. chairman_id / chairman_name yalnızca admin tarafından değişebilir ──
-- auth.uid() NULL ise çağrı SQL Editor / service_role'dendir → serbest.
CREATE OR REPLACE FUNCTION public.communities_lock_chairman_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (NEW.chairman_id IS DISTINCT FROM OLD.chairman_id
      OR NEW.chairman_name IS DISTINCT FROM OLD.chairman_name)
     AND auth.uid() IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
     )
  THEN
    RAISE EXCEPTION 'Başkan bilgisi yalnızca admin tarafından değiştirilebilir.'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS communities_lock_chairman ON public.communities;
CREATE TRIGGER communities_lock_chairman
  BEFORE UPDATE ON public.communities
  FOR EACH ROW EXECUTE FUNCTION public.communities_lock_chairman_fields();

-- ── 3. Üye sayacı RPC'leri: sayacı +1/-1 yapmak yerine gerçek satır
--    sayısından yeniden hesapla ─────────────────────────────────────────────
-- community_members_count_sync trigger'ı (20260924) sayacı zaten her
-- katıl/ayrıl işleminde yeniden hesaplıyor; eski +1/-1 RPC'leri üstüne bir
-- kez daha ekleyip sayacı şişirirdi. Mağazadaki eski sürümler bu RPC'leri
-- hâlâ çağırdığı için silinmiyor, zararsız (idempotent) hâle getiriliyor.
CREATE OR REPLACE FUNCTION public.increment_community_member(community_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  UPDATE public.communities c
  SET member_count = (
    SELECT COUNT(*) FROM public.community_members m
    WHERE m.community_id = increment_community_member.community_id
  )
  WHERE c.id = increment_community_member.community_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_community_member(community_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  UPDATE public.communities c
  SET member_count = (
    SELECT COUNT(*) FROM public.community_members m
    WHERE m.community_id = decrement_community_member.community_id
  )
  WHERE c.id = decrement_community_member.community_id;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_community_member(BIGINT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.decrement_community_member(BIGINT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.increment_community_member(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decrement_community_member(BIGINT) TO authenticated;

-- ── 4. Olası kaymış sayaçları bir kez gerçek değerle düzelt ───────────────
UPDATE public.communities c
SET member_count = sub.cnt
FROM (
  SELECT c2.id, COUNT(m.user_id) AS cnt
  FROM public.communities c2
  LEFT JOIN public.community_members m ON m.community_id = c2.id
  GROUP BY c2.id
) sub
WHERE sub.id = c.id AND c.member_count IS DISTINCT FROM sub.cnt;

NOTIFY pgrst, 'reload schema';
