# NevGenç - Otomatik ASCII Dizininde AAB Derleme Scripti
$ErrorActionPreference = "Stop"

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
robocopy $SourceDir $TargetDir /MIR /XD .dart_tool .git build node_modules /XF app-release.aab app-release.apk /NJH /NJS /ndl /nc /ns /np

Write-Host "2. $TargetDir dizininde derleme başlatılıyor..." -ForegroundColor Cyan
Set-Location $TargetDir

Write-Host "Flutter önbellek temizleniyor..." -ForegroundColor Yellow
flutter clean

Write-Host "Bağımlılıklar indiriliyor..." -ForegroundColor Yellow
flutter pub get

Write-Host "AppBundle (AAB) derleniyor..." -ForegroundColor Green
flutter build appbundle --release --no-tree-shake-icons

$ScriptDir = $PSScriptRoot
$BuildAabPath = "$TargetDir\build\app\outputs\bundle\release\app-release.aab"
$OutputAabPath = "$ScriptDir\app-release.aab"

if (Test-Path $BuildAabPath) {
    Copy-Item -Path $BuildAabPath -Destination $OutputAabPath -Force
    Write-Host "✅ AAB Başarıyla Derlendi ve kopyalandı:" -ForegroundColor Green
    Write-Host "   $OutputAabPath" -ForegroundColor White
} else {
    Write-Host "❌ AAB dosyası bulunamadı, derleme başarısız olabilir." -ForegroundColor Red
}
