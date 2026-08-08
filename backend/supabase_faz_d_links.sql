-- ============================================================================
-- NevGenç — Faz D: Topluluk Sohbetlerini Telegram/Discord'a Taşıma
-- ----------------------------------------------------------------------------
-- Amaç: Uygulama içi mesaj depolaması (community_messages) kapatılır; her
--       topluluğun harici sohbet grubu (Telegram / Discord) bağlantısı
--       community_links tablosunda tutulur. Böylece sunucu depolama maliyeti
--       sıfırlanır — sohbet artık ücretsiz harici platformlarda yürür.
--
-- Nasıl çalıştırılır: Supabase Dashboard → SQL Editor → bu dosyayı yapıştır → RUN.
-- Not: İlk migrasyonu (supabase_migration.sql) çalıştırdıysanız bu script onun
--      üzerine biner. current_user_role() yardımcı fonksiyonu korunur.
-- ============================================================================

-- 0) Yardımcı: kullanıcı rolü (ilk migrasyonda yoksa burada oluşur)
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM profiles WHERE id = auth.uid()
$$;

-- ----------------------------------------------------------------------------
-- 1) community_links — her topluluğun harici sohbet bağlantıları
--    • Her platform için tek satır (UNIQUE community_id + platform)
--    • Herkes okuyabilir; yalnızca o topluluğun başkanı veya admin yazabilir
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_links (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  community_id bigint NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  platform     text NOT NULL CHECK (platform IN ('telegram', 'discord')),
  url          text NOT NULL CHECK (url LIKE 'https://%'),
  label        text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (community_id, platform)
);

CREATE INDEX IF NOT EXISTS idx_community_links_community ON community_links(community_id);

ALTER TABLE community_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS community_links_public_select ON community_links;
CREATE POLICY community_links_public_select
  ON community_links FOR SELECT
  USING (true);

DROP POLICY IF EXISTS community_links_baskan_write ON community_links;
CREATE POLICY community_links_baskan_write
  ON community_links FOR ALL
  USING (
    public.current_user_role() = 'admin'
    OR (SELECT chairman_id::text FROM communities WHERE id = community_id) = auth.uid()::text
  )
  WITH CHECK (
    public.current_user_role() = 'admin'
    OR (SELECT chairman_id::text FROM communities WHERE id = community_id) = auth.uid()::text
  );

-- ----------------------------------------------------------------------------
-- 2) Eski mesaj depolama tablosu
--    ⚠️ SİLMEK İÇİN: Yayındaki eski uygulama sürümlerinin sohbeti bu tabloyu
--       kullanıyor. Tüm kullanıcıların yeni sürüme geçtiği varsayılınca şu satırı
--       aktif edin (depolama tamamen sıfırlanır):
--
--   -- DROP TABLE IF EXISTS community_messages;
--
--    Yeni sürüm bu tabloya hiç yazmaz/okumaz, bu yüzden şimdilik güvenle
--    bırakılabilir.
-- ============================================================================

-- Doğrulama:
--   SELECT * FROM community_links LIMIT 0;   (tablo var)
--   INSERT INTO community_links (community_id, platform, url)
--     VALUES (1, 'telegram', 'https://t.me/ornek')  (başkan hesabıyla dener)
-- ============================================================================
