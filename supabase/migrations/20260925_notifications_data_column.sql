-- ============================================================================
-- NevGenç — notifications.data sütunu eksikliği düzeltmesi (2026-09-25)
-- ----------------------------------------------------------------------------
-- Bağlam: lib/services/supabase_data_service.dart -> sendUpdateAnnouncement()
-- ve lib/screens/notification_center_screen.dart, bildirim satırlarında bir
-- `data` (jsonb) alanı bekliyor (versiyon/store_url/deep-link bilgisi
-- taşımak için) ama bu sütun şemada hiç yoktu — hem eski hem yeni projede
-- "Could not find the 'data' column of 'notifications'" hatasına yol
-- açıyordu (admin "Bildirimi Gönder" / sürüm duyurusu özelliği). İdempotent.
-- ============================================================================

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS data jsonb NOT NULL DEFAULT '{}'::jsonb;
