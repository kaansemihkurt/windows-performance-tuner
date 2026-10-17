# ============================================================
#  Reverts the changes made by performance-tweaks.ps1.
#  Uses Desktop\perf-backup.json.
#  Run in an ADMINISTRATOR PowerShell.
# ============================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "You need to run this script as ADMINISTRATOR." -ForegroundColor Red
    exit 1
}

$backupPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'perf-backup.json'
if (-not (Test-Path $backupPath)) {
    Write-Host "Backup not found: $backupPath" -ForegroundColor Red
    Write-Host "Alternative: Start > 'Create a restore point' > System Restore." -ForegroundColor Yellow
    exit 1
}

$b = Get-Content $backupPath -Raw | ConvertFrom-Json

Write-Host "`nRestoring power plan..." -ForegroundColor Cyan
if ($b.PowerPlan) { powercfg /setactive $b.PowerPlan; Write-Host "   Done." -ForegroundColor Green }

Write-Host "`nRestoring services..." -ForegroundColor Cyan
foreach ($s in $b.Services) {
    try {
        Set-Service -Name $s.Name -StartupType $s.StartType -ErrorAction Stop
        if ($s.StartType -eq 'Automatic') { Start-Service -Name $s.Name -ErrorAction SilentlyContinue }
        Write-Host "   $($s.Name) -> $($s.StartType)" -ForegroundColor Green
    } catch {
        Write-Host "   Could not restore $($s.Name): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nRestoring registry settings..." -ForegroundColor Cyan
foreach ($r in $b.Registry) {
    try {
        if ($null -eq $r.OldValue) {
            Remove-ItemProperty -Path $r.Path -Name $r.Name -ErrorAction SilentlyContinue
            Write-Host "   $($r.Name) removed (it did not exist before)" -ForegroundColor Green
        } else {
            Set-ItemProperty -Path $r.Path -Name $r.Name -Value $r.OldValue -Type $r.Type -ErrorAction Stop
            Write-Host "   $($r.Name) = $($r.OldValue)" -ForegroundColor Green
        }
    } catch {
        Write-Host "   Could not restore $($r.Name): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$newName = "perf-backup-restored-$(Get-Date -Format 'yyyyMMdd-HHmm').json"
Rename-Item -Path $backupPath -NewName $newName
Write-Host "`nEverything has been restored. Restart your computer." -ForegroundColor Green
