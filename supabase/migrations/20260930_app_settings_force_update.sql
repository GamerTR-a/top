-- ============================================================================
-- NevGenç — app_settings tablosu (zorunlu güncelleme mekanizması)
-- ----------------------------------------------------------------------------
-- kontrol.md Bölüm 31.6: kritik bir güvenlik açığı çıktığında eski sürümdeki
-- kullanıcıları güncellemeye zorlayacak bir mekanizma yoktu. Bu tablo,
-- istemcinin (lib/services/force_update_service.dart) açılışta okuduğu basit
-- bir anahtar/değer ayar deposu. Supabase Dashboard → SQL Editor'da çalıştırın.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.app_settings (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_settings_select ON public.app_settings;
CREATE POLICY app_settings_select ON public.app_settings FOR SELECT USING (true);

DROP POLICY IF EXISTS app_settings_write_admin ON public.app_settings;
CREATE POLICY app_settings_write_admin ON public.app_settings FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- Başlangıç değerleri: 0 = hiçbir sürüm bloklanmaz (mağazada hâlâ build 26
-- olabilir; 27 yazmak onları kapatılamayan güncelleme ekranına kilitlerdi). İleride
-- kritik bir düzeltme yayınlandığında admin bu değeri yeni build numarasına
-- yükselterek eski sürümleri devre dışı bırakabilir:
--   UPDATE public.app_settings SET value = '<yeni_build_numarası>'
--   WHERE key = 'min_supported_android_build';
INSERT INTO public.app_settings (key, value) VALUES
  ('min_supported_android_build', '0'),
  ('min_supported_ios_build', '0'),
  ('android_store_url', 'https://play.google.com/store/apps/details?id=com.Nevgenc'),
  ('ios_store_url', '')
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- Doğrulama:
--   SELECT * FROM public.app_settings ORDER BY key;
-- ============================================================================
