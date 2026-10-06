-- ============================================================================
-- NevGenç — Başkanın topluluk bilgisi düzenlemesi, SOSYO metinleri, kampüs
-- noktaları (2026-10-07)
-- Supabase Dashboard → SQL Editor'da çalıştırın. İdempotent; tek transaction.
--
--  1. communities: kısaltma + iletişim sütunları.
--  2. Başkan kendi topluluğunda ad, kısaltma, tanıtım, logo, başkan adı ve
--     iletişim bilgilerini düzenleyebilir; chairman_id, score, member_count
--     ve category yalnızca admin tarafından değişir. (Önceden başkan adı
--     kilitliydi, score/member_count ise başkana açıktı.)
--  3. community_links: yeni platformlar (whatsapp, instagram, x, linkedin,
--     youtube, website) kabul edilir.
--  4. campus_pois: admin panelinden eklenen Kampüs Cepte noktaları.
-- SOSYO metinleri mevcut app_settings tablosunda tutulur (sosyo_description,
-- sosyo_about); yeni tablo/policy gerekmez.
-- ============================================================================

BEGIN;

-- ── 1. communities: yeni sütunlar ─────────────────────────────────────────
ALTER TABLE public.communities ADD COLUMN IF NOT EXISTS short_name TEXT;
ALTER TABLE public.communities ADD COLUMN IF NOT EXISTS contact_email TEXT;
ALTER TABLE public.communities ADD COLUMN IF NOT EXISTS contact_phone TEXT;

ALTER TABLE public.communities DROP CONSTRAINT IF EXISTS communities_text_lengths;
ALTER TABLE public.communities ADD CONSTRAINT communities_text_lengths CHECK (
  char_length(name) BETWEEN 2 AND 120
  AND (short_name IS NULL OR char_length(short_name) <= 20)
  AND (description IS NULL OR char_length(description) <= 1000)
  AND (chairman_name IS NULL OR char_length(chairman_name) <= 80)
  AND (contact_email IS NULL OR char_length(contact_email) <= 120)
  AND (contact_phone IS NULL OR char_length(contact_phone) <= 30)
) NOT VALID;

-- ── 2. Başkanın değiştiremeyeceği alanlar ─────────────────────────────────
-- SECURITY INVOKER (bilerek): current_user çağıranın rolünü gösterir. REST
-- istekleri 'authenticated'/'anon' ile gelir; üye sayacını güncelleyen
-- SECURITY DEFINER trigger/RPC'ler, SQL Editor ve service_role muaftır.
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
  NEW.score := OLD.score;
  NEW.member_count := OLD.member_count;
  NEW.category := OLD.category;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS communities_lock_chairman ON public.communities;
CREATE TRIGGER communities_lock_chairman
  BEFORE UPDATE ON public.communities
  FOR EACH ROW EXECUTE FUNCTION public.communities_lock_chairman_fields();

-- ── 3. community_links: platform listesi genişler ─────────────────────────
-- Eski şema platformu ('telegram','discord') ile sınırlıyordu; kısıtın canlı
-- adı bilinmediğinden platform sütununa dokunan tüm CHECK'ler kaldırılır.
DO $$
DECLARE
  con RECORD;
BEGIN
  FOR con IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.community_links'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%platform%'
  LOOP
    EXECUTE format('ALTER TABLE public.community_links DROP CONSTRAINT %I', con.conname);
  END LOOP;
END $$;

ALTER TABLE public.community_links ADD CONSTRAINT community_links_platform_check CHECK (
  platform IN ('telegram', 'discord', 'whatsapp', 'instagram', 'x', 'linkedin', 'youtube', 'website')
);

-- ── 4. campus_pois: admin'in eklediği harita noktaları ────────────────────
CREATE TABLE IF NOT EXISTS public.campus_pois (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        TEXT NOT NULL CHECK (char_length(name) BETWEEN 2 AND 120),
  category    TEXT NOT NULL CHECK (category IN (
                'dormitory', 'busStop', 'wifi', 'study', 'faculty', 'food',
                'health', 'market', 'sport', 'park', 'worship', 'finance', 'culture'
              )),
  lat         DOUBLE PRECISION NOT NULL CHECK (lat BETWEEN 40.5 AND 41.1),
  lng         DOUBLE PRECISION NOT NULL CHECK (lng BETWEEN 29.9 AND 30.8),
  description TEXT NOT NULL DEFAULT '' CHECK (char_length(description) <= 300),
  address     TEXT NOT NULL DEFAULT '' CHECK (char_length(address) <= 200),
  created_by  UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.campus_pois ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS campus_pois_select ON public.campus_pois;
CREATE POLICY campus_pois_select ON public.campus_pois FOR SELECT USING (true);

DROP POLICY IF EXISTS campus_pois_write_admin ON public.campus_pois;
CREATE POLICY campus_pois_write_admin ON public.campus_pois FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

COMMIT;

NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- DOĞRULAMA:
--   SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'communities' AND column_name IN ('short_name','contact_email','contact_phone');
--   SELECT pg_get_constraintdef(oid) FROM pg_constraint
--   WHERE conrelid = 'public.community_links'::regclass AND contype = 'c';
--   -- Başkan hesabıyla: topluluk adı/tanıtımı kaydedilebilmeli; üye katıl/ayrıl
--   -- sonrası member_count güncellenmeye devam etmeli.
-- ============================================================================
