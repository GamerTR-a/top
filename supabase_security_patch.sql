-- ============================================================
-- NevGenç — Güvenlik Yaması v1
-- Mevcut Supabase kurulumunda Supabase SQL Editor'da çalıştırın.
-- ============================================================

-- ── 1. Profil ekleme: zorunlu olarak role='student' ──────────
DROP POLICY IF EXISTS "profiles_insert" ON public.profiles;
CREATE POLICY "profiles_insert" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id AND role = 'student');

-- ── 2. Profil güncelleme: rol değişikliğini engelle ──────────
--    Kullanıcı kendi profilini güncelleyebilir ama rolünü değiştiremez.
--    Admin her profili (rol dahil) güncelleyebilir.
DROP POLICY IF EXISTS "profiles_update"       ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own"   ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON public.profiles;

CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id AND
    role = (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid())
  );

CREATE POLICY "profiles_update_admin" ON public.profiles
  FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- ── 3. Admin kullanıcı silebilir ─────────────────────────────
DROP POLICY IF EXISTS "profiles_delete_admin" ON public.profiles;
CREATE POLICY "profiles_delete_admin" ON public.profiles
  FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- ── 4. Gönderilere yazar (user_id) sütunu ekle ──────────────
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS user_id UUID
  REFERENCES public.profiles(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_posts_user ON public.posts(user_id);

-- ── 5. Gönderi politikaları: sadece yazar veya admin ────────
DROP POLICY IF EXISTS "posts_insert" ON public.posts;
DROP POLICY IF EXISTS "posts_update" ON public.posts;
DROP POLICY IF EXISTS "posts_delete" ON public.posts;

CREATE POLICY "posts_insert" ON public.posts
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND auth.uid() = user_id);

CREATE POLICY "posts_update" ON public.posts
  FOR UPDATE
  USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

CREATE POLICY "posts_delete" ON public.posts
  FOR DELETE
  USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- ── 6. Rozet: yalnızca kendine veya admin ekleyebilir ────────
DROP POLICY IF EXISTS "user_badges_insert" ON public.user_badges;
CREATE POLICY "user_badges_insert" ON public.user_badges
  FOR INSERT
  WITH CHECK (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- ── 7. Bildirim: yalnızca admin ekleyebilir ──────────────────
--    (Edge Functions servis anahtarıyla RLS'yi atlayarak ekler)
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
CREATE POLICY "notifications_insert" ON public.notifications
  FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- ── 8. Topluluk mesajı silme: sadece sahibi ─────────────────
DROP POLICY IF EXISTS "messages_delete" ON public.community_messages;
CREATE POLICY "messages_delete" ON public.community_messages
  FOR DELETE
  USING (auth.uid() = user_id);

-- ── 9. RPC'lere yetkilendirme kontrolü ekle ─────────────────
--    Eski saf SQL fonksiyonları yerine güvenli plpgsql versiyonları.

CREATE OR REPLACE FUNCTION public.increment_post_support(post_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  -- Kullanıcının gerçekten bu postu desteklediğini doğrula
  IF NOT EXISTS (
    SELECT 1 FROM public.post_supports s
    WHERE s.user_id = auth.uid() AND s.post_id = increment_post_support.post_id
  ) THEN
    RAISE EXCEPTION 'Unauthorized: no support record found';
  END IF;
  UPDATE public.posts SET support_count = support_count + 1 WHERE id = post_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_post_support(post_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  UPDATE public.posts SET support_count = GREATEST(support_count - 1, 0) WHERE id = post_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_community_member(community_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  -- Kullanıcı gerçekten bu topluluğa üye mi?
  IF NOT EXISTS (
    SELECT 1 FROM public.community_members m
    WHERE m.user_id = auth.uid() AND m.community_id = increment_community_member.community_id
  ) THEN
    RAISE EXCEPTION 'Unauthorized: not a member';
  END IF;
  UPDATE public.communities SET member_count = member_count + 1 WHERE id = community_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_community_member(community_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  UPDATE public.communities SET member_count = GREATEST(member_count - 1, 0) WHERE id = community_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_post_quality(post_id BIGINT, new_score REAL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF new_score < 0 OR new_score > 5 THEN
    RAISE EXCEPTION 'Invalid score: must be between 0 and 5';
  END IF;
  UPDATE public.posts
  SET quality_score = (quality_score + new_score) / 2.0
  WHERE id = post_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_user_xp(user_id UUID, xp_amount INTEGER)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  -- Yalnızca kendine XP eklenebilir (admin hariç)
  IF auth.uid() != add_user_xp.user_id THEN
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin') THEN
      RAISE EXCEPTION 'Unauthorized: cannot add XP to other users';
    END IF;
  END IF;
  IF xp_amount <= 0 OR xp_amount > 100 THEN
    RAISE EXCEPTION 'Invalid XP amount: must be 1–100';
  END IF;
  UPDATE public.profiles SET xp = profiles.xp + xp_amount WHERE profiles.id = add_user_xp.user_id;
END;
$$;

-- ── 10. İçerik uzunluğu kısıtlamaları ───────────────────────
ALTER TABLE public.community_messages
  ADD CONSTRAINT IF NOT EXISTS chk_msg_content_len
  CHECK (char_length(content) >= 1 AND char_length(content) <= 2000);

ALTER TABLE public.posts
  ADD CONSTRAINT IF NOT EXISTS chk_post_content_len
  CHECK (char_length(content) >= 1 AND char_length(content) <= 5000);

ALTER TABLE public.profiles
  ADD CONSTRAINT IF NOT EXISTS chk_profile_name_len
  CHECK (char_length(name) >= 1 AND char_length(name) <= 100);

ALTER TABLE public.calendar_notes
  ADD CONSTRAINT IF NOT EXISTS chk_note_len
  CHECK (char_length(note) >= 1 AND char_length(note) <= 1000);

-- ── Tamamlandı ───────────────────────────────────────────────
-- Bu yamayı uyguladıktan sonra:
--   1. Supabase Dashboard → Auth → Rate Limits → login girişimlerini sınırla (5/dk)
--   2. Supabase Dashboard → Auth → Password Strength → minimum 8 karakter
--   3. app_config.dart dosyasının .gitignore'da olduğunu doğrula
