-- ============================================================================
-- NevGenç — İçerik saklama/temizlik politikası (2026-09-27)
-- ----------------------------------------------------------------------------
-- Bağlam: Supabase veritabanının gereksiz yere büyümemesi için, kullanıcıyla
-- birlikte kararlaştırılan saklama süreleri sonunda otomatik (pg_cron ile
-- günlük) silme uygulanır:
--   - posts (topluluk gönderileri)........... 30 gün
--   - notifications (type='announcement')..... 1 gün
--   - user_tickets (şikayet/talep)............ 7 gün
--   - job_listings (iş ilanları).............. 14 gün
--   - news_bulletins (haber bülteni).......... 7 gün
-- Bildirimlerin geneli (announcement DIŞINDAKİ tipler) kasıtlı olarak bu
-- otomasyona DAHİL EDİLMEDİ — kullanıcı tercihi: manuel temizlik
-- (bkz. NotificationCenterScreen > Ayarlar > "Okunmuş Bildirimleri Temizle")
-- olduğu gibi kalsın.
--
-- community_messages tablosu artık hiçbir yerden yazılmıyor/okunmuyor
-- (topluluk sohbeti Telegram/Discord derin linklerine taşındı — "Faz D").
-- Kullanıcı kararı: tablo tamamen kaldırılsın.
--
-- İdempotent — birden fazla kez çalıştırılabilir.
-- ============================================================================

-- ── 1. Kullanılmayan community_messages tablosunu kaldır ───────────────────
DROP TABLE IF EXISTS public.community_messages CASCADE;

-- ── 2. Günlük temizlik fonksiyonu ───────────────────────────────────────────
-- Her tablo kendi BEGIN/EXCEPTION bloğunda çalışır — biri beklenmedik bir
-- hatayla karşılaşırsa (ör. ileride eklenecek, CASCADE'siz yeni bir FK)
-- yalnızca o tablonun temizliği o gün atlanır, diğerleri etkilenmez ve
-- Postgres loglarına uyarı düşer (pg_cron sessizce tüm işi iptal etmez).
CREATE OR REPLACE FUNCTION public.cleanup_old_content()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Topluluk gönderileri (destek/puan/rapor/etkinlik-katılımcı satırları
  -- CASCADE ile birlikte otomatik silinir — post_supports/post_ratings/
  -- post_reports/event_participants tümü posts(id) ON DELETE CASCADE).
  BEGIN
    DELETE FROM public.posts WHERE created_at < NOW() - INTERVAL '30 days';
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[cleanup_old_content] posts temizliği başarısız: %', SQLERRM;
  END;

  -- Yalnızca admin "güncelleme duyurusu" bildirimleri (type='announcement').
  -- Diğer bildirim tipleri (community, badge_earned, event_reminder, vb.)
  -- bilinçli olarak dokunulmadan bırakılır — kullanıcı tercihi.
  BEGIN
    DELETE FROM public.notifications
    WHERE type = 'announcement' AND created_at < NOW() - INTERVAL '1 day';
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[cleanup_old_content] notifications temizliği başarısız: %', SQLERRM;
  END;

  BEGIN
    DELETE FROM public.user_tickets WHERE created_at < NOW() - INTERVAL '7 days';
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[cleanup_old_content] user_tickets temizliği başarısız: %', SQLERRM;
  END;

  BEGIN
    DELETE FROM public.job_listings WHERE created_at < NOW() - INTERVAL '14 days';
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[cleanup_old_content] job_listings temizliği başarısız: %', SQLERRM;
  END;

  BEGIN
    DELETE FROM public.news_bulletins WHERE created_at < NOW() - INTERVAL '7 days';
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[cleanup_old_content] news_bulletins temizliği başarısız: %', SQLERRM;
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.cleanup_old_content() FROM public;

-- ── 3. pg_cron ile günlük otomatik çalıştırma (her gün 03:00 UTC) ─────────
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'nevgenc-daily-content-cleanup') THEN
    PERFORM cron.unschedule('nevgenc-daily-content-cleanup');
  END IF;
  PERFORM cron.schedule(
    'nevgenc-daily-content-cleanup',
    '0 3 * * *',
    $cron$SELECT public.cleanup_old_content();$cron$
  );
END $$;
