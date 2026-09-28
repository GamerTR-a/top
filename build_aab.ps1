# NevGenç - Otomatik ASCII Dizininde AAB Derleme Scripti
#
# Not: $ErrorActionPreference = "Stop" kasıtlı olarak KULLANILMIYOR.
# PowerShell 5.1, çıktısı yakalanan/yönlendirilen (örn. arka planda) bir
# native komutun (flutter, robocopy) stderr'ine yazdığı her satırı
# NativeCommandError'a çevirip $ErrorActionPreference="Stop" ile script'i
# durdurabiliyor — "flutter clean" içindeki zararsız "ephemeral klasörü
# silinemedi" uyarısı bu yüzden derlemeyi tamamen bloke ediyordu. Bunun
# yerine her native komuttan sonra gerçek başarı/başarısızlık $LASTEXITCODE
# ile kontrol ediliyor.

# Kaynak dizin sabit yazilmak yerine scriptin bulundugu dizin (proje koku)
# kullanilir. Boylece "Masaustu" (Masaüstü) gibi Turkce karakterlerin
# PowerShell 5.1 tarafindan yanlis okunmasi sorunu ortadan kalkar.
$SourceDir = $PSScriptRoot
$TargetDir = "C:\newgenc_build"

Write-Host "1. Proje dosyaları $TargetDir dizinine kopyalanıyor..." -ForegroundColor Cyan
if (!(Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
}

# robocopy ile .git ve build önbellekleri hariç kopyalama
# (robocopy exit code'ları bit-mask'tir; 0-7 arası başarı sayılır, 8+ hata.)
robocopy $SourceDir $TargetDir /MIR /XD .dart_tool .git build node_modules /XF app-release.aab app-release.apk /NJH /NJS /ndl /nc /ns /np
if ($LASTEXITCODE -ge 8) {
    Write-Host "❌ robocopy başarısız oldu (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}

Write-Host "2. $TargetDir dizininde derleme başlatılıyor..." -ForegroundColor Cyan
Set-Location $TargetDir

Write-Host "Flutter önbellek temizleniyor..." -ForegroundColor Yellow
flutter clean
# flutter clean, kilitli bir ephemeral klasörü silemediğinde bile temizliğin
# geri kalanını tamamlar ve kendi exit code'u 0 döner — bu yüzden burada
# $LASTEXITCODE kontrolü kasıtlı olarak yapılmıyor (zararsız uyarı).

Write-Host "Bağımlılıklar indiriliyor..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ flutter pub get başarısız oldu (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}

Write-Host "AppBundle (AAB) derleniyor..." -ForegroundColor Green
# --obfuscate + --split-debug-info: reverse engineering yüzeyini azaltır.
# debug-info klasörünü crash sembolikasyonu için sakla (Play Console'a yüklenmez).
flutter build appbundle --release --no-tree-shake-icons --obfuscate --split-debug-info="$TargetDir\debug-info"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ flutter build appbundle başarısız oldu (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}

$ScriptDir = $PSScriptRoot
$BuildAabPath = "$TargetDir\build\app\outputs\bundle\release\app-release.aab"
$OutputAabPath = "$ScriptDir\app-release.aab"

if (Test-Path $BuildAabPath) {
    Copy-Item -Path $BuildAabPath -Destination $OutputAabPath -Force
    Write-Host "✅ AAB Başarıyla Derlendi ve kopyalandı:" -ForegroundColor Green
    Write-Host "   $OutputAabPath" -ForegroundColor White
} else {
    Write-Host "❌ AAB dosyası bulunamadı, derleme başarısız olabilir." -ForegroundColor Red
    exit 1
}
