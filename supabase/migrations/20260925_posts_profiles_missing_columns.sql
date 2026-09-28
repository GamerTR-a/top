-- ============================================================================
-- NevGenç — posts/profiles eksik sütun denetimi (2026-09-25, devam)
-- ----------------------------------------------------------------------------
-- Bağlam: Görsel şema/kod karşılaştırması OpenAPI (PostgREST) tanımları
-- üzerinden birebir tekrarlandı. Bulunanlar (hiçbir schema dosyasında
-- tanımlı değildi, sadece Dart kodunda vardı — eski projede de eksikti):
-- ============================================================================

-- posts.is_event: create_post_screen.dart "Etkinlik Katılım Butonu Ekle"
-- switch'i her zaman gönderiyor (createPost -> 'is_event': isEvent), sütun
-- hiç yoktu → "PostgrestException ... 'is_event' column" hatası veriyordu.
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_event boolean NOT NULL DEFAULT false;

-- profiles.birth_date: kayıt formunda opsiyonel doğum tarihi alanı
-- (supabase_auth_service.dart _insertProfile) — sütun hiç yoktu, doğum
-- tarihi giren her yeni kullanıcı kaydı hata alıyordu. Serbest metin
-- olarak saklanıyor (uygulama gerçek DATE tipi olarak parse etmiyor).
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS birth_date text;

-- profiles.department: supabase_schema.sql TEXT[] (çoklu seçim) olarak
-- tasarlanmıştı ama canlı DB'de düz TEXT idi; kod her zaman bir Dart
-- List<String> gönderiyor (_insertProfile -> deptArray). Var olan
-- (muhtemelen tek bölüm içeren) metin değerleri diziye çevrilerek taşınır.
-- NOT: 20260529_security_constraints.sql'deki profiles_dept_len (char_length
-- tabanlı) kısıtı TEXT[] ile uyumsuz olduğundan önce kaldırılır.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_dept_len;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='department' AND data_type <> 'ARRAY'
  ) THEN
    ALTER TABLE public.profiles ALTER COLUMN department TYPE TEXT[] USING CASE
      WHEN department IS NULL OR department = '' THEN NULL
      ELSE ARRAY[department]
    END;
  END IF;
END $$;
