# ============================================================
#  Windows Performance Tweaks
#  - Creates a System Restore point first
#  - Backs up everything it changes to Desktop\perf-backup.json
#  - undo-tweaks.ps1 restores everything to the original state
#  Does NOT touch Windows Defender or Windows Update.
#  Run in an ADMINISTRATOR PowerShell.
# ============================================================

$guidRegex = '[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "You need to run this script as ADMINISTRATOR (right-click PowerShell > Run as administrator)." -ForegroundColor Red
    exit 1
}

function Ask($question) {
    $answer = Read-Host "$question (y/n)"
    return ($answer -match '^[yY]')
}

$backupPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'perf-backup.json'
$otherBackupPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'perf-yedek.json'   # backup of the Turkish version
if ((Test-Path $backupPath) -or (Test-Path $otherBackupPath)) {
    Write-Host "A backup from a previous run already exists on the Desktop (perf-backup.json, or perf-yedek.json from the Turkish version)." -ForegroundColor Yellow
    Write-Host "The script stopped so your original settings are not lost. Run the matching undo script first, or move the backup file somewhere else." -ForegroundColor Yellow
    exit 1
}

$backup = [ordered]@{
    Date      = (Get-Date).ToString('s')
    PowerPlan = $null
    Services  = @()
    Registry  = @()
}

function Save-Backup {
    $script:backup | ConvertTo-Json -Depth 5 | Set-Content -Path $script:backupPath -Encoding UTF8
}

function Set-ServiceTweak($name, $startType = 'Disabled') {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Host "   $name does not exist on this computer, skipped." -ForegroundColor DarkGray; return }
    $script:backup.Services += [pscustomobject]@{ Name = $name; StartType = $svc.StartType.ToString() }
    try {
        if ($startType -eq 'Disabled' -and $svc.Status -eq 'Running') { Stop-Service -Name $name -Force -ErrorAction Stop }
        Set-Service -Name $name -StartupType $startType -ErrorAction Stop
        Write-Host "   $name ($($svc.DisplayName)) -> $startType" -ForegroundColor Green
    } catch {
        Write-Host "   Could not change ${name}: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Save-Backup
}

function Set-RegistryTweak($path, $name, $value, $type = 'String') {
    try {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        $old = (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name
        $script:backup.Registry += [pscustomobject]@{ Path = $path; Name = $name; OldValue = $old; Type = $type }
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -ErrorAction Stop
        Write-Host "   $name = $value" -ForegroundColor Green
    } catch {
        Write-Host "   Could not set ${name}: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Save-Backup
}

Save-Backup

# ---------------- 1) Restore point ----------------
Write-Host "`n[1] Creating a restore point..." -ForegroundColor Cyan
try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
    Checkpoint-Computer -Description "Before performance tweaks" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Host "   Done." -ForegroundColor Green
} catch {
    Write-Host "   Could not create it: $($_.Exception.Message)" -ForegroundColor Yellow
    if (-not (Ask "   Continue without a restore point?")) { Remove-Item $backupPath -ErrorAction SilentlyContinue; exit 1 }
}

# ---------------- 2) Power plan ----------------
Write-Host "`n[2] Power plan" -ForegroundColor Cyan
$backup.PowerPlan = [regex]::Match((powercfg /getactivescheme | Out-String), $guidRegex).Value
Save-Backup
if (Ask "   Switch to the High Performance power plan? (On a laptop the battery drains faster)") {
    $highPerf = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    if (-not (powercfg /list | Select-String $highPerf)) {
        $highPerf = [regex]::Match((powercfg /duplicatescheme $highPerf | Out-String), $guidRegex).Value
    }
    if ($highPerf) { powercfg /setactive $highPerf; Write-Host "   High Performance is now active." -ForegroundColor Green }
    else { Write-Host "   Could not enable the High Performance plan on this device, skipped." -ForegroundColor Yellow }
}

# ---------------- 3) Unneeded services ----------------
Write-Host "`n[3] Disabling services most people do not use..." -ForegroundColor Cyan
Set-ServiceTweak 'DiagTrack'        # Telemetry (Connected User Experiences)
Set-ServiceTweak 'dmwappushservice' # Telemetry WAP push
Set-ServiceTweak 'MapsBroker'       # Offline map downloads
Set-ServiceTweak 'RetailDemo'       # Store demo mode
Set-ServiceTweak 'Fax'              # Fax
Set-ServiceTweak 'RemoteRegistry'   # Remote registry (should be off for security as well)
Set-ServiceTweak 'WerSvc' 'Manual'  # Error reporting -> only when needed

Write-Host "`n   Optional services:" -ForegroundColor Cyan
if (Ask "   Do you NOT use the Xbox app / Game Pass / an Xbox controller? (yes = disable Xbox services)") {
    'XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc' | ForEach-Object { Set-ServiceTweak $_ }
}
if (Ask "   Do you NOT use a printer? (yes = disable the Print Spooler)") {
    Set-ServiceTweak 'Spooler'
}
if (Ask "   Is Windows installed on an SSD? (yes = disable SysMain/Superfetch; answer no if it is an HDD)") {
    Set-ServiceTweak 'SysMain'
}
if (Ask "   Disable file search indexing? (Reduces disk load but makes Start search slower)") {
    Set-ServiceTweak 'WSearch'
}

# ---------------- 4) UI and background settings ----------------
Write-Host "`n[4] UI and background settings..." -ForegroundColor Cyan
Set-RegistryTweak 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '100' 'String'
Set-RegistryTweak 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
Set-RegistryTweak 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0 'DWord'
Set-RegistryTweak 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 'DWord'
Set-RegistryTweak 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 'DWord'
Set-RegistryTweak 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 'DWord'
Set-RegistryTweak 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1 'DWord'
Set-RegistryTweak 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 'DWord'
Set-RegistryTweak 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' 0 'DWord'
Set-RegistryTweak 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 0 'DWord'
Set-RegistryTweak 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled' 0 'DWord'

# ---------------- 5) Temporary file cleanup ----------------
Write-Host "`n[5] Cleaning temporary files..." -ForegroundColor Cyan
$folders = @($env:TEMP, "$env:SystemRoot\Temp")
$before = ($folders | ForEach-Object { Get-ChildItem $_ -Recurse -Force -ErrorAction SilentlyContinue } | Measure-Object Length -Sum).Sum
foreach ($f in $folders) {
    Get-ChildItem $f -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
$after = ($folders | ForEach-Object { Get-ChildItem $_ -Recurse -Force -ErrorAction SilentlyContinue } | Measure-Object Length -Sum).Sum
Write-Host ("   Freed about {0:N0} MB (files in use were skipped)." -f (($before - $after) / 1MB)) -ForegroundColor Green

# ---------------- 6) Disk optimization ----------------
if (Ask "`n[6] Optimize the system drive? (TRIM on SSD, defragmentation on HDD; can take a long time on an HDD)") {
    Optimize-Volume -DriveLetter $env:SystemDrive.TrimEnd(':') -Verbose
}

# ---------------- 7) Startup apps ----------------
Write-Host "`n[7] Apps that run when the computer starts:" -ForegroundColor Cyan
Get-CimInstance Win32_StartupCommand | Select-Object Name, Location | Format-Table -AutoSize
Write-Host "   Disable the ones you do not need in Task Manager > Startup apps." -ForegroundColor Yellow
Write-Host "   (Discord, Spotify, Steam, Epic, OneDrive etc. can usually be disabled; leave audio/GPU driver software alone.)"

Save-Backup
Write-Host "`nDone. Backup: $backupPath" -ForegroundColor Green
Write-Host "RESTART your computer so all changes take effect." -ForegroundColor Green
Write-Host "If anything goes wrong, run undo-tweaks.ps1." -ForegroundColor Green
