# ============================================================
#  Windows Performans Ayarlari
#  - Once geri yukleme noktasi olusturur
#  - Degistirdigi her seyi Masaustu\perf-yedek.json'a yedekler
#  - geri-al.ps1 ile hepsi eski haline doner
#  Windows Defender ve Windows Update'e DOKUNMAZ.
#  YONETICI PowerShell'de calistir.
# ============================================================

$guidRegex = '[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Bu scripti YONETICI olarak calistirman lazim (PowerShell'e sag tik > Yonetici olarak calistir)." -ForegroundColor Red
    exit 1
}

function Sor($soru) {
    $c = Read-Host "$soru (e/h)"
    return ($c -match '^[eEyY]')
}

$yedekYolu = Join-Path ([Environment]::GetFolderPath('Desktop')) 'perf-yedek.json'
if (Test-Path $yedekYolu) {
    Write-Host "Masaustunde zaten bir yedek var: $yedekYolu" -ForegroundColor Yellow
    Write-Host "Orijinal ayarlar kaybolmasin diye script durdu. Once geri-al.ps1'i calistir ya da bu dosyayi baska yere tasi." -ForegroundColor Yellow
    exit 1
}

$yedek = [ordered]@{
    Tarih     = (Get-Date).ToString('s')
    GucPlani  = $null
    Hizmetler = @()
    Kayit     = @()
}

function Kaydet {
    $script:yedek | ConvertTo-Json -Depth 5 | Set-Content -Path $script:yedekYolu -Encoding UTF8
}

function HizmetAyarla($ad, $tur = 'Disabled') {
    $s = Get-Service -Name $ad -ErrorAction SilentlyContinue
    if (-not $s) { Write-Host "   $ad bu bilgisayarda yok, atlandi." -ForegroundColor DarkGray; return }
    $script:yedek.Hizmetler += [pscustomobject]@{ Ad = $ad; Tur = $s.StartType.ToString() }
    try {
        if ($tur -eq 'Disabled' -and $s.Status -eq 'Running') { Stop-Service -Name $ad -Force -ErrorAction Stop }
        Set-Service -Name $ad -StartupType $tur -ErrorAction Stop
        Write-Host "   $ad ($($s.DisplayName)) -> $tur" -ForegroundColor Green
    } catch {
        Write-Host "   $ad degistirilemedi: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Kaydet
}

function KayitAyarla($yol, $ad, $deger, $tip = 'String') {
    try {
        if (-not (Test-Path $yol)) { New-Item -Path $yol -Force | Out-Null }
        $eski = (Get-ItemProperty -Path $yol -Name $ad -ErrorAction SilentlyContinue).$ad
        $script:yedek.Kayit += [pscustomobject]@{ Yol = $yol; Ad = $ad; Eski = $eski; Tip = $tip }
        Set-ItemProperty -Path $yol -Name $ad -Value $deger -Type $tip -ErrorAction Stop
        Write-Host "   $ad = $deger" -ForegroundColor Green
    } catch {
        Write-Host "   $ad ayarlanamadi: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Kaydet
}

Kaydet

# ---------------- 1) Geri yukleme noktasi ----------------
Write-Host "`n[1] Geri yukleme noktasi olusturuluyor..." -ForegroundColor Cyan
try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
    Checkpoint-Computer -Description "Performans ayarlari oncesi" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Host "   Tamam." -ForegroundColor Green
} catch {
    Write-Host "   Olusturulamadi: $($_.Exception.Message)" -ForegroundColor Yellow
    if (-not (Sor "   Geri yukleme noktasi olmadan devam edilsin mi?")) { Remove-Item $yedekYolu -ErrorAction SilentlyContinue; exit 1 }
}

# ---------------- 2) Guc plani ----------------
Write-Host "`n[2] Guc plani" -ForegroundColor Cyan
$yedek.GucPlani = [regex]::Match((powercfg /getactivescheme | Out-String), $guidRegex).Value
Kaydet
if (Sor "   Yuksek Performans guc planina gecilsin mi? (Dizustuyse pil daha hizli biter)") {
    $yuksek = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    if (-not (powercfg /list | Select-String $yuksek)) {
        $yuksek = [regex]::Match((powercfg /duplicatescheme $yuksek | Out-String), $guidRegex).Value
    }
    if ($yuksek) { powercfg /setactive $yuksek; Write-Host "   Yuksek Performans aktif." -ForegroundColor Green }
    else { Write-Host "   Bu cihazda Yuksek Performans plani acilamadi, atlandi." -ForegroundColor Yellow }
}

# ---------------- 3) Gereksiz hizmetler ----------------
Write-Host "`n[3] Cogu kisinin kullanmadigi hizmetler kapatiliyor..." -ForegroundColor Cyan
HizmetAyarla 'DiagTrack'        # Telemetri (Connected User Experiences)
HizmetAyarla 'dmwappushservice' # Telemetri WAP push
HizmetAyarla 'MapsBroker'       # Cevrimdisi harita indirme
HizmetAyarla 'RetailDemo'       # Magaza demo modu
HizmetAyarla 'Fax'              # Faks
HizmetAyarla 'RemoteRegistry'   # Uzaktan kayit defteri (guvenlik icin de kapali olmali)
HizmetAyarla 'WerSvc' 'Manual'  # Hata raporlama -> sadece gerektiginde

Write-Host "`n   Istege bagli hizmetler:" -ForegroundColor Cyan
if (Sor "   Xbox uygulamasi / Game Pass / Xbox kumandasi KULLANMIYOR musun? (evet = Xbox hizmetlerini kapat)") {
    'XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc' | ForEach-Object { HizmetAyarla $_ }
}
if (Sor "   Yazici KULLANMIYOR musun? (evet = Yazdirma Biriktiricisini kapat)") {
    HizmetAyarla 'Spooler'
}
if (Sor "   Windows SSD'de mi kurulu? (evet = SysMain/Superfetch kapat; HDD ise HAYIR de)") {
    HizmetAyarla 'SysMain'
}
if (Sor "   Dosya arama indekslemesini kapatayim mi? (Diskteki yuku azaltir ama Baslat aramasi yavaslar)") {
    HizmetAyarla 'WSearch'
}

# ---------------- 4) Arayuz ve arka plan ayarlari ----------------
Write-Host "`n[4] Arayuz ve arka plan ayarlari..." -ForegroundColor Cyan
KayitAyarla 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '100' 'String'
KayitAyarla 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
KayitAyarla 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0 'DWord'
KayitAyarla 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 'DWord'
KayitAyarla 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 'DWord'
KayitAyarla 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 'DWord'
KayitAyarla 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1 'DWord'
KayitAyarla 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 'DWord'
KayitAyarla 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' 0 'DWord'
KayitAyarla 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 0 'DWord'
KayitAyarla 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled' 0 'DWord'

# ---------------- 5) Gecici dosya temizligi ----------------
Write-Host "`n[5] Gecici dosyalar temizleniyor..." -ForegroundColor Cyan
$klasorler = @($env:TEMP, "$env:SystemRoot\Temp")
$once = ($klasorler | ForEach-Object { Get-ChildItem $_ -Recurse -Force -ErrorAction SilentlyContinue } | Measure-Object Length -Sum).Sum
foreach ($k in $klasorler) {
    Get-ChildItem $k -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
$sonra = ($klasorler | ForEach-Object { Get-ChildItem $_ -Recurse -Force -ErrorAction SilentlyContinue } | Measure-Object Length -Sum).Sum
Write-Host ("   Yaklasik {0:N0} MB bosaldi (kullanimdaki dosyalar atlandi)." -f (($once - $sonra) / 1MB)) -ForegroundColor Green

# ---------------- 6) Disk optimizasyonu ----------------
if (Sor "`n[6] Sistem diski optimize edilsin mi? (SSD'de TRIM, HDD'de birlestirme; HDD'de uzun surebilir)") {
    Optimize-Volume -DriveLetter $env:SystemDrive.TrimEnd(':') -Verbose
}

# ---------------- 7) Baslangic uygulamalari ----------------
Write-Host "`n[7] Bilgisayar acilirken calisan uygulamalar:" -ForegroundColor Cyan
Get-CimInstance Win32_StartupCommand | Select-Object Name, Location | Format-Table -AutoSize
Write-Host "   Bunlardan gereksiz olanlari Gorev Yoneticisi > Baslangic uygulamalari'ndan 'Devre disi birak' yap." -ForegroundColor Yellow
Write-Host "   (Discord, Spotify, Steam, Epic, OneDrive vb. genelde kapatilabilir; ses/ekran karti suruculerine dokunma.)"

Kaydet
Write-Host "`nBitti. Yedek: $yedekYolu" -ForegroundColor Green
Write-Host "Ayarlarin tam oturmasi icin bilgisayari YENIDEN BASLAT." -ForegroundColor Green
Write-Host "Bir sorun olursa geri-al.ps1'i calistir." -ForegroundColor Green
