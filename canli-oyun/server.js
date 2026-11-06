// Kümes Sahnesi - TikTok canlı yayın köprüsü
// TikTok LIVE olaylarını (yorum, beğeni, hediye, takip, paylaşım) dinler ve
// WebSocket üzerinden oyun ekranına (public/index.html) iletir.
//
// Kullanım:  node server.js [tiktok_kullanici_adi]
// Sonra tarayıcıda:  http://localhost:8080        (oyun ekranı)
//                    http://localhost:8080/panel  (kontrol paneli)

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebSocketServer } from 'ws';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(__dirname, 'public');
const AYAR_DOSYASI = path.join(__dirname, 'ayarlar.json');
const PORT = Number(process.env.PORT) || 8080;

function ayarOku() {
  try { return JSON.parse(fs.readFileSync(AYAR_DOSYASI, 'utf8')); } catch { return {}; }
}
function ayarYaz(a) {
  try { fs.writeFileSync(AYAR_DOSYASI, JSON.stringify(a, null, 2)); } catch { /* önemsiz */ }
}
const ayarlar = ayarOku();

// ---------------------------------------------------------------- HTTP
const TIPLER = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
};

const sunucu = http.createServer((req, res) => {
  let yol = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (yol === '/') yol = '/index.html';
  if (yol === '/panel') yol = '/panel.html';
  const dosya = path.normalize(path.join(PUBLIC, yol));
  if (!dosya.startsWith(PUBLIC)) { res.writeHead(403).end(); return; }
  fs.readFile(dosya, (err, veri) => {
    if (err) { res.writeHead(404).end('Bulunamadı'); return; }
    res.writeHead(200, {
      'Content-Type': TIPLER[path.extname(dosya)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(veri);
  });
});

// ---------------------------------------------------------------- WebSocket
const wss = new WebSocketServer({ server: sunucu, path: '/ws' });

function yayinla(mesaj) {
  const s = JSON.stringify(mesaj);
  for (const c of wss.clients) if (c.readyState === 1) c.send(s);
}

let durum = { type: 'durum', baglanti: 'kapali', kullanici: ayarlar.kullanici || '', mesaj: 'Bağlı değil' };
function durumGuncelle(baglanti, mesaj) {
  durum = { type: 'durum', baglanti, kullanici: hedefKullanici, mesaj };
  console.log(`[durum] ${baglanti}: ${mesaj}`);
  yayinla(durum);
}

wss.on('connection', (ws) => {
  ws.send(JSON.stringify(durum));
  ws.on('message', (ham) => {
    let m;
    try { m = JSON.parse(ham.toString()); } catch { return; }
    if (m.type === 'baglan' && typeof m.kullanici === 'string') {
      tiktokBaglan(m.kullanici);
    } else if (m.type === 'kes') {
      tiktokKes();
    } else if (m.type === 'komut' || m.type === 'olay') {
      // Panelden gelen komutları / deneme olaylarını oyun ekranlarına aktar
      yayinla(m);
    }
  });
});

// ---------------------------------------------------------------- TikTok
let baglanti = null;
let hedefKullanici = ayarlar.kullanici || '';
let yenidenDene = null;
let istenenAcik = false;

function kullaniciBilgisi(d) {
  return {
    id: String(d.uniqueId || d.userId || d.nickname || 'misafir'),
    ad: String(d.nickname || d.uniqueId || 'Misafir').slice(0, 24),
    foto: d.profilePictureUrl || '',
  };
}

async function tiktokBaglan(kullanici) {
  kullanici = String(kullanici || '').trim().replace(/^@/, '');
  if (!kullanici) { durumGuncelle('hata', 'Kullanıcı adı boş'); return; }
  await tiktokKes(true);
  hedefKullanici = kullanici;
  istenenAcik = true;
  ayarlar.kullanici = kullanici;
  ayarYaz(ayarlar);

  let WebcastPushConnection, SignConfig;
  try {
    ({ WebcastPushConnection } = await import('tiktok-live-connector/legacy'));
    ({ SignConfig } = await import('tiktok-live-connector'));
  } catch (e) {
    durumGuncelle('hata', 'tiktok-live-connector yüklenemedi. "npm install" çalıştırdınız mı?');
    return;
  }
  const anahtar = process.env.EULER_API_KEY || ayarlar.eulerApiKey;
  if (anahtar && SignConfig) SignConfig.apiKey = anahtar;

  durumGuncelle('baglaniyor', `@${kullanici} yayınına bağlanılıyor...`);
  const b = new WebcastPushConnection(kullanici, {
    processInitialData: false,
    enableExtendedGiftInfo: true,
  });
  baglanti = b;

  b.on('chat', (d) => {
    yayinla({ type: 'olay', tur: 'yorum', kisi: kullaniciBilgisi(d), metin: String(d.comment || '').slice(0, 120) });
  });

  b.on('gift', (d) => {
    // Seri hediyelerde (giftType 1) yalnızca seri bittiğinde say
    if (d.giftType === 1 && !d.repeatEnd) {
      yayinla({ type: 'olay', tur: 'hediyeSuruyor', kisi: kullaniciBilgisi(d), hediye: d.giftName || 'Hediye' });
      return;
    }
    const tek = Number(d.diamondCount ?? d.extendedGiftInfo?.diamond_count ?? 1) || 1;
    const adet = Number(d.repeatCount) || 1;
    yayinla({
      type: 'olay', tur: 'hediye', kisi: kullaniciBilgisi(d),
      hediye: d.giftName || d.extendedGiftInfo?.name || 'Hediye',
      adet, jeton: tek * adet,
    });
  });

  b.on('like', (d) => {
    yayinla({ type: 'olay', tur: 'begeni', kisi: kullaniciBilgisi(d), adet: Number(d.likeCount) || 1 });
  });

  b.on('follow', (d) => yayinla({ type: 'olay', tur: 'takip', kisi: kullaniciBilgisi(d) }));
  b.on('share', (d) => yayinla({ type: 'olay', tur: 'paylasim', kisi: kullaniciBilgisi(d) }));
  b.on('member', (d) => yayinla({ type: 'olay', tur: 'giris', kisi: kullaniciBilgisi(d) }));
  b.on('roomUser', (d) => yayinla({ type: 'olay', tur: 'izleyici', sayi: Number(d.viewerCount) || 0 }));

  b.on('streamEnd', () => {
    durumGuncelle('kapali', 'Yayın sona erdi');
    istenenAcik = false;
  });
  b.on('disconnected', () => {
    if (baglanti !== b) return;
    if (istenenAcik) {
      durumGuncelle('baglaniyor', 'Bağlantı koptu, 10 sn sonra tekrar denenecek');
      yenidenDene = setTimeout(() => tiktokBaglan(hedefKullanici), 10000);
    }
  });
  b.on('error', (e) => console.warn('[tiktok hata]', e?.message || e));

  try {
    const st = await b.connect();
    if (baglanti !== b) return;
    durumGuncelle('bagli', `@${kullanici} yayınına bağlandı (oda ${st.roomId})`);
  } catch (e) {
    if (baglanti !== b) return;
    const msg = String(e?.message || e);
    let aciklama = msg;
    if (/offline|not live|LIVE has ended|isn't online/i.test(msg)) aciklama = 'Kullanıcı şu anda canlı yayında değil';
    else if (/sign|rate limit|429|api key/i.test(msg)) aciklama = 'İmza sunucusu reddetti: eulerstream.com\'dan ücretsiz API anahtarı alıp ayarlar.json içine "eulerApiKey" olarak yazın. (' + msg + ')';
    durumGuncelle('hata', aciklama);
    if (istenenAcik) yenidenDene = setTimeout(() => tiktokBaglan(hedefKullanici), 20000);
  }
}

async function tiktokKes(sessiz = false) {
  istenenAcik = false;
  clearTimeout(yenidenDene);
  const b = baglanti;
  baglanti = null;
  if (b) { try { await b.disconnect(); } catch { /* yoksay */ } }
  if (!sessiz) durumGuncelle('kapali', 'Bağlantı kesildi');
}

sunucu.listen(PORT, () => {
  console.log('');
  console.log('  Kümes Sahnesi çalışıyor!');
  console.log(`  Oyun ekranı : http://localhost:${PORT}`);
  console.log(`  Kontrol     : http://localhost:${PORT}/panel`);
  console.log('');
  const ilk = process.argv[2] || process.env.TIKTOK_KULLANICI;
  if (ilk) tiktokBaglan(ilk);
  else if (ayarlar.kullanici) console.log(`  Son kullanılan hesap: @${ayarlar.kullanici} (panelden "Bağlan"a basın)`);
});
