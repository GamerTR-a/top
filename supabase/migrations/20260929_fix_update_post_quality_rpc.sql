/* ============================================================================
   NevGenç — update_post_quality RPC yetki açığı düzeltmesi (2026-09-29)
   ----------------------------------------------------------------------------
   Supabase Dashboard → SQL Editor'da çalıştırın. İdempotent.

   Bulgu (KRİTİK — yetkisiz veri manipülasyonu): 20260925_missing_tables_and_
   rpcs.sql içinde tanımlanan update_post_quality(post_id, new_score)
   SECURITY DEFINER ama içeride yalnızca "auth.uid() IS NOT NULL" (yani
   giriş yapılmış mı) kontrol ediliyordu — sahiplik, rol veya kullanıcı
   başına tekil oy kontrolü YOKTU. Herhangi bir authenticated kullanıcı
   Supabase REST API'sine doğrudan rpc/update_post_quality çağrısı yaparak
   İSTEDİĞİ herhangi bir gönderinin quality_score'unu sınırsız kez
   manipüle edebilirdi. (Gerçek/doğru puanlama akışı ratePost() →
   upsert_post_rating RPC'sini kullanıyor, bu fonksiyonu hiç çağırmıyor —
   update_post_quality istemci tarafında ölü kod ama veritabanında canlı
   ve dışarıdan çağrılabilir durumdaydı.)

   Fix: fonksiyon artık yalnızca admin çağırabilir (kupon RPC'lerinde
   uygulanan aynı desen — bkz. 20260928_security_hardening_v2.sql), ve
   PUBLIC'ten yetkisi geri alınıyor.
   ============================================================================ */

CREATE OR REPLACE FUNCTION public.update_post_quality(post_id BIGINT, new_score REAL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekir.' USING ERRCODE = '42501';
  END IF;
  IF new_score < 0 OR new_score > 5 THEN
    RAISE EXCEPTION 'Invalid score: must be between 0 and 5';
  END IF;
  UPDATE public.posts
  SET quality_score = (quality_score + new_score) / 2.0
  WHERE id = post_id;
END;
$$;

REVOKE ALL ON FUNCTION public.update_post_quality(BIGINT, REAL) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_post_quality(BIGINT, REAL) TO authenticated;

/* ============================================================================
   DOĞRULAMA (çalıştırdıktan sonra elle teyit edin):

   SELECT proname, proacl FROM pg_proc WHERE proname = 'update_post_quality';
   (proacl içinde yalnızca "authenticated=X/..." görünmeli, PUBLIC olmamalı)

   Ayrıca admin olmayan bir hesapla şu çağrının HATA vermesi gerekir:
   select public.update_post_quality(<var_olan_post_id>, 5);
   ============================================================================ */
