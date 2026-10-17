# Windows Performance Tuner

[🇹🇷 Türkçe açıklama için aşağı kaydırın / Turkish description below](#-türkçe)

A **safe and reversible** performance tuning script for Windows 10 / 11.

Before changing anything, the script creates a **System Restore point**. It then saves the original value of every setting it touches to a backup file. If anything goes wrong, `geri-al.ps1` (the undo script) restores everything with a single command.

> ⚠️ Windows Defender, Windows Update and drivers are **never touched**. Disabling them barely improves performance and leaves the system insecure and unstable.

> ℹ️ The interactive prompts and console messages are in Turkish. Answer **`e`** (evet) or **`y`** for yes, and **`h`** (hayır) or anything else for no.

---

## Table of Contents

- [Files](#files)
- [Requirements](#requirements)
- [Usage](#usage)
- [What It Changes](#what-it-changes)
- [Undo / Rollback](#undo--rollback)
- [What It Deliberately Does Not Touch](#what-it-deliberately-does-not-touch)
- [Safety Measures](#safety-measures)
- [FAQ](#faq)
- [Disclaimer](#disclaimer)
- [License](#license)
- [🇹🇷 Türkçe](#-türkçe)

---

## Files

| File | Purpose |
|---|---|
| `perf-ayarlari.ps1` | Applies the performance tweaks and creates the backup |
| `geri-al.ps1` | Restores all changes from the backup |
| `perf-yedek.json` | Created automatically on your **Desktop** when the script runs; stores your original settings |

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 (included with Windows)
- **Administrator** privileges

## Usage

1. Download the repository (or just the two `.ps1` files) into a folder.
2. Type `PowerShell` in the Start menu, **right-click it and choose "Run as administrator"**.
3. Run the following (adjust the folder path to where you saved the files):

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd $env:USERPROFILE\Downloads
.\perf-ayarlari.ps1
```

4. The script asks a few questions along the way. Answer `e` / `y` for yes and `h` for no.
5. When it finishes, **restart your computer**.

> `Set-ExecutionPolicy -Scope Process Bypass` only applies to that single PowerShell window. Once you close it, your system's script policy is back to normal.

---

## What It Changes

### 1. Restore point

| Action | Why |
|---|---|
| Enables System Protection on the system drive | Required to create restore points |
| Creates a restore point named "Performans ayarlari oncesi" ("before performance tweaks") | Lets you roll Windows back to this moment if something goes wrong |

Windows normally allows only one restore point per 24 hours. If the point cannot be created, the script warns you and asks whether to continue.

### 2. Power plan

*Prompted.*

| Action | Why |
|---|---|
| Activates the **High Performance** power plan (creates it from the template if it is hidden on your device) | Reduces CPU throttling and improves responsiveness |

On laptops the battery drains faster. The GUID of your previous plan is saved to the backup.

### 3. Services disabled automatically

These services are unnecessary for most users and are disabled without asking.

| Service | Display name | New state | Why |
|---|---|---|---|
| `DiagTrack` | Connected User Experiences and Telemetry | Disabled | Sends telemetry to Microsoft; uses CPU, disk and network |
| `dmwappushservice` | Device Management WAP Push | Disabled | Message routing tied to telemetry |
| `MapsBroker` | Downloaded Maps Manager | Disabled | Offline map downloads; rarely used |
| `RetailDemo` | Retail Demo Service | Disabled | Only for in-store demo machines |
| `Fax` | Fax | Disabled | Fax service |
| `RemoteRegistry` | Remote Registry | Disabled | Allows remote registry access; unnecessary and a security risk |
| `WerSvc` | Windows Error Reporting | Manual | Not fully disabled, only runs when needed |

### 4. Optional services

These depend on how you use your PC, so the script asks first.

| Question | Service(s) affected | Say yes if... | Effect |
|---|---|---|---|
| Do you NOT use Xbox? | `XblAuthManager`, `XblGameSave`, `XboxNetApiSvc`, `XboxGipSvc` | You don't use the Xbox app, Game Pass or an Xbox controller | Xbox sign-in, cloud saves and controller support stop working |
| Do you NOT use a printer? | `Spooler` | You never print | Printing and "Print to PDF" stop working |
| Is Windows on an SSD? | `SysMain` (Superfetch) | Windows is installed on an **SSD**. Do not disable on an HDD. | Less unnecessary disk activity on SSDs |
| Disable file indexing? | `WSearch` | Disk usage is constantly high | Lower disk load, but Start and File Explorer search get slower |

### 5. UI and background settings

All changes affect the current user only (`HKCU`).

| Registry path | Value | New | Why |
|---|---|---|---|
| `HKCU:\Control Panel\Desktop` | `MenuShowDelay` | `100` | Menu delay drops from 400 ms to 100 ms |
| `HKCU:\Control Panel\Desktop\WindowMetrics` | `MinAnimate` | `0` | Disables window minimize/maximize animation |
| `HKCU:\...\Explorer\Advanced` | `TaskbarAnimations` | `0` | Disables taskbar animations |
| `HKCU:\Software\Microsoft\GameBar` | `AutoGameModeEnabled` | `1` | Enables Game Mode, prioritizing resources for games |
| `HKCU:\System\GameConfigStore` | `GameDVR_Enabled` | `0` | Disables background game recording, reducing FPS loss |
| `HKCU:\...\CurrentVersion\GameDVR` | `AppCaptureEnabled` | `0` | Disables app screen capture |
| `HKCU:\...\BackgroundAccessApplications` | `GlobalUserDisabled` | `1` | Stops Store apps from running in the background (most effective on Windows 10) |
| `HKCU:\...\AdvertisingInfo` | `Enabled` | `0` | Turns off the advertising ID |
| `HKCU:\...\ContentDeliveryManager` | `SystemPaneSuggestionsEnabled` | `0` | Turns off Start menu suggestions |
| `HKCU:\...\ContentDeliveryManager` | `SubscribedContent-338389Enabled` | `0` | Turns off Windows tips and suggestion notifications |
| `HKCU:\...\ContentDeliveryManager` | `SilentInstalledAppsEnabled` | `0` | Stops Windows from silently installing apps |

> Paths abbreviated with `...` are under `HKCU:\Software\Microsoft\Windows\CurrentVersion\`.

If a value did not exist beforehand, it is recorded in the backup as "did not exist" and is deleted during rollback.

### 6. Temporary file cleanup

| Action | Why |
|---|---|
| Empties `%TEMP%` (user) and `C:\Windows\Temp` | Frees disk space. Files in use are skipped. The script reports how much space was freed. |

This step cannot be undone, but the deleted files are temporary by nature.

### 7. Disk optimization

*Prompted.*

| Action | Why |
|---|---|
| Runs `Optimize-Volume` on the system drive | Performs **TRIM** on SSDs and **defragmentation** on HDDs. Windows detects the drive type itself. |

This can take a long time on an HDD.

### 8. Startup apps

| Action | Why |
|---|---|
| Programs that launch at boot are **listed, not modified** | Startup apps affect boot time the most, but only you know which ones you need |

Disable the ones you don't need under **Task Manager → Startup apps**. Discord, Spotify, Steam, Epic Games and OneDrive can usually be disabled safely. Leave audio and GPU software alone.

---

## Undo / Rollback

There are two ways to roll back.

### Method 1: `geri-al.ps1` (recommended)

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd $env:USERPROFILE\Downloads
.\geri-al.ps1
```

This script:
- Re-activates your previous power plan.
- Restores each service's original startup type, and starts those that were previously "Automatic".
- Restores registry values to their original state, deleting those that did not exist before.
- Renames the backup to `perf-yedek-geri-alindi-DATE.json` so you can run the tweaks again later.

Restart your computer when it finishes.

### Method 2: System Restore

Type **"Create a restore point"** in the Start menu, click **System Restore**, and pick the **"Performans ayarlari oncesi"** restore point.

---

## What It Deliberately Does Not Touch

| Setting | Why it is left alone |
|---|---|
| Windows Defender | Disabling it gives no meaningful speedup and exposes the system to malware |
| Windows Update | Security patches are critical |
| Drivers | Tampering can cause hardware problems |
| Virtual memory (pagefile) | Wrong settings cause crashes and app terminations |
| Hibernation / Fast Startup | Changes boot behavior; benefit varies by hardware |
| All visual effects | Settings that affect readability, such as font smoothing, are kept |

---

## Safety Measures

- The script **refuses to run** without administrator privileges.
- If `perf-yedek.json` already exists on the Desktop, the script **stops**, so a second run can never overwrite the backup of your original settings.
- The backup is saved after every step, so even if the script is interrupted, changes made up to that point can still be undone.
- If a service or setting does not exist or cannot be changed, the script shows a warning and continues instead of failing.

---

## FAQ

**Can I run the script a second time?**
Run `geri-al.ps1` first, or move `perf-yedek.json` off the Desktop. Otherwise the script stops to protect your original backup.

**I get a "running scripts is disabled on this system" error.**
Make sure you ran `Set-ExecutionPolicy -Scope Process Bypass -Force` before the other commands.

**Characters look broken in the console.**
Console messages intentionally avoid Turkish special characters to prevent this.

**My printer / Xbox controller stopped working.**
You may have answered "yes" to the related question. Run `geri-al.ps1`, or open `services.msc`, set the service to **Automatic** and start it.

**How do I know whether Windows is on an SSD or an HDD?**
Open Task Manager → Performance → Disk 0. The type is shown in the top-right corner.

---

## Disclaimer

This script changes settings that are widely considered safe, and every change is backed up and reversible. Still, every system is different. Use it at your own risk, and read the script before running it.

## License

Released under the [MIT License](LICENSE). Copyright (c) 2026 Kaan Semih Kurt.

---

# 🇹🇷 Türkçe

## Windows Performans Ayarları

Windows 10 / 11 için **güvenli ve geri alınabilir** bir performans iyileştirme scripti.

Script çalışmaya başlamadan önce bir **sistem geri yükleme noktası** oluşturur ve değiştirdiği her ayarın eski değerini Masaüstüne yedekler. Bir sorun çıkarsa `geri-al.ps1` ile tek komutta her şey eski haline döner.

> ⚠️ Windows Defender, Windows Update ve sürücülere **dokunulmaz**.

### Kullanım

1. İki `.ps1` dosyasını bir klasöre indirin.
2. PowerShell'i **Yönetici olarak** açın.
3. Şunları çalıştırın:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd $env:USERPROFILE\Downloads
.\perf-ayarlari.ps1
```

4. Sorulara evet için `e`, hayır için `h` yazın.
5. Bitince bilgisayarı **yeniden başlatın**.

### Script neler yapar?

| Adım | Yapılan işlem | Neden |
|---|---|---|
| 1. Geri yükleme noktası | "Performans ayarlari oncesi" noktası oluşturulur | Sorun olursa Windows'u bu ana döndürmek için |
| 2. Güç planı *(sorar)* | Yüksek Performans planı etkinleştirilir | İşlemci hız düşürmesin diye. Dizüstünde pil daha hızlı biter |
| 3. Hizmetler *(otomatik)* | `DiagTrack`, `dmwappushservice` (telemetri), `MapsBroker` (çevrimdışı haritalar), `RetailDemo`, `Fax`, `RemoteRegistry` kapatılır; `WerSvc` (hata raporlama) "el ile" yapılır | CPU, disk ve ağ kullanımını azaltmak, güvenlik riskini kapatmak için |
| 4. Hizmetler *(sorar)* | Xbox hizmetleri, `Spooler` (yazıcı), `SysMain` (sadece SSD'de), `WSearch` (arama indeksi) | Kullanımınıza bağlı olduğu için önce sorulur |
| 5. Arayüz ayarları | Menü gecikmesi 100 ms, pencere ve görev çubuğu animasyonları kapalı, Oyun Modu açık, Game DVR kapalı, arka plan uygulamaları kapalı, reklam kimliği ve Başlat önerileri kapalı | Sistemi daha akıcı yapmak, arka plan yükünü ve reklamları azaltmak için |
| 6. Geçici dosyalar | `%TEMP%` ve `C:\Windows\Temp` temizlenir | Disk alanı açmak için |
| 7. Disk optimizasyonu *(sorar)* | SSD'de TRIM, HDD'de birleştirme | Diskin uzun vadede hızlı kalması için |
| 8. Başlangıç uygulamaları | Açılışta çalışanlar **sadece listelenir** | Hangisinin gerekli olduğuna siz karar verirsiniz; açılış hızını en çok bu etkiler |

### Geri alma

- **Yöntem 1 (önerilen):** Yönetici PowerShell'de `.\geri-al.ps1` çalıştırın. Hizmetler, güç planı ve kayıt defteri ayarları eski haline döner.
- **Yöntem 2:** Başlat'a "Geri yükleme noktası oluştur" yazın, Sistem Geri Yükleme'den **"Performans ayarlari oncesi"** noktasını seçin.

### Bilerek dokunulmayanlar

Windows Defender, Windows Update, sürücüler, sanal bellek (pagefile) ve hazırda bekletme / Hızlı Başlatma ayarlarına dokunulmaz. Bunları değiştirmek ya performansı artırmaz ya da sistemi kararsız ve güvensiz yapar.

### Güvenlik önlemleri

- Yönetici yetkisi olmadan çalışmaz.
- Masaüstünde zaten `perf-yedek.json` varsa script durur; orijinal ayarların yedeği ezilmez.
- Yedek her adımdan sonra kaydedilir, script yarıda kesilse bile geri alınabilir.
- Bir ayar bulunamazsa ya da değiştirilemezse hata vermeden uyarı gösterip devam eder.

### Sorumluluk reddi

Her değişiklik yedeklenir ve geri alınabilir, ancak her sistem farklıdır. Kullanım sorumluluğu size aittir; çalıştırmadan önce scripti okumanızı öneririz.

### Lisans

[MIT Lisansı](LICENSE) ile yayınlanmıştır. Telif hakkı (c) 2026 Kaan Semih Kurt.
