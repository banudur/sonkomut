# Saklı Nesne

Ev içinde oynanan, çok oyunculu, yapay zekâ destekli nesne bulma oyunu. 7'den 70'e herkes için.

1. **Saklayan**, ebeler bakmazken evdeki bir nesneyi telefon kamerasıyla 1-3 açıdan tarar.
2. **Yapay zekâ** nesneyi tanır: "mavi vazo". Saklayan onaylar; yanlışsa doğrusunu seçer ya da yazar.
3. AI, her **yaş grubu** için 3 kademeli ipucu hazırlar. Nesnenin adını söylemez, çağrıştırır:
   *"Çiçekler bende su içer!"* → *"Gökyüzü gibi bir rengim var."* → *"Misafirler gelince beni görür."*
4. **Ebeler** evi dolaşıp şüphelendikleri nesneyi tarar. AI aynı nesne mi diye karşılaştırır
   (sadece aynı renk ya da tür yetmez).
5. İpucu isteyen ebe önce yaşına uygun kısa bir **zekâ oyunu** çözer: şekil matrisi (Raven tarzı),
   dönen şekil dizisi ya da parça birleştirme.
6. Doğru nesneyi **ilk tarayan** kazanır.

## Yapı

```
server/   Python (FastAPI + WebSocket): odalar, oyun kuralları, bulmaca üretimi/doğrulama, AI çağrıları
client/   Godot 4.5 projesi: arayüz, kamera, AR tarama efekti, bulmaca çizimi
docs/     protocol.md: istemci ↔ sunucu mesajları
```

API anahtarı yalnızca sunucuda durur. "Kim önce buldu" kararını ve bulmaca cevaplarını da
sunucu verir, yani istemci tarafında hile yapılamaz.

## Sunucuyu çalıştırma

**API anahtarı gerekmez.** Varsayılan yerel modda yapay zekâ bilgisayarda çalışır.

**Windows:** `server` klasöründeki **`baslat.bat`** dosyasına çift tıklayın. Python'u bulur,
paketleri kurar ve sunucuyu başlatır. Python yüklü değilse python.org'dan kurun ve kurulumda
"Add python.exe to PATH" kutusunu işaretleyin.

**Mac / Linux:**

```bash
cd server
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

İlk taramada küçük bir görüntü modeli (MobileNetV2, 14 MB) otomatik indirilir
ve `server/models/` klasörüne kaydedilir. Sonrasında internet gerekmez.

### Yapay zekâ modları (`AI_MODE`)

| Mod | Anahtar | Nasıl çalışır |
|---|---|---|
| `local` (varsayılan) | Gerekmez | Nesne türünü küçük bir model, rengi piksel analizi tanır. "Aynı nesne mi?" kararı ayırt edici desen noktalarının eşleştirilmesiyle verilir. İpuçları ~90 ev eşyası için elle yazılmış bilmece bankasından gelir. Katalogda olmayan nesnelerde harf ipucu verilir. |
| `claude` | `ANTHROPIC_API_KEY` | Claude görüntü API'si: daha isabetli tanıma ve her nesneye özel yaratıcı ipuçları. |
| `fake` | Gerekmez | Sadece test içindir, görüntüye bakmaz. |

Yerel modun sınırları: Model 1000 genel sınıf bildiği için bazı nesneleri yanlış adlandırabilir.
Bu yüzden saklayan, onay ekranında adı ve rengi düzeltebilir. Desensiz, tek renk nesnelerde
eşleştirme daha zordur; ebenin nesneyi yakından ve ortalayarak taraması gerekir.
Eşikler `server/app/local_ai.py` başında, gerçek cihazlarda denenip ayarlanmalıdır.

Testler (AI gerektirmez):

```bash
cd server && python -m pytest -q
```

Claude modunda kullanılan model `CLAUDE_MODEL` ortam değişkeniyle değiştirilebilir
(varsayılan `claude-opus-5-5`). Bir güvenlik sınıflandırıcısı isteği reddederse sunucu tarafında
önerilen yedek modele düşülür (`fallbacks: "default"`).

## İstemciyi çalıştırma

> **Oda kurmak için sunucunun çalışıyor olması gerekir.** Sunucu kapalıysa "Sunucuya
> bağlanılamadı" uyarısı çıkar.

1. Önce yukarıdaki gibi sunucuyu başlatın.
2. Godot 4.5 veya üstüyle `client/project.godot` dosyasını açın ve F5 ile çalıştırın.
3. Giriş ekranında **BAŞLAT** → adınızı ve yaş grubunuzu seçin → **Yeni Oda Kur**.
4. Aynı bilgisayarda sunucu adresi varsayılan olarak `ws://127.0.0.1:8000/ws`'dir.
   Telefondan bağlanırken *Bağlantı ayarları* altında `ws://<bilgisayarın-yerel-IP'si>:8000/ws` yazın.
5. Bilgisayarda kamera yoksa "Dosyadan Görüntü Seç (test)" ile deneme yapılabilir.

### Giriş ekranı, müzik ve tanıtım klibi

- Giriş ekranının arkasında oyunun akışını gösteren 16 saniyelik bir tanıtım animasyonu sürekli
  döner (`scripts/ui/attract_loop.gd`). Kodla çizildiği için dosya boyutu yoktur.
  Gerçek bir oyun kaydı kullanmak isterseniz videoyu Ogg Theora'ya çevirip
  `client/media/intro.ogv` olarak koyun, animasyonun yerine o oynatılır:
  `ffmpeg -i kayit.mp4 -vf scale=720:-2 -c:v libtheora -q:v 7 -an client/media/intro.ogv`
- Giriş müziği (`client/audio/intro_theme.ogg`) telif sorunu olmasın diye
  `tools/make_intro_music.py` ile kodla üretilmiş özgün bir parçadır. Menü ve lobide çalar,
  oyun sırasında susar. Giriş ekranındaki düğmeyle kapatılabilir.

### Telefona aktarma

- **Android**: Proje → Dışa Aktar → Android. *Permissions* altında **Camera** ve **Internet**
  izinlerini açın. Sunucu `ws://` (şifresiz) ise yerel ağ için açık metin trafiğine izin verilmelidir
  ya da sunucuyu `wss://` arkasına koyun.
- **iOS**: Dışa aktarmada *Privacy → Camera Usage Description* metnini doldurun.

## Durum ve bilinen eksikler

Bu bir **MVP iskeleti**:

- Sunucu tarafı (oyun akışı, bulmacalar, adil kazanan kuralı, WebSocket) testlerle doğrulandı.
- Godot istemcisi yazıldı ama bu ortamda Godot çalıştırılamadığı için **henüz editörde açılıp
  derlenmedi**. İlk açılışta küçük yazım düzeltmeleri gerekebilir.
- Godot'un mobil kamera desteği (`CameraFeed`) gerçek cihazda denenmeli. Görüntü yan dönük
  gelirse `camera_view.gd` içine döndürme eklenmeli. Bazı cihazlar ayrı Y/CbCr düzlemi verir;
  bunun için `shaders/ycbcr.gdshader` var.
- Gerçek AR (yüzey takibi, nesneye 3D işaret koymak) yok, sadece kamera üzerinde AR tarzı
  tarama efekti var. Oyun mantığı için gerekmiyor; ileride eklenebilir.
- Ses, çeviri ve hesap/oturum sistemi yok.

## Gizlilik

Ev içi fotoğraflar işleniyor ve oyuncular arasında çocuklar var:

- Fotoğraflar diske yazılmaz, sadece tur boyunca bellekte tutulur ve tur bitince silinir.
- AI'a insan, evcil hayvan, ekran ya da belge içeren görüntüleri reddetmesi söylenir.
- Varsayılan yerel modda fotoğraflar bilgisayardan hiç çıkmaz.
- Claude modunda fotoğraflar AI sağlayıcısına (Anthropic) gönderilir. Bu modla yayına almadan önce
  KVKK aydınlatma metni ve ebeveyn onayı eklenmeli.
