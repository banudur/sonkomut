# 🐔 Kümes Sahnesi: Tavuk Horonu

TikTok canlı yayını için, izleyicilerin yorum, beğeni ve hediyeleriyle yönettiği tavuk horonu oyunu.

Yaylada tavuklar kanat kanada tutuşup 7/16 aksak ritimle horon teper. Ortada **gelin ile damat** dans eder,
yanlarında **kemençeci** ve **davulcu** çalar; izleyiciler hediyeyle bu rolleri kapabilir. Kavgalar halkanın altındaki çitli
**Kavga Meydanı**'nda olur, horon bozulmaz. Tempo yükselince tavuklar meşhur "titreme"ye geçer.

| Gelin, damat ve çalgıcılar | Mahalle kavgası |
|---|---|
| ![](ekran/a_horon.png) | ![](ekran/b_kavga.png) |

## İzleyici ne yapınca ne olur?

| İzleyici | Oyunda |
|---|---|
| Yorum yazar | Kendi adıyla bir tavuk halkaya katılır, yorumu konuşma balonunda çıkar, zıplar |
| `kavga` yazar | Tavuğu rastgele biriyle Kavga Meydanı'na iner. `kavga @isim` yazarsa o kişiyle. Toz bulutu, POW/GÜM, uçuşan tüyler; kaybeden bayılır |
| `şarkı` yazar | Sıradaki şarkıya geçilir (herkes için 15 sn bekleme). `türkü` ve `müzik` de olur |
| `yumurta` yazar | Tavuğu gıdaklayarak yumurtlar |
| `çıldır` yazar | Tavuğu birkaç saniye çıldırır (20 sn bekleme) |
| `gelin` / `damat` / `davul` / `kemençe` yazar | Tavuğu o rolün kaç jeton olduğunu söyler |
| Beğeni | Tempo göstergesi dolar, müzik ve dans hızlanır |
| Takip / Paylaşım | Kalpler / yumurta yağmuru |

## Hediyeler

| Hediye | Oyunda |
|---|---|
| 1-4 jeton | Gönderenin tavuğu **çıldırır**: deli gibi koşar, kanat çırpar, tüy saçar |
| **5-9 jeton** | 🥁 **Davulcu olur** (3 dk). Tokmakla 2+2+3 vuruşlarında davula vurur. Davulcuyken `şov` yazarsa yere yatıp havada davul çalar |
| **10-19 jeton** | 🎻 **Kemençeci olur** (3 dk) |
| **20-29 jeton** | 🤵 **Damat olur** (3 dk): siyah yelek, papyon, yaka çiçeği |
| **30-98 jeton** | 👰 **Gelin olur** (3 dk): duvak, taç, gelinlik, kırmızı kuşak, buket. Ayrıca konfeti |
| **99+ jeton** | 🥊 **Mahalle kavgası**: tavuklar ikişer ikişer Kavga Meydanı'na iner |
| **500+ jeton** | Havai fişek ve kalıcı **altın taç**. Altın taçlı tavuk kavgalarda daha güçlüdür |

Her rolde tek kişi olur: **son hediye atan rolü kapar**, öncekinin tavuğu "Gelinliğimi kaptılar! 😭" ya da
"Davulumu kaptılar! 😤" diyerek halaya döner. Aynı kişi tekrar atarsa süresi uzar. Rol boşken Gelin Tavuk,
Damat Horoz, Kemençeci Horoz ve Davulcu Horoz yerinde durur. Gelin ve damat kanat kanada salınır,
aralarından kalpler uçar. **İkisi de izleyiciyse "DÜĞÜN VAR!"** kutlaması olur (konfeti, kalpler, fanfar).
Rol sahipleri kavgaya girmez.

**Düğün kamerası:** Arada bir sahne düğün videocusu gibi yakına çekilir; köşelerde kamera çerçevesi ve yanıp sönen
● REC görünür. Her 25-40 saniyede bir rastgele bir izleyicinin tavuğuna yaklaşır (tavuk kameraya el sallar),
davulcu yerde çalarken ona, kavgada Kavga Meydanı'na, düğün olunca gelin ile damada döner. Üstteki tablolar
sabit kalır. Kontrol panelindeki **🎥 Düğün kamerası** kutusuyla kapatılabilir.

**Davulcu şovu:** Davulcu her 20-30 saniyede bir sırtüstü yere yatar, davulu havaya kaldırıp alttan çalar,
ayaklarıyla tempo tutar ("ŞOV!", "DÜM! TAK!"). Şov boyunca tavuklar coşar ve tempo yükselir. Davulcu rolündeki
izleyici `şov` yazarak da başlatabilir (şovlar arasında 10 sn bekleme var).

Ayrıca her 20-30 saniyede bir rastgele iki tavuk kendiliğinden kavgaya tutuşur. Hediye gönderenler kavgalarda
daha şanslıdır. Lider tablosunda (Kümes Kralları) puanlar görünür.

Jeton eşikleri `public/oyun.js` içinde `DAVUL_JETON`, `KEMENCE_JETON`, `DAMAT_JETON` ve `GELIN_JETON` sabitlerindedir.

## Şarkılar

Ekranın sağında **ŞİMDİ ÇALIYOR** kutusu var. `şarkı` yazılınca ya da paneldeki **🎵 Şarkı değiştir**
düğmesine basılınca sıradaki şarkıya geçilir.

- **Kendi türküleriniz:** `public/muzik` klasörüne `.mp3`, `.m4a`, `.ogg` veya `.wav` dosyaları koyun.
  Dosya adı ekranda şarkı adı olarak görünür (`01 Ben Giderim Batuma.mp3` → "Ben Giderim Batuma";
  baştaki numara yalnızca sırayı belirler). Oyun açılınca ilk dosya çalar. Dosya ekledikten sonra
  oyun sayfasını yenileyin.
- **Hazır horon havaları:** Dosyalardan sonra oyunun kodla çaldığı dört hava gelir: Dik Horon, Sıksara,
  Tulum Havası ve Ağır Horon. Klasör boşsa oyun bunlarla açılır.

Başkasına ait kayıtları yayında çalmak telif sorununa yol açabilir; TikTok bu durumda yayının sesini kısabilir.
Mümkünse kendi kayıtlarınızı ya da kullanım izni olan müzikleri kullanın.

## Kurulum

1. [Node.js](https://nodejs.org) LTS sürümünü kurun.
2. **Windows:** `canli-oyun` klasöründeki **`baslat.bat`** dosyasına çift tıklayın.
   Paketleri kurar, sunucuyu başlatır ve kontrol panelini açar.
   **Mac/Linux:** `npm install` ve ardından `npm start` komutlarını çalıştırın.
3. TikTok'ta canlı yayını başlatın.
4. Kontrol panelinde (`http://localhost:8080/panel`) kullanıcı adınızı yazıp **Bağlan**'a basın.

## Yayına ekleme

- **TikTok LIVE Studio:** Chrome'da `http://localhost:8080` adresini ayrı, dikey bir pencerede açın ve
  *Pencere yakalama* ile ekleyin. Kamera kaynağı eklemeyin. Müziğin başlaması için oyun ekranına bir kez tıklayın.
  Oyun penceresini simge durumuna küçültmeyin; küçültülen sayfada animasyon durur.
- **OBS / Streamlabs:** Kaynak ekle → *Tarayıcı* → URL `http://localhost:8080`, genişlik **720**, yükseklik **1280**.
  "Sesi OBS üzerinden kontrol et" kutusunu işaretlerseniz müzik yayına gider.

Kontrol panelini oyundan ayrı bir pencerede tutun. Şarkı değiştirme, demo modu ve deneme olayları oradadır.
Yayına çıkmadan önce **Demo** kutusunu açarak oyunu sahte izleyicilerle deneyebilirsiniz; yayında kapatın.

Oyun ekranı kısayolları: **0** şarkı değiştir, **D** demo, **S** ses, **1-9** deneme olayları
(1 yorum, 2 kavga, 3 beğeni, 4 1 jeton, 5 99 jeton, 6 500 jeton, 7 yumurta, 8 5 jeton, 9 10 jeton).
Adres sonuna `?demo=1` eklenirse demo açık başlar.

## Bağlantı sorunları

TikTok'un resmî bir canlı yayın API'si yok. Bağlantı açık kaynak
[tiktok-live-connector](https://github.com/zerodytrash/TikTok-Live-Connector) kütüphanesiyle kurulur.
İmza sunucusu reddederse [eulerstream.com](https://www.eulerstream.com)'dan ücretsiz API anahtarı alıp
`ayarlar.json` dosyasına şöyle yazın:

```json
{ "kullanici": "tiktok_adiniz", "eulerApiKey": "ANAHTAR" }
```

## Dosyalar

```
server.js          TikTok köprüsü + web sunucusu (port 8080)
public/index.html  Oyun ekranı (yayına eklenen sayfa)
public/panel.html  Kontrol paneli
public/oyun.js     Oyun: tavuklar, horon, gelin-damat ve çalgıcılar, kavga meydanı, arayüz
public/ses.js      Horon havaları, şarkı dosyalarını çalma ve efektler
public/muzik/      Kendi türkü dosyalarınız
```
