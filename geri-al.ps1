# ============================================================
#  perf-ayarlari.ps1 ile yapilan degisiklikleri geri alir.
#  Masaustu\perf-yedek.json dosyasini kullanir.
#  YONETICI PowerShell'de calistir.
# ============================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Bu scripti YONETICI olarak calistirman lazim." -ForegroundColor Red
    exit 1
}

$yedekYolu = Join-Path ([Environment]::GetFolderPath('Desktop')) 'perf-yedek.json'
if (-not (Test-Path $yedekYolu)) {
    Write-Host "Yedek bulunamadi: $yedekYolu" -ForegroundColor Red
    Write-Host "Alternatif: Baslat > 'Geri yukleme noktasi olustur' > Sistem Geri Yukleme." -ForegroundColor Yellow
    exit 1
}

$y = Get-Content $yedekYolu -Raw | ConvertFrom-Json

Write-Host "`nGuc plani geri aliniyor..." -ForegroundColor Cyan
if ($y.GucPlani) { powercfg /setactive $y.GucPlani; Write-Host "   Tamam." -ForegroundColor Green }

Write-Host "`nHizmetler geri aliniyor..." -ForegroundColor Cyan
foreach ($h in $y.Hizmetler) {
    try {
        Set-Service -Name $h.Ad -StartupType $h.Tur -ErrorAction Stop
        if ($h.Tur -eq 'Automatic') { Start-Service -Name $h.Ad -ErrorAction SilentlyContinue }
        Write-Host "   $($h.Ad) -> $($h.Tur)" -ForegroundColor Green
    } catch {
        Write-Host "   $($h.Ad) geri alinamadi: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nKayit defteri ayarlari geri aliniyor..." -ForegroundColor Cyan
foreach ($k in $y.Kayit) {
    try {
        if ($null -eq $k.Eski) {
            Remove-ItemProperty -Path $k.Yol -Name $k.Ad -ErrorAction SilentlyContinue
            Write-Host "   $($k.Ad) silindi (onceden yoktu)" -ForegroundColor Green
        } else {
            Set-ItemProperty -Path $k.Yol -Name $k.Ad -Value $k.Eski -Type $k.Tip -ErrorAction Stop
            Write-Host "   $($k.Ad) = $($k.Eski)" -ForegroundColor Green
        }
    } catch {
        Write-Host "   $($k.Ad) geri alinamadi: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$yeniAd = "perf-yedek-geri-alindi-$(Get-Date -Format 'yyyyMMdd-HHmm').json"
Rename-Item -Path $yedekYolu -NewName $yeniAd
Write-Host "`nHepsi geri alindi. Bilgisayari yeniden baslat." -ForegroundColor Green
