# Saklı Nesne

Ev içinde oynanan, çok oyunculu, yapay zekâ destekli nesne bulma oyunu. 7'den 70'e herkes için.

1. **Saklayan**, ebeler bakmazken evdeki bir nesneyi telefon kamerasıyla 1-3 açıdan tarar.
2. **Yapay zekâ** (Claude görüntü API'si) nesneyi tanır: "mavi seramik vazo". Saklayan onaylar.
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

```bash
cd server
pip install -r requirements-dev.txt
export ANTHROPIC_API_KEY=...      # ya da: AI_MODE=fake (AI'sız deneme)
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Testler (AI gerektirmez):

```bash
cd server && python -m pytest -q
```

`AI_MODE=fake` modunda AI görüntüye bakmaz: nesne hep "mavi seramik vazo" olur ve ebe,
saklayanın gönderdiği fotoğraflardan biriyle **aynı** görüntüyü tararsa eşleşme sayılır.
Akışı uçtan uca denemek için iki istemcide aynı test görüntüsünü "Dosyadan seç" ile seçmek yeterli.

Kullanılan model `CLAUDE_MODEL` ortam değişkeniyle değiştirilebilir (varsayılan `claude-opus-5-5`).
Bir güvenlik sınıflandırıcısı isteği reddederse sunucu tarafında önerilen yedek modele düşülür
(`fallbacks: "default"`).

## İstemciyi çalıştırma

1. Godot 4.5 veya üstüyle `client/project.godot` dosyasını açın.
2. Oyunu çalıştırın. Menüde **Sunucu adresi** alanına `ws://<bilgisayarın-yerel-IP'si>:8000/ws` yazın.
3. Bilgisayarda kamera yoksa "Dosyadan Görüntü Seç (test)" ile deneme yapılabilir.

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
- Fotoğraflar AI sağlayıcısına (Anthropic) gönderilir. Yayına almadan önce KVKK aydınlatma
  metni ve ebeveyn onayı eklenmeli.
