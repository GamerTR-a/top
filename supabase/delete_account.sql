-- Uygulama içi hesap silme (Apple App Store yönergesi 5.1.1(v) için zorunlu)
--
-- Bu fonksiyon, giriş yapmış kullanıcının auth.users kaydını siler.
-- auth.users üzerindeki ON DELETE CASCADE foreign key'ler sayesinde
-- profiles / posts / user_badges gibi ilişkili satırlar otomatik silinir.
-- (FK'lerinizde CASCADE yoksa, aşağıya elle DELETE satırları ekleyin.)
--
-- SECURITY DEFINER: fonksiyon, tablo sahibinin (postgres) yetkisiyle çalışır;
-- böylece anon/authenticated rol auth.users'tan silme yapabilir.
-- auth.uid() sayesinde yalnızca KENDİ hesabını silebilir.

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Güvenlik ağı: public.profiles.id -> auth.users(id) ON DELETE CASCADE
  -- olsa da (bkz. supabase_schema.sql), canlı ortamda hangi kurulum
  -- dosyasının çalıştığı belirsiz olabileceğinden buradan da açıkça
  -- silinir. profiles.id'ye ON DELETE CASCADE ile bağlı tüm alt tablolar
  -- (posts, community_members, user_badges, notifications,
  -- event_registrations, post_ratings, post_reports, calendar_notes,
  -- fcm_tokens, community_messages, post_supports vb.) bu satırla
  -- birlikte temizlenir — auth.users satırı zaten silinmeden önce.
  delete from public.profiles where id = uid;

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_account() from public;
grant execute on function public.delete_account() to authenticated;
