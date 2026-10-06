#!/usr/bin/env bash
# CI'da lib/config/app_config.dart dosyasını üretir (dosya .gitignore'da).
# Gerekli ortam değişkenleri: SUPABASE_URL, SUPABASE_ANON_KEY (publishable key).
set -euo pipefail

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "::error::SUPABASE_URL / SUPABASE_ANON_KEY tanımlı değil. CI secret'larına ekleyin."
  exit 1
fi
case "$SUPABASE_ANON_KEY" in
  *service_role*|sb_secret_*)
    echo "::error::SUPABASE_ANON_KEY bir gizli (service) anahtar gibi görünüyor; istemciye yalnızca publishable/anon anahtar gömülür."
    exit 1
    ;;
esac

mkdir -p lib/config
cat > lib/config/app_config.dart <<EOF
// CI tarafından üretildi (tool/ci_write_app_config.sh) — elle düzenlemeyin.
enum AppEnvironment { production, staging, development }

class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '${SUPABASE_URL}',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '${SUPABASE_ANON_KEY}',
  );

  static const String _envName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  static AppEnvironment get environment {
    switch (_envName) {
      case 'staging':
        return AppEnvironment.staging;
      case 'development':
        return AppEnvironment.development;
      default:
        return AppEnvironment.production;
    }
  }

  static bool get isProduction => environment == AppEnvironment.production;
}
EOF
echo "lib/config/app_config.dart üretildi."
