# Windows Performans Ayarları

[English](README.md) | **Türkçe**

Windows 10 / 11 için **güvenli ve geri alınabilir** bir performans iyileştirme scripti.

Script, herhangi bir şeyi değiştirmeden önce bir **sistem geri yükleme noktası** oluşturur. Ardından değiştirdiği her ayarın eski değerini bir yedek dosyasına kaydeder. Bir sorun çıkarsa `geri-al.ps1` (geri alma scripti) tek komutla her şeyi eski haline döndürür.

> ⚠️ Windows Defender, Windows Update ve sürücülere **asla dokunulmaz**. Bunları kapatmak performansı neredeyse hiç artırmaz, ama sistemi güvensiz ve kararsız hale getirir.

> ℹ️ Script çalışırken çıkan sorular ve mesajlar Türkçedir. Evet için **`e`** (veya `y`), hayır için **`h`** yazın.

---

## İçindekiler

- [Dosyalar](#dosyalar)
- [Gereksinimler](#gereksinimler)
- [Kullanım](#kullanım)
- [Yapılan Değişiklikler](#yapılan-değişiklikler)
- [Geri Alma](#geri-alma)
- [Bilerek Dokunulmayanlar](#bilerek-dokunulmayanlar)
- [Güvenlik Önlemleri](#güvenlik-önlemleri)
- [Sık Sorulan Sorular](#sık-sorulan-sorular)
- [Sorumluluk Reddi](#sorumluluk-reddi)
- [Lisans](#lisans)

---

## Dosyalar

| Dosya | Görevi |
|---|---|
| `perf-ayarlari.ps1` | Performans ayarlarını uygular, yedek alır |
| `geri-al.ps1` | Yedekten tüm değişiklikleri geri alır |
| `perf-yedek.json` | Script çalışınca **Masaüstünde** otomatik oluşur, orijinal ayarları tutar |

## Gereksinimler

- Windows 10 veya Windows 11
- Windows PowerShell 5.1 (Windows ile birlikte gelir)
- **Yönetici (Administrator)** yetkisi

## Kullanım

1. Repoyu indirin veya iki `.ps1` dosyasını bir klasöre kaydedin.
2. Başlat menüsüne `PowerShell` yazın, **sağ tıklayın ve "Yönetici olarak çalıştır"** seçin.
3. Şu komutları çalıştırın (klasör yolunu dosyaları kaydettiğiniz yere göre değiştirin):

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd $env:USERPROFILE\Downloads
.\perf-ayarlari.ps1
```

4. Script bazı adımlarda soru sorar. Evet için `e`, hayır için `h` yazın.
5. İşlem bitince **bilgisayarı yeniden başlatın**.

> `Set-ExecutionPolicy -Scope Process Bypass` sadece o PowerShell penceresi için geçerlidir. Pencereyi kapattığınızda sisteminizin script politikası eski haline döner.

---

## Yapılan Değişiklikler

### 1. Geri yükleme noktası

| İşlem | Neden |
|---|---|
| Sistem sürücüsünde Sistem Koruması açılır | Geri yükleme noktası oluşturulabilmesi için gereklidir |
| "Performans ayarlari oncesi" adlı geri yükleme noktası oluşturulur | Bir sorun çıkarsa Windows'u bu ana döndürebilmek için |

Windows varsayılan olarak 24 saat içinde yalnızca bir geri yükleme noktası oluşturmaya izin verir. Nokta oluşturulamazsa script uyarı verir ve devam edip etmeyeceğinizi sorar.

### 2. Güç planı

*Sorulur.*

| İşlem | Neden |
|---|---|
| **Yüksek Performans** güç planı etkinleştirilir. Planın gizli olduğu cihazlarda şablondan oluşturulur. | İşlemcinin hız düşürmesini (throttling) azaltır, tepki süresini iyileştirir |

Dizüstü bilgisayarlarda pil daha hızlı tükenir. Önceki güç planının GUID'i yedeğe kaydedilir.

### 3. Otomatik kapatılan hizmetler

Bu hizmetler çoğu kullanıcı için gereksizdir ve sorulmadan kapatılır.

| Hizmet adı | Görünen ad | Yeni durum | Neden |
|---|---|---|---|
| `DiagTrack` | Connected User Experiences and Telemetry | Devre dışı | Microsoft'a telemetri verisi gönderir; CPU, disk ve ağ kullanır |
| `dmwappushservice` | Device Management WAP Push | Devre dışı | Telemetriyle ilişkili mesaj yönlendirme hizmeti |
| `MapsBroker` | Downloaded Maps Manager | Devre dışı | Çevrimdışı harita indirme; neredeyse kullanılmaz |
| `RetailDemo` | Retail Demo Service | Devre dışı | Yalnızca mağaza vitrin bilgisayarları için |
| `Fax` | Fax | Devre dışı | Faks hizmeti |
| `RemoteRegistry` | Remote Registry | Devre dışı | Kayıt defterine uzaktan erişim; gereksiz ve güvenlik riski |
| `WerSvc` | Windows Error Reporting | El ile | Tamamen kapatılmaz, yalnızca ihtiyaç olduğunda çalışır |

### 4. İsteğe bağlı hizmetler

Bunlar kullanıma göre değiştiği için script önce sorar.

| Soru | Etkilenen hizmet(ler) | Ne zaman "evet" denmeli | Etkisi |
|---|---|---|---|
| Xbox kullanmıyor musun? | `XblAuthManager`, `XblGameSave`, `XboxNetApiSvc`, `XboxGipSvc` | Xbox uygulaması, Game Pass veya Xbox kumandası kullanmıyorsanız | Xbox oturumu, bulut kayıtları ve kumanda desteği çalışmaz |
| Yazıcı kullanmıyor musun? | `Spooler` | Hiç yazıcı kullanmıyorsanız | Yazdırma ve "PDF olarak yazdır" çalışmaz |
| Windows SSD'de mi? | `SysMain` (Superfetch) | Windows **SSD**'deyse. HDD'de kapatmayın. | SSD'de gereksiz disk aktivitesi azalır |
| İndeksleme kapatılsın mı? | `WSearch` | Disk kullanımı sürekli yüksekse | Disk yükü azalır, Başlat ve Dosya Gezgini araması yavaşlar |

### 5. Arayüz ve arka plan ayarları

Tüm değişiklikler yalnızca mevcut kullanıcıyı (`HKCU`) etkiler.

| Kayıt defteri yolu | Değer | Yeni | Neden |
|---|---|---|---|
| `HKCU:\Control Panel\Desktop` | `MenuShowDelay` | `100` | Menü açılma gecikmesi 400 ms'den 100 ms'ye iner |
| `HKCU:\Control Panel\Desktop\WindowMetrics` | `MinAnimate` | `0` | Pencere küçültme/büyütme animasyonu kapanır |
| `HKCU:\...\Explorer\Advanced` | `TaskbarAnimations` | `0` | Görev çubuğu animasyonları kapanır |
| `HKCU:\Software\Microsoft\GameBar` | `AutoGameModeEnabled` | `1` | Oyun Modu açılır, oyunlara kaynak önceliği verilir |
| `HKCU:\System\GameConfigStore` | `GameDVR_Enabled` | `0` | Arka planda oyun kaydı kapanır, FPS kaybı azalır |
| `HKCU:\...\CurrentVersion\GameDVR` | `AppCaptureEnabled` | `0` | Uygulama ekran yakalama kapanır |
| `HKCU:\...\BackgroundAccessApplications` | `GlobalUserDisabled` | `1` | Mağaza uygulamalarının arka planda çalışması engellenir (en çok Windows 10'da etkili) |
| `HKCU:\...\AdvertisingInfo` | `Enabled` | `0` | Reklam kimliği kapanır |
| `HKCU:\...\ContentDeliveryManager` | `SystemPaneSuggestionsEnabled` | `0` | Başlat menüsü önerileri kapanır |
| `HKCU:\...\ContentDeliveryManager` | `SubscribedContent-338389Enabled` | `0` | Windows ipuçları ve öneri bildirimleri kapanır |
| `HKCU:\...\ContentDeliveryManager` | `SilentInstalledAppsEnabled` | `0` | Windows'un kendiliğinden uygulama yüklemesi engellenir |

> `...` ile kısaltılan yollar `HKCU:\Software\Microsoft\Windows\CurrentVersion\` altındadır.

Bir değer daha önce hiç yoksa yedeğe "yoktu" olarak kaydedilir. Geri alma sırasında bu değer silinir.

### 6. Geçici dosya temizliği

| İşlem | Neden |
|---|---|
| `%TEMP%` (kullanıcı) ve `C:\Windows\Temp` klasörleri boşaltılır | Disk alanı açar. Kullanımdaki dosyalar atlanır. Script ne kadar yer açıldığını gösterir. |

Bu adım geri alınamaz, ancak silinen dosyalar zaten geçici dosyalardır.

### 7. Disk optimizasyonu

*Sorulur.*

| İşlem | Neden |
|---|---|
| Sistem diski için `Optimize-Volume` çalıştırılır | SSD'de **TRIM**, HDD'de **birleştirme (defrag)** yapılır. Disk türünü Windows kendisi algılar. |

HDD'de bu işlem uzun sürebilir.

### 8. Başlangıç uygulamaları

| İşlem | Neden |
|---|---|
| Bilgisayar açılırken çalışan programlar **listelenir, değiştirilmez** | Açılış hızını en çok etkileyen şey budur, ama hangi programa ihtiyacınız olduğuna siz karar vermelisiniz |

Gereksiz olanları **Görev Yöneticisi → Başlangıç uygulamaları** bölümünden devre dışı bırakın. Discord, Spotify, Steam, Epic Games ve OneDrive genelde güvenle kapatılabilir. Ses ve ekran kartı yazılımlarına dokunmayın.

---

## Geri Alma

İki yöntem vardır.

### Yöntem 1: `geri-al.ps1` (önerilen)

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd $env:USERPROFILE\Downloads
.\geri-al.ps1
```

Bu script şunları yapar:
- Önceki güç planını etkinleştirir.
- Her hizmetin başlangıç türünü eski haline getirir. Önceden "Otomatik" olanları ayrıca başlatır.
- Kayıt defteri değerlerini eski haline getirir; önceden olmayanları siler.
- Yedek dosyasını `perf-yedek-geri-alindi-TARIH.json` olarak yeniden adlandırır, böylece ayarları daha sonra tekrar uygulayabilirsiniz.

İşlem bitince bilgisayarı yeniden başlatın.

### Yöntem 2: Sistem Geri Yükleme

Başlat menüsüne **"Geri yükleme noktası oluştur"** yazın, **Sistem Geri Yükleme**'ye tıklayın ve **"Performans ayarlari oncesi"** noktasını seçin.

---

## Bilerek Dokunulmayanlar

| Ayar | Neden dokunulmadı |
|---|---|
| Windows Defender | Kapatmak kayda değer performans sağlamaz, sistemi virüslere açık bırakır |
| Windows Update | Güvenlik yamaları kritiktir |
| Sürücüler | Yanlış müdahale donanım sorunlarına yol açar |
| Sanal bellek (pagefile) | Yanlış ayarlanırsa çökmelere ve uygulama kapanmalarına neden olur |
| Hazırda bekletme / Hızlı Başlatma | Açılış davranışını değiştirir, faydası donanıma göre değişir |
| Görsel efektlerin tamamı | Yazı tipi yumuşatma gibi okunabilirliği etkileyen ayarlar korunur |

---

## Güvenlik Önlemleri

- Script yönetici yetkisi olmadan **çalışmaz**.
- Masaüstünde zaten bir `perf-yedek.json` varsa script **durur**. Böylece ikinci çalıştırmada orijinal ayarların yedeği ezilmez.
- Yedek dosyası her adımdan sonra kaydedilir. Script yarıda kesilse bile o ana kadarki değişiklikler geri alınabilir.
- Bir hizmet veya ayar bilgisayarda yoksa ya da değiştirilemezse hata vermek yerine uyarı gösterip devam eder.

---

## Sık Sorulan Sorular

**Script'i ikinci kez çalıştırabilir miyim?**
Önce `geri-al.ps1`'i çalıştırın ya da Masaüstündeki `perf-yedek.json` dosyasını başka bir yere taşıyın. Aksi halde script, orijinal yedeği korumak için durur.

**"Bu sistemde script çalıştırma devre dışı" hatası alıyorum.**
Diğer komutlardan önce `Set-ExecutionPolicy -Scope Process Bypass -Force` satırını çalıştırdığınızdan emin olun.

**Konsolda Türkçe karakterler bozuk görünüyor.**
Script çıktıları bu sorunu önlemek için bilerek Türkçe özel karakter kullanmaz.

**Yazıcım / Xbox kumandam çalışmıyor.**
İlgili soruya "evet" demiş olabilirsiniz. `geri-al.ps1`'i çalıştırın veya `services.msc`'den ilgili hizmeti **Otomatik** yapıp başlatın.

**Windows SSD'de mi HDD'de mi, nasıl anlarım?**
Görev Yöneticisi → Performans → Disk 0 bölümünde sağ üstte "SSD" veya "HDD" yazar.

---

## Sorumluluk Reddi

Bu script yaygın ve güvenli kabul edilen ayarları değiştirir; her değişiklik yedeklenir ve geri alınabilir. Yine de her sistem farklıdır. Kullanım sorumluluğu size aittir. Çalıştırmadan önce scripti okumanız önerilir.

## Lisans

[MIT Lisansı](LICENSE) ile yayınlanmıştır. Telif hakkı (c) 2026 Kaan Semih Kurt.
