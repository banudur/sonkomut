# 🐔 Kümes Sahnesi: TikTok Canlı Yayın Oyunu

İzleyicilerin yorum, beğeni ve hediyeleriyle yönettiği tavuk oyunu. İki sahnesi var:

- **Tavuk Horonu**: Yaylada tavuklar el (kanat) ele tutuşup 7/16 aksak ritimle horon teper.
  Ortada Kemençeci Horoz çalar. Tempo yükselince tavuklar meşhur "titreme"ye geçer.
- **Hamam Disko**: Göbek taşında DJ Tellak, tavanda disko topu, tavuklar peştemalle ve güneş gözlüğüyle dans eder.

| Tavuk Horonu | Mahalle Kavgası | Hamam Disko |
|---|---|---|
| ![](ekran/a_horon.png) | ![](ekran/b_kavga.png) | ![](ekran/c_hamam.png) |

## İzleyici ne yapınca ne olur?

| İzleyici | Oyunda |
|---|---|
| Yorum yazar | Kendi adıyla bir tavuk halkaya katılır, yorumu konuşma balonunda çıkar, zıplar |
| `kavga` yazar | Tavuğu rastgele birine dalar. `kavga @isim` yazarsa o kişiye dalar. Toz bulutu, POW/GÜM, uçuşan tüyler; kaybeden bayılır |
| `yumurta` yazar | Tavuğu gıdaklayarak yumurtlar |
| `çıldır` yazar | Tavuğu birkaç saniye çıldırır (20 sn bekleme süresi var) |
| Beğeni | Tempo göstergesi dolar, müzik ve dans hızlanır |
| Hediye (1+ jeton) | Gönderenin tavuğu ÇILDIRIR: deli gibi koşar, kanat çırpar, tüy saçar. Jeton arttıkça süre uzar |
| 30+ jeton | Konfeti, herkes zıplar |
| 99+ jeton | **MAHALLE KAVGASI** (herkes birbirine girer) veya **TOPLU ÇILGINLIK**. 300+ jetonda ikisi birden |
| 500+ jeton | Havai fişek ve kalıcı **altın taç**. Altın taçlı tavuk kavgalarda daha güçlüdür |
| Takip / Paylaşım | Kalpler / yumurta yağmuru |

Ayrıca her 20-30 saniyede bir rastgele iki tavuk kendiliğinden kavgaya tutuşur.
Hediye gönderenler kavgalarda daha şanslıdır. Lider tablosunda (Kümes Kralları) puanlar görünür.

## Kurulum

1. [Node.js](https://nodejs.org) LTS sürümünü kurun.
2. **Windows:** `canli-oyun` klasöründeki **`baslat.bat`** dosyasına çift tıklayın.
   Paketleri kurar, sunucuyu başlatır ve kontrol panelini açar.
   **Mac/Linux:** `npm install` ve ardından `npm start` komutlarını çalıştırın.
3. TikTok'ta canlı yayını başlatın.
4. Kontrol panelinde (`http://localhost:8080/panel`) kullanıcı adınızı yazıp **Bağlan**'a basın.

## Yayına ekleme

- **OBS / Streamlabs:** Kaynak ekle → *Tarayıcı* → URL `http://localhost:8080`, genişlik **720**, yükseklik **1280**.
  "Sesi OBS üzerinden kontrol et" kutusunu işaretlerseniz müzik yayına gider.
- **TikTok LIVE Studio:** Chrome'da `http://localhost:8080` adresini ayrı bir pencerede açın, pencereyi dikey yapın ve
  *Pencere yakalama* ile ekleyin. Müziğin başlaması için oyun ekranına bir kez tıklayın.

Kontrol panelini ayrı bir sekmede tutun. Sahne değiştirme, demo modu ve deneme olayları oradadır.
Yayına çıkmadan önce **Demo** kutusunu açarak oyunu sahte izleyicilerle deneyebilirsiniz.

Oyun ekranı kısayolları: **M** sahne değiştir, **D** demo, **S** ses, **1-7** deneme olayları.
Adres sonuna `?mod=hamam` eklenirse Hamam Disko ile başlar, `?demo=1` eklenirse demo açık başlar.

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
public/oyun.js     Oyun: tavuklar, dans, kavga, sahneler, arayüz
public/ses.js      Kodla üretilen müzik (horon ve disko) ve efektler
```
