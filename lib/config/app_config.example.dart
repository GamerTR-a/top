// Bu dosyayı app_config.dart olarak kopyalayıp gerçek değerlerle doldurun.
// app_config.dart asla git'e eklenmez.
//
// Not: Gerçek app_config.dart bu sabit değerleri `--dart-define=SUPABASE_URL=...`
// ile override edilebilir hale getirir (staging ortamı için) — bkz. o dosyadaki
// yorum.
class AppConfig {
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
}
