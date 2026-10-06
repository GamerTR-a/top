-- ============================================================================
-- NevGenç — Kampüs Bilgi Yarışması soruları (2026-10-08)
-- Supabase Dashboard → SQL Editor'da çalıştırın. İdempotent.
--
-- Admin panelinden eklenen sorular burada tutulur; uygulamayla gelen gömülü
-- sorulara eklenir. Bu tablo olmadan da oyun gömülü sorularla çalışır.
-- Doğru şık istemciye açıktır (skor yalnızca cihazda tutulur, ödül/XP yok).
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.quiz_questions (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  question      TEXT NOT NULL CHECK (char_length(question) BETWEEN 5 AND 300),
  options       TEXT[] NOT NULL CHECK (array_length(options, 1) = 4),
  correct_index SMALLINT NOT NULL CHECK (correct_index BETWEEN 0 AND 3),
  category      TEXT NOT NULL DEFAULT 'Genel Kültür' CHECK (char_length(category) <= 40),
  created_by    UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS quiz_questions_select ON public.quiz_questions;
CREATE POLICY quiz_questions_select ON public.quiz_questions
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS quiz_questions_write_admin ON public.quiz_questions;
CREATE POLICY quiz_questions_write_admin ON public.quiz_questions FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

NOTIFY pgrst, 'reload schema';
