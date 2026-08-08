# ============================================================
# NevGenç — Firebase Kurulum Script'i (PowerShell)
# Çalıştır: .\setup_firebase.ps1
# ============================================================

Write-Host ""
Write-Host "===== NevGenç Firebase Kurulumu =====" -ForegroundColor Cyan
Write-Host ""

# 1. Firebase CLI kur
Write-Host "[1/4] Firebase CLI kuruluyor..." -ForegroundColor Yellow
npm install -g firebase-tools
if ($LASTEXITCODE -ne 0) {
    Write-Host "HATA: npm bulunamadi. Node.js yuklu mu kontrol edin." -ForegroundColor Red
    exit 1
}
Write-Host "Firebase CLI kuruldu." -ForegroundColor Green

# 2. FlutterFire CLI kur
Write-Host ""
Write-Host "[2/4] FlutterFire CLI kuruluyor..." -ForegroundColor Yellow
dart pub global activate flutterfire_cli
Write-Host "FlutterFire CLI kuruldu." -ForegroundColor Green

# 3. Firebase'e giriş yap
Write-Host ""
Write-Host "[3/4] Firebase hesabiniza giris yapin..." -ForegroundColor Yellow
firebase login
if ($LASTEXITCODE -ne 0) {
    Write-Host "HATA: Firebase girisi basarisiz." -ForegroundColor Red
    exit 1
}

# 4. FlutterFire ile konfigürasyon dosyalarını oluştur
Write-Host ""
Write-Host "[4/4] Firebase proje konfigurasyonu yapiliyor..." -ForegroundColor Yellow
Write-Host "NOT: Firebase Console'da bir proje olusturulmus olmali." -ForegroundColor Magenta
Write-Host "     https://console.firebase.google.com adresinden proje olusturun." -ForegroundColor Magenta
Write-Host ""

Set-Location $PSScriptRoot
flutterfire configure

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "===== Firebase kurulumu tamamlandi! =====" -ForegroundColor Green
    Write-Host ""
    Write-Host "Olusturulan dosyalar:" -ForegroundColor Cyan
    Write-Host "  - lib/firebase_options.dart (otomatik)" -ForegroundColor White
    Write-Host "  - android/app/google-services.json (otomatik)" -ForegroundColor White
    Write-Host "  - ios/Runner/GoogleService-Info.plist (otomatik)" -ForegroundColor White
    Write-Host ""
    Write-Host "Son adim: lib/main.dart icindeki Firebase.initializeApp() cagrisini guncelle:" -ForegroundColor Yellow
    Write-Host "  import 'firebase_options.dart';" -ForegroundColor Gray
    Write-Host "  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Simdi 'flutter pub get' ve 'flutter run' calistirabilirsiniz." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "HATA: FlutterFire configure basarisiz oldu." -ForegroundColor Red
    Write-Host "Firebase Console'da projenizin mevcut oldugunu kontrol edin." -ForegroundColor Red
}
