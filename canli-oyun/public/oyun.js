// Kümes Sahnesi: TikTok canlı yayın için etkileşimli tavuk oyunu
// Modlar: "horon" (yaylada tavuk horonu) ve "hamam" (hamamda disko)
import { Ses } from './ses.js';

const W = 720, H = 1280;
const tuval = document.getElementById('oyun');
const ctx = tuval.getContext('2d');
const ses = new Ses();

const MERKEZ = { x: 360, y: 820 };
const HALKA_DIS = { rx: 300, ry: 165 };
const HALKA_IC = { rx: 195, ry: 105 };
const DIS_KAPASITE = 30;
const MAKS_TAVUK = 64;

const S = {
  mod: 'horon',
  zaman: 0,
  dansZamani: 0,
  tempo: 15,
  halkaAci: 0,
  tavuklar: [],
  kimlik: new Map(),
  kavgalar: [],
  parcaciklar: [],
  yumurtalar: [],
  puanlar: new Map(),
  akis: [],
  manset: null,
  sarsinti: 0,
  flas: 0,
  fisekSure: 0,
  sonrakiOtoKavga: 25,
  demo: false,
  demoSayac: 0,
  izleyici: 0,
  otoMod: false,
  otoModSayac: 0,
};

// ------------------------------------------------------------------ yardımcılar
const rnd = (a, b) => a + Math.random() * (b - a);
const rint = (a, b) => Math.floor(rnd(a, b + 1));
const sec = (d) => d[Math.floor(Math.random() * d.length)];
const kis = (s) => String(s || '').toLocaleLowerCase('tr');
function ozet(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
function kisalt(s, n) { s = String(s); return s.length > n ? s.slice(0, n - 1) + '…' : s; }

const GOVDE_RENK = [
  ['#ffffff', '#e6e1d6'], ['#fff3d6', '#ecd9ad'], ['#c9773b', '#a95f2c'],
  ['#e9a24f', '#cf8638'], ['#3a3330', '#25201e'], ['#a8a39c', '#8a857f'],
  ['#d9c6a5', '#bfa984'], ['#8c4a2f', '#6e3823'],
];
const YAZMA_RENK = ['#d6336c', '#7048e8', '#f08c00', '#1c7ed6', '#2b8a3e', '#c92a2a', '#e64980'];

// ------------------------------------------------------------------ tavuk
function tavukOlustur(kisi, npc = false) {
  const h = ozet(kisi.id);
  const c = {
    id: kisi.id,
    ad: kisi.ad,
    npc,
    renk: GOVDE_RENK[h % GOVDE_RENK.length],
    kiyafet: (h >> 4) % 2,                 // 0: yazma/havlu, 1: yelek/peştemal
    yazma: YAZMA_RENK[(h >> 8) % YAZMA_RENK.length],
    faz: ((h >> 12) % 100) / 100,
    x: Math.random() < 0.5 ? -60 : W + 60,
    y: rnd(760, 1000),
    hx: 0, hy: 0,
    durum: 'halka',      // halka | cilgin | kavga | ko | zafer | gizli
    cilgin: 0,
    ko: 0,
    zafer: 0,
    ziplama: 0,
    vx: 0, vy: 0,
    yonDegis: 0,
    donus: 0,
    balon: null,
    sonAktif: S.zaman,
    altinTac: false,
    takipci: false,
    hediyeci: false,
    yuruyor: false,
    yumurtaBekleme: 0,
    kavgaBekleme: 0,
    cildirBekleme: 0,
    olcek: 1,
  };
  return c;
}

function tavukGetir(kisi, olustur = true) {
  let c = S.kimlik.get(kisi.id);
  if (c) {
    if (kisi.ad && kisi.ad !== c.ad) c.ad = kisi.ad;
    c.sonAktif = S.zaman;
    return c;
  }
  if (!olustur) return null;
  // Yer aç: önce NPC, sonra en uzun süredir sessiz olan
  const gercek = S.tavuklar.filter((t) => !t.npc).length;
  const npcler = S.tavuklar.filter((t) => t.npc);
  if (npcler.length && (S.tavuklar.length >= MAKS_TAVUK || gercek + npcler.length >= 10)) {
    tavukCikar(npcler[0]);
  } else if (S.tavuklar.length >= MAKS_TAVUK) {
    const aday = S.tavuklar
      .filter((t) => t.durum === 'halka' && !t.altinTac)
      .sort((a, b) => a.sonAktif - b.sonAktif)[0];
    if (aday) tavukCikar(aday);
  }
  c = tavukOlustur(kisi);
  S.tavuklar.push(c);
  S.kimlik.set(c.id, c);
  return c;
}

function tavukCikar(c) {
  for (let i = 0; i < 14; i++) parcacik('tuy', c.x, c.y - 30, { renk: c.renk[0] });
  parcacik('duman', c.x, c.y - 20);
  S.tavuklar.splice(S.tavuklar.indexOf(c), 1);
  S.kimlik.delete(c.id);
}

function npcEkle() {
  const adlar = ['Gıdık', 'Pıtırcık', 'Horoz Rıza', 'Fındık', 'Tüylü Temel', 'Hamsi', 'Cücük', 'Bıdık'];
  adlar.forEach((ad, i) => {
    const c = tavukOlustur({ id: 'npc_' + i, ad }, true);
    S.tavuklar.push(c);
    S.kimlik.set(c.id, c);
  });
}

function puanEkle(kisi, p) {
  const e = S.puanlar.get(kisi.id) || { ad: kisi.ad, puan: 0 };
  e.ad = kisi.ad || e.ad;
  e.puan += p;
  S.puanlar.set(kisi.id, e);
}

function balon(c, metin, sure = 3) { c.balon = { metin: kisalt(metin, 26), sure }; }

// halkadaki yerlerin hesaplanması
function yerleriHesapla() {
  const n = S.tavuklar.length;
  const dis = Math.min(n, DIS_KAPASITE);
  const ic = n - dis;
  S.tavuklar.forEach((c, i) => {
    let a, rx, ry;
    if (i < dis) {
      a = S.halkaAci + (i / dis) * Math.PI * 2;
      rx = HALKA_DIS.rx; ry = HALKA_DIS.ry;
    } else {
      const j = i - dis;
      a = -S.halkaAci * 1.3 + (j / ic) * Math.PI * 2;
      rx = HALKA_IC.rx; ry = HALKA_IC.ry;
    }
    c.halkaSira = i < dis ? i : i - dis;
    c.halkaIc = i >= dis;
    c.hx = MERKEZ.x + Math.cos(a) * rx;
    c.hy = MERKEZ.y + Math.sin(a) * ry;
  });
}

const derinlikOlcek = (y) => 0.72 + 0.42 * ((y - 600) / 460);

// ------------------------------------------------------------------ olaylar
function olayIsle(o) {
  switch (o.tur) {
    case 'yorum': yorum(o.kisi, o.metin || ''); break;
    case 'hediye': hediye(o.kisi, Number(o.jeton) || 1, o.hediye || 'Hediye', Number(o.adet) || 1); break;
    case 'hediyeSuruyor': {
      const c = tavukGetir(o.kisi);
      cildir(c, 2.5);
      break;
    }
    case 'begeni': begeni(o.kisi, Number(o.adet) || 1); break;
    case 'takip': takip(o.kisi); break;
    case 'paylasim': paylasim(o.kisi); break;
    case 'izleyici': S.izleyici = o.sayi; break;
  }
}

function yorum(kisi, metin) {
  const yeni = !S.kimlik.has(kisi.id);
  const c = tavukGetir(kisi);
  puanEkle(kisi, 1);
  if (yeni) {
    akisEkle(`${kisalt(kisi.ad, 16)} ${S.mod === 'horon' ? 'horona' : 'diskoya'} katıldı!`, '#9be15d');
    ses.gidak(2);
  }
  const k = kis(metin);
  if (/kavga|dövüş|dovus|kapış|kapis|savaş|savas|kafa at|🥊|👊/.test(k)) {
    kavgaIstegi(c, hedefBul(k, c));
  } else if (/yumurta|🥚/.test(k)) {
    yumurtla(c);
  } else if (/çıldır|cildir|deli|çıldırt|cildirt/.test(k)) {
    if (c.cildirBekleme <= 0) { cildir(c, 4); c.cildirBekleme = 20; }
    balon(c, 'GIDAAAK!!');
  } else if (/disko|disco/.test(k) && S.mod === 'horon') {
    balon(c, 'Hamama gidelim! 🪩');
    zipla(c);
  } else {
    zipla(c);
    if (metin.trim()) balon(c, metin);
    if (Math.random() < 0.3) ses.gidak(1);
  }
}

function hedefBul(k, ben) {
  const kelimeler = k.replace(/@/g, ' ').split(/\s+/).filter((w) => w.length >= 3 && !/kavga|dövüş|dovus|kapış|savaş|ile|benle|seninle/.test(w));
  for (const w of kelimeler) {
    const h = S.tavuklar.find((t) => t !== ben && (kis(t.ad).includes(w) || kis(t.id).includes(w)));
    if (h) return h;
  }
  return null;
}

function hediye(kisi, jeton, hediyeAdi, adet) {
  const c = tavukGetir(kisi);
  c.hediyeci = true;
  puanEkle(kisi, jeton * 10);
  S.tempo = Math.min(100, S.tempo + Math.min(35, 4 + jeton));
  const sure = Math.min(45, 6 + Math.log2(jeton + 1) * 4);
  cildir(c, sure);
  balon(c, sec(['GIDAAAK!!!', 'ÇILDIRDIM!', 'TUTMAYIN BENİ!', 'Hoppaaa!', 'Bok bok BOOOK!']), 3);
  akisEkle(`🎁 ${kisalt(kisi.ad, 14)}: ${adet > 1 ? adet + 'x ' : ''}${hediyeAdi} → ÇILDIRDI!`, '#ffd43b');
  for (let i = 0; i < 8 + Math.min(40, jeton); i++) parcacik('tuy', c.x, c.y - 30, { renk: c.renk[0] });
  parcacik('yazi', c.x, c.y - 100, { metin: `+${jeton * 10}`, renk: '#ffd43b', boyut: 30 });
  ses.gidak(3, 1.15);

  if (jeton >= 30) {
    konfeti(80 + Math.min(200, jeton));
    S.tavuklar.forEach((t) => zipla(t, rnd(0, 0.4)));
    ses.fanfar(false);
  }
  if (jeton >= 99) {
    const tur = jeton >= 300 ? 'ikisi' : sec(['kavga', 'cilgin']);
    if (tur === 'kavga' || tur === 'ikisi') {
      mansetGoster('MAHALLE KAVGASI!', `${kisalt(kisi.ad, 18)} ortalığı karıştırdı`, '#ff6b6b');
      topluKavga(c);
    }
    if (tur === 'cilgin' || tur === 'ikisi') {
      if (tur === 'cilgin') mansetGoster('TOPLU ÇILGINLIK!', `${kisalt(kisi.ad, 18)} herkesi çıldırttı`, '#da77f2');
      S.tavuklar.forEach((t) => { if (t.durum === 'halka') cildir(t, rnd(6, 10)); });
    }
    S.sarsinti = 0.8;
    ses.fanfar(true);
  }
  if (jeton >= 500) {
    c.altinTac = true;
    S.fisekSure = 8;
    mansetGoster('ALTIN TAVUK!', `${kisalt(kisi.ad, 18)} kümesin kralı oldu 👑`, '#ffd43b');
  }
}

function begeni(kisi, adet) {
  S.tempo = Math.min(100, S.tempo + Math.min(adet, 30) * 0.45);
  const c = tavukGetir(kisi, false);
  puanEkle(kisi, Math.min(adet, 15) * 0.2);
  const x = c ? c.x : rnd(560, 700), y = c ? c.y - 80 : rnd(1100, 1200);
  for (let i = 0; i < Math.min(adet, 4); i++) parcacik('kalp', x + rnd(-15, 15), y);
  if (c && Math.random() < 0.5) zipla(c);
}

function takip(kisi) {
  const c = tavukGetir(kisi);
  c.takipci = true;
  puanEkle(kisi, 20);
  zipla(c);
  balon(c, 'Takip ettim! ❤️');
  akisEkle(`❤️ ${kisalt(kisi.ad, 16)} takip etti!`, '#ff8fab');
  for (let i = 0; i < 10; i++) parcacik('kalp', c.x + rnd(-20, 20), c.y - 60);
  ses.pat();
}

function paylasim(kisi) {
  const c = tavukGetir(kisi);
  puanEkle(kisi, 15);
  akisEkle(`📣 ${kisalt(kisi.ad, 16)} yayını paylaştı! Yumurta yağmuru!`, '#74c0fc');
  for (let i = 0; i < 14; i++) {
    S.yumurtalar.push({ x: rnd(80, 640), y: rnd(-300, -20), hedefY: rnd(700, 1050), vy: 0, sure: 7, kirik: false, sallanma: 0 });
  }
  zipla(c);
}

function zipla(c, gecikme = 0) {
  if (c.durum === 'ko' || c.durum === 'kavga') return;
  if (c.ziplama <= 0) {
    c.ziplama = 0.45 + gecikme;
    c.ziplamaGecikme = gecikme;
    if (gecikme === 0) ses.ziplama();
  }
}

function cildir(c, sure) {
  if (c.durum === 'kavga' || c.durum === 'ko') { c.bekleyenCilgin = Math.max(c.bekleyenCilgin || 0, sure); return; }
  c.durum = 'cilgin';
  c.cilgin = Math.max(c.cilgin, sure);
  c.vx = rnd(-250, 250); c.vy = rnd(-150, 150);
}

function yumurtla(c) {
  if (c.yumurtaBekleme > 0 || c.durum === 'kavga' || c.durum === 'ko') return;
  c.yumurtaBekleme = 6;
  c.yumurtliyor = 0.8;
  balon(c, 'Gıt gıt gıdaaak!');
  ses.gidak(3);
  setTimeout(() => {
    S.yumurtalar.push({ x: c.x + rnd(-6, 6), y: c.y - 6, hedefY: c.y + 4, vy: -120, sure: 9, kirik: false, sallanma: 1, altin: c.altinTac || Math.random() < 0.08 });
    ses.pat();
    puanEkle(c, 3);
    parcacik('yazi', c.x, c.y - 90, { metin: '🥚 +3', renk: '#fff', boyut: 24 });
  }, 650);
}

// ------------------------------------------------------------------ kavga
function kavgaIstegi(c, hedef) {
  if (c.kavgaBekleme > 0) { balon(c, 'Biraz soluklanayım...'); return; }
  if (c.durum === 'kavga' || c.durum === 'ko') return;
  if (S.kavgalar.length >= 5) { balon(c, 'Sıradayım! 🥊'); return; }
  let rakip = hedef;
  if (!rakip || rakip.durum === 'kavga' || rakip.durum === 'ko') {
    const adaylar = S.tavuklar.filter((t) => t !== c && (t.durum === 'halka' || t.durum === 'cilgin'));
    rakip = sec(adaylar);
  }
  if (!rakip) { balon(c, 'Kimse yok mu?!'); return; }
  c.kavgaBekleme = 10;
  balon(c, sec([`Gel buraya ${kisalt(rakip.ad, 10)}!`, 'Tut beni tut!', 'Kafana gagalarım!', 'Hadi bakalım!']), 2.5);
  kavgaBaslat(c, rakip);
}

function kavgaYeri() {
  for (let deneme = 0; deneme < 12; deneme++) {
    const yan = Math.random() < 0.5 ? -1 : 1;
    const x = MERKEZ.x + yan * rnd(90, 230);
    const y = MERKEZ.y + rnd(-70, 110);
    if (!S.kavgalar.some((k) => Math.hypot(k.x - x, (k.y - y) * 1.6) < 130)) return { x, y };
  }
  return { x: MERKEZ.x + rnd(-200, 200), y: MERKEZ.y + rnd(-60, 120) };
}

function kavgaBaslat(a, b) {
  const yer = kavgaYeri();
  const k = { a, b, x: yer.x, y: yer.y, t: 0, faz: 'yaklas', kavgaSure: rnd(3, 4.2), uzuv: [], uzuvSayac: 0 };
  for (const c of [a, b]) {
    c.durum = 'kavga';
    c.cilgin = 0;
    c.kavga = k;
  }
  S.kavgalar.push(k);
  ses.gidak(2, 0.8);
}

function topluKavga(tetikleyen) {
  const musait = S.tavuklar.filter((t) => t.durum === 'halka' || t.durum === 'cilgin');
  const karisik = musait.sort(() => Math.random() - 0.5);
  if (tetikleyen && (tetikleyen.durum === 'halka' || tetikleyen.durum === 'cilgin')) {
    karisik.splice(karisik.indexOf(tetikleyen), 1);
    karisik.unshift(tetikleyen);
  }
  for (let i = 0; i + 1 < karisik.length && S.kavgalar.length < 6; i += 2) kavgaBaslat(karisik[i], karisik[i + 1]);
}

function kavgaGuncelle(k, dt) {
  k.t += dt;
  const { a, b } = k;
  if (k.faz === 'yaklas') {
    a.hx = k.x - 30; a.hy = k.y;
    b.hx = k.x + 30; b.hy = k.y;
    const yakin = Math.hypot(a.x - a.hx, a.y - a.hy) < 25 && Math.hypot(b.x - b.hx, b.y - b.hy) < 25;
    if (yakin || k.t > 2.2) {
      k.faz = 'kavga'; k.t = 0;
      S.sarsinti = Math.max(S.sarsinti, 0.25);
    }
  } else if (k.faz === 'kavga') {
    k.uzuvSayac -= dt;
    if (k.uzuvSayac <= 0) {
      k.uzuvSayac = 0.09;
      k.uzuv = [];
      const n = rint(3, 6);
      for (let i = 0; i < n; i++) k.uzuv.push({ tur: sec(['bacak', 'kanat', 'kafa', 'bacak']), a: rnd(0, Math.PI * 2), sahip: Math.random() < 0.5 ? a : b });
    }
    if (Math.random() < dt * 9) ses.yumruk();
    const yazilar = S.parcaciklar.filter((p) => p.tur === 'yazi').length;
    if (Math.random() < dt * 3.5 && yazilar < 8) {
      parcacik('yazi', k.x + rnd(-70, 70), k.y - rnd(50, 130), { metin: sec(['POW!', 'GÜM!', 'ŞAK!', 'PAT!', 'ÇAT!', 'BAM!', 'GAK!']), renk: sec(['#ffd43b', '#ff922b', '#ff6b6b', '#fff']), boyut: rnd(28, 40), cizgi: true });
    }
    if (Math.random() < dt * 25) parcacik('tuy', k.x + rnd(-30, 30), k.y - 40, { renk: (Math.random() < 0.5 ? a : b).renk[0] });
    if (Math.random() < dt * 6) parcacik('yildiz', k.x + rnd(-50, 50), k.y - rnd(30, 90));
    if (Math.random() < dt * 0.6) ses.gidak(2, 1.3);
    if (k.t >= k.kavgaSure) kavgaBitir(k);
  }
}

function kavgaBitir(k) {
  const { a, b } = k;
  const guc = (c) => 1 + (c.hediyeci ? 1.2 : 0) + (c.altinTac ? 2 : 0) + (c.takipci ? 0.3 : 0) + (c.bekleyenCilgin ? 0.8 : 0);
  const kazanan = Math.random() * (guc(a) + guc(b)) < guc(a) ? a : b;
  const kaybeden = kazanan === a ? b : a;
  kazanan.durum = 'zafer'; kazanan.zafer = 2.4; kazanan.kavga = null;
  kaybeden.durum = 'ko'; kaybeden.ko = 5; kaybeden.kavga = null;
  kazanan.x = k.x - 35; kaybeden.x = k.x + 35;
  kazanan.y = kaybeden.y = k.y;
  kaybeden.hx = kaybeden.x; kaybeden.hy = kaybeden.y;
  kazanan.hx = kazanan.x; kazanan.hy = kazanan.y;
  balon(kazanan, sec(['KAZANDIM!', 'Kümesin reisi benim!', 'Bir daha gel!', 'Hoppa!']), 2.4);
  puanEkle(kazanan, 25);
  parcacik('yazi', kazanan.x, kazanan.y - 110, { metin: '+25 🏆', renk: '#ffd43b', boyut: 28 });
  parcacik('duman', k.x, k.y - 30);
  for (let i = 0; i < 20; i++) parcacik('tuy', k.x + rnd(-40, 40), k.y - 40, { renk: kaybeden.renk[0] });
  akisEkle(`🥊 ${kisalt(kazanan.ad, 12)} kavgayı kazandı, ${kisalt(kaybeden.ad, 12)} bayıldı!`, '#ffa94d');
  ses.dusus();
  S.kavgalar.splice(S.kavgalar.indexOf(k), 1);
}

// ------------------------------------------------------------------ güncelleme
function guncelle(dt) {
  S.zaman += dt;
  S.tempo = Math.max(0, S.tempo - dt * 2.2);
  const hiz = 1 + (S.tempo / 100) * 0.65;
  ses.hiz = hiz;
  S.dansZamani += dt * hiz;
  S.halkaAci += dt * (S.mod === 'horon' ? 0.13 : 0.06) * hiz;
  S.sarsinti = Math.max(0, S.sarsinti - dt);
  S.flas = Math.max(0, S.flas - dt * 1.5);

  yerleriHesapla();
  for (const k of [...S.kavgalar]) kavgaGuncelle(k, dt);

  for (const c of S.tavuklar) {
    c.kavgaBekleme -= dt; c.yumurtaBekleme -= dt; c.cildirBekleme -= dt;
    if (c.yumurtliyor > 0) c.yumurtliyor -= dt;
    if (c.ziplama > 0) c.ziplama -= dt;
    if (c.balon) { c.balon.sure -= dt; if (c.balon.sure <= 0) c.balon = null; }

    let tx = c.hx, ty = c.hy;
    if (c.durum === 'cilgin') {
      c.cilgin -= dt;
      c.yonDegis -= dt;
      if (c.yonDegis <= 0) {
        c.yonDegis = rnd(0.15, 0.5);
        const hizC = rnd(180, 380);
        const a = rnd(0, Math.PI * 2);
        c.vx = Math.cos(a) * hizC; c.vy = Math.sin(a) * hizC * 0.6;
        if (Math.random() < 0.25) c.donus = 0.5;
        if (Math.random() < 0.3) zipla(c);
        if (Math.random() < 0.15) balon(c, sec(['GIDAAAK!', 'AAAAA!', 'Bok bok!', 'Wiiiii!', '🤪']), 1.2);
      }
      c.x += c.vx * dt; c.y += c.vy * dt;
      // alanın içinde tut
      const dx = (c.x - MERKEZ.x) / 330, dy = (c.y - (MERKEZ.y + 20)) / 215;
      if (dx * dx + dy * dy > 1) {
        c.vx = -c.vx + (MERKEZ.x - c.x) * 0.8; c.vy = -c.vy + (MERKEZ.y - c.y) * 0.8;
        c.x += c.vx * dt * 2; c.y += c.vy * dt * 2;
      }
      if (c.donus > 0) c.donus -= dt;
      if (Math.random() < dt * 4) parcacik('tuy', c.x, c.y - 35, { renk: c.renk[0] });
      if (Math.random() < dt * 0.8) ses.gidak(rint(1, 3), rnd(0.9, 1.4));
      c.yuruyor = true;
      if (c.cilgin <= 0) { c.durum = 'halka'; c.cilgin = 0; }
      continue;
    }
    if (c.durum === 'ko') {
      c.ko -= dt;
      if (c.ko <= 0) {
        c.durum = 'halka';
        balon(c, sec(['Neredeyim ben?', 'Başım dönüyor...', 'Rövanş istiyorum!']), 2);
        if (c.bekleyenCilgin) { cildir(c, c.bekleyenCilgin); c.bekleyenCilgin = 0; }
      }
      continue;
    }
    if (c.durum === 'zafer') {
      c.zafer -= dt;
      if (c.ziplama <= 0) c.ziplama = 0.4;
      if (c.zafer <= 0) {
        c.durum = 'halka';
        if (c.bekleyenCilgin) { cildir(c, c.bekleyenCilgin); c.bekleyenCilgin = 0; }
      }
      continue;
    }
    // halka veya kavgaya yürüyüş
    const dx = tx - c.x, dy = ty - c.y;
    const d = Math.hypot(dx, dy);
    if (d > 0.5) {
      const adim = Math.min(d, (c.durum === 'kavga' ? 420 : 320) * dt + d * dt * 2.5);
      c.x += (dx / d) * adim; c.y += (dy / d) * adim;
    }
    c.yuruyor = d > 18;
  }

  // otomatik rastgele kavga
  S.sonrakiOtoKavga -= dt;
  if (S.sonrakiOtoKavga <= 0) {
    S.sonrakiOtoKavga = rnd(18, 32);
    const adaylar = S.tavuklar.filter((t) => t.durum === 'halka');
    if (adaylar.length >= 4 && S.kavgalar.length < 2) {
      const a = sec(adaylar);
      const b = sec(adaylar.filter((t) => t !== a));
      balon(a, sec(['Sen bana mı baktın?!', 'Ayağıma bastın!', 'Yemimi yedin!', 'Bu halay benim!']), 2.5);
      kavgaBaslat(a, b);
      akisEkle(`⚡ ${kisalt(a.ad, 12)} ile ${kisalt(b.ad, 12)} birbirine girdi!`, '#ff8787');
    }
  }

  // yumurtalar
  for (const e of S.yumurtalar) {
    if (e.y < e.hedefY || e.vy < 0) {
      e.vy += 900 * dt; e.y += e.vy * dt;
      if (e.y >= e.hedefY && e.vy > 0) {
        e.y = e.hedefY;
        if (e.vy > 500) { e.kirik = true; ses.pat(); } else e.vy = 0;
        e.vy = 0;
      }
    }
    e.sure -= dt;
    if (e.sallanma > 0) e.sallanma -= dt * 0.5;
  }
  S.yumurtalar = S.yumurtalar.filter((e) => e.sure > 0);

  // parçacıklar
  for (const p of S.parcaciklar) parcacikGuncelle(p, dt);
  S.parcaciklar = S.parcaciklar.filter((p) => p.omur > 0);
  if (S.parcaciklar.length > 900) S.parcaciklar.splice(0, S.parcaciklar.length - 900);

  // hamamda buhar
  if (S.mod === 'hamam' && Math.random() < dt * 6) parcacik('buhar', rnd(0, W), rnd(900, 1250));
  // havai fişek
  if (S.fisekSure > 0) {
    S.fisekSure -= dt;
    if (Math.random() < dt * 3) fisekPatlat(rnd(120, 600), rnd(180, 520));
  }

  // akış ve manşet
  for (const a of S.akis) a.sure -= dt;
  S.akis = S.akis.filter((a) => a.sure > 0);
  if (S.manset) { S.manset.t += dt; if (S.manset.t > S.manset.sure) S.manset = null; }

  // demo
  if (S.demo) demoGuncelle(dt);
  if (S.otoMod) {
    S.otoModSayac += dt;
    if (S.otoModSayac > 300) { S.otoModSayac = 0; modDegistir(S.mod === 'horon' ? 'hamam' : 'horon'); }
  }
}

// ------------------------------------------------------------------ parçacıklar
function parcacik(tur, x, y, ek = {}) {
  const p = { tur, x, y, vx: 0, vy: 0, omur: 1, maks: 1, a: rnd(0, Math.PI * 2), va: 0, ...ek };
  switch (tur) {
    case 'tuy': p.vx = rnd(-160, 160); p.vy = rnd(-260, -60); p.omur = p.maks = rnd(1.5, 2.6); p.va = rnd(-6, 6); break;
    case 'konfeti': p.vx = rnd(-80, 80); p.vy = rnd(-50, 150); p.omur = p.maks = rnd(3, 5); p.va = rnd(-10, 10); p.renk = sec(['#ff6b6b', '#ffd43b', '#69db7c', '#4dabf7', '#da77f2', '#ff922b']); break;
    case 'kalp': p.vx = rnd(-30, 30); p.vy = rnd(-140, -90); p.omur = p.maks = rnd(1.2, 1.8); break;
    case 'yazi': p.vy = -60; p.omur = p.maks = 1.1; p.a = rnd(-0.3, 0.3); break;
    case 'yildiz': p.vx = rnd(-90, 90); p.vy = rnd(-160, -40); p.omur = p.maks = 0.7; break;
    case 'duman': p.omur = p.maks = 0.6; break;
    case 'buhar': p.vx = rnd(-10, 10); p.vy = rnd(-50, -25); p.omur = p.maks = rnd(4, 7); p.r = rnd(30, 70); break;
    case 'kivilcim': p.omur = p.maks = rnd(0.9, 1.6); break;
  }
  S.parcaciklar.push(p);
  return p;
}

function parcacikGuncelle(p, dt) {
  p.omur -= dt;
  p.a += p.va * dt;
  switch (p.tur) {
    case 'tuy':
      p.vy += 160 * dt; p.vy = Math.min(p.vy, 60);
      p.vx *= 1 - dt * 2.5;
      p.x += (p.vx + Math.sin(S.zaman * 5 + p.a) * 30) * dt; p.y += p.vy * dt; break;
    case 'konfeti':
      p.vy = Math.min(p.vy + 200 * dt, 140);
      p.x += (p.vx + Math.sin(S.zaman * 4 + p.a) * 40) * dt; p.y += p.vy * dt; break;
    case 'kivilcim':
      p.vy += 120 * dt; p.vx *= 1 - dt; p.vy *= 1 - dt * 0.5;
      p.x += p.vx * dt; p.y += p.vy * dt; break;
    default:
      p.x += p.vx * dt; p.y += p.vy * dt;
  }
}

function konfeti(n) {
  for (let i = 0; i < n; i++) parcacik('konfeti', rnd(0, W), rnd(-200, 0));
}

function fisekPatlat(x, y) {
  const renk = sec(['#ff6b6b', '#ffd43b', '#69db7c', '#4dabf7', '#da77f2', '#ffffff']);
  for (let i = 0; i < 60; i++) {
    const a = (i / 60) * Math.PI * 2, v = rnd(140, 260);
    parcacik('kivilcim', x, y, { vx: Math.cos(a) * v, vy: Math.sin(a) * v, renk });
  }
  ses.havaiFisek();
}

function akisEkle(metin, renk = '#fff') {
  S.akis.push({ metin, renk, sure: 6 });
  if (S.akis.length > 5) S.akis.shift();
}

function mansetGoster(metin, alt, renk) {
  S.manset = { metin, alt, renk, t: 0, sure: 3.2 };
}

function modDegistir(m) {
  if (m !== 'horon' && m !== 'hamam') return;
  if (S.mod === m) return;
  S.mod = m;
  ses.modAyarla(m);
  S.flas = 1;
  mansetGoster(m === 'horon' ? 'TAVUK HORONU' : 'HAMAM DİSKO', m === 'horon' ? 'Yaylada horon başlıyor!' : 'Kurnalar titresin! 🪩', m === 'horon' ? '#9be15d' : '#f783ac');
  S.parcaciklar = S.parcaciklar.filter((p) => p.tur !== 'buhar');
}

// ------------------------------------------------------------------ çizim: arka plan
const sahneOnbellek = {};
function sahneHazirla(mod) {
  if (sahneOnbellek[mod]) return sahneOnbellek[mod];
  const c = document.createElement('canvas');
  c.width = W; c.height = H;
  const g = c.getContext('2d');
  if (mod === 'horon') yaylaCiz(g); else hamamCiz(g);
  sahneOnbellek[mod] = c;
  return c;
}

function yaylaCiz(g) {
  // gökyüzü
  let gr = g.createLinearGradient(0, 0, 0, 600);
  gr.addColorStop(0, '#8fd3ff'); gr.addColorStop(1, '#e3f6ff');
  g.fillStyle = gr; g.fillRect(0, 0, W, 620);
  // uzak dağlar
  const dag = (renk, taban, tepe, adim, tohum) => {
    g.fillStyle = renk; g.beginPath(); g.moveTo(0, taban);
    for (let x = 0; x <= W + adim; x += adim) {
      const y = taban - tepe * (0.5 + 0.5 * Math.sin(x * 0.011 + tohum) * Math.cos(x * 0.004 + tohum * 2));
      g.lineTo(x, y);
    }
    g.lineTo(W, 640); g.lineTo(0, 640); g.fill();
  };
  dag('#a7c4d6', 470, 230, 40, 1);
  dag('#86b39a', 520, 170, 30, 4);
  dag('#5f9c6d', 570, 110, 24, 7);
  // sis
  gr = g.createLinearGradient(0, 430, 0, 560);
  gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(1, 'rgba(255,255,255,0.55)');
  g.fillStyle = gr; g.fillRect(0, 430, W, 140);
  // çimen
  gr = g.createLinearGradient(0, 560, 0, H);
  gr.addColorStop(0, '#7cc95a'); gr.addColorStop(1, '#4e9a35');
  g.fillStyle = gr; g.fillRect(0, 560, W, H - 560);
  // yayla evleri
  const ev = (x, y, s) => {
    g.save(); g.translate(x, y); g.scale(s, s);
    g.fillStyle = '#8a5a35'; g.fillRect(-40, -45, 80, 45);
    g.fillStyle = '#6b4226';
    for (let i = 0; i < 4; i++) g.fillRect(-40, -45 + i * 11, 80, 2);
    g.fillStyle = '#c0392b'; g.beginPath(); g.moveTo(-50, -43); g.lineTo(0, -80); g.lineTo(50, -43); g.fill();
    g.fillStyle = '#fbe7a1'; g.fillRect(-25, -32, 14, 14); g.fillRect(10, -32, 14, 14);
    g.fillStyle = '#4a2c17'; g.fillRect(-6, -24, 12, 24);
    g.restore();
  };
  ev(90, 600, 1); ev(640, 590, 0.85); ev(520, 560, 0.6);
  // çam ağaçları
  const cam = (x, y, s) => {
    g.save(); g.translate(x, y); g.scale(s, s);
    g.fillStyle = '#5b3a1e'; g.fillRect(-4, -14, 8, 14);
    g.fillStyle = '#2f6b3a';
    for (let i = 0; i < 3; i++) { g.beginPath(); g.moveTo(-26 + i * 5, -12 - i * 22); g.lineTo(0, -52 - i * 24); g.lineTo(26 - i * 5, -12 - i * 22); g.fill(); }
    g.restore();
  };
  [[30, 610, 1.1], [190, 585, 0.9], [250, 570, 0.7], [400, 575, 0.75], [470, 590, 0.95], [700, 615, 1.2], [580, 600, 0.8], [330, 560, 0.6]].forEach(([x, y, s]) => cam(x, y, s));
  // çay bahçesi sıraları
  g.fillStyle = 'rgba(40,110,45,0.35)';
  for (let i = 0; i < 4; i++) { g.beginPath(); g.ellipse(120 + i * 160, 1210 + (i % 2) * 20, 110, 18, 0, 0, Math.PI * 2); g.fill(); }
  // dans alanı (çiğnenmiş toprak)
  gr = g.createRadialGradient(MERKEZ.x, MERKEZ.y, 50, MERKEZ.x, MERKEZ.y, 360);
  gr.addColorStop(0, '#b08a5a'); gr.addColorStop(0.75, '#9c7a4c'); gr.addColorStop(1, 'rgba(156,122,76,0)');
  g.fillStyle = gr;
  g.beginPath(); g.ellipse(MERKEZ.x, MERKEZ.y + 10, 360, 220, 0, 0, Math.PI * 2); g.fill();
  // çiçekler
  for (let i = 0; i < 70; i++) {
    const x = Math.random() * W, y = 620 + Math.random() * 640;
    const dx = (x - MERKEZ.x) / 360, dy = (y - MERKEZ.y) / 220;
    if (dx * dx + dy * dy < 1.05) continue;
    g.fillStyle = sec(['#fff', '#ffe066', '#f783ac', '#b197fc']);
    g.beginPath(); g.arc(x, y, 3, 0, Math.PI * 2); g.fill();
  }
}

function hamamCiz(g) {
  // kubbe ve duvar
  let gr = g.createLinearGradient(0, 0, 0, 640);
  gr.addColorStop(0, '#2a1d3d'); gr.addColorStop(0.45, '#4b3a5c'); gr.addColorStop(1, '#8c7a6b');
  g.fillStyle = gr; g.fillRect(0, 0, W, 660);
  // kubbe kemerleri
  g.strokeStyle = 'rgba(255,230,200,0.18)'; g.lineWidth = 6;
  for (let i = 0; i < 5; i++) { g.beginPath(); g.ellipse(360, 420, 420 - i * 70, 380 - i * 60, 0, Math.PI, Math.PI * 2); g.stroke(); }
  // fil gözleri (kubbedeki ışık delikleri)
  for (let i = 0; i < 26; i++) {
    const a = Math.PI + (i % 13) / 12 * Math.PI;
    const r = i < 13 ? 300 : 190;
    const x = 360 + Math.cos(a) * r * 1.1, y = 420 + Math.sin(a) * r * 0.95;
    yildizSekli(g, x, y, 9, 4, 6, 'rgba(255,248,210,0.85)');
  }
  // mermer duvar ve kemerli nişler (kurnalar)
  gr = g.createLinearGradient(0, 400, 0, 660);
  gr.addColorStop(0, '#e9dfd0'); gr.addColorStop(1, '#cfc2ad');
  g.fillStyle = gr; g.fillRect(0, 430, W, 230);
  for (let i = 0; i < 4; i++) {
    const x = 90 + i * 180;
    g.fillStyle = '#b9a98f';
    g.beginPath(); g.moveTo(x - 60, 650); g.lineTo(x - 60, 520); g.arc(x, 520, 60, Math.PI, 0); g.lineTo(x + 60, 650); g.fill();
    g.fillStyle = '#8e7d66';
    g.beginPath(); g.moveTo(x - 48, 650); g.lineTo(x - 48, 525); g.arc(x, 525, 48, Math.PI, 0); g.lineTo(x + 48, 650); g.fill();
    // kurna
    g.fillStyle = '#f4efe6'; g.beginPath(); g.ellipse(x, 615, 34, 12, 0, 0, Math.PI * 2); g.fill();
    g.fillStyle = '#e1d7c6'; g.fillRect(x - 30, 615, 60, 30);
    g.fillStyle = '#c9a227'; g.fillRect(x - 3, 575, 6, 22); g.fillRect(x - 10, 575, 20, 5);
  }
  // zemin: perspektif mermer karolar
  gr = g.createLinearGradient(0, 655, 0, H);
  gr.addColorStop(0, '#d8cfc2'); gr.addColorStop(1, '#f2ece2');
  g.fillStyle = gr; g.fillRect(0, 655, W, H - 655);
  g.strokeStyle = 'rgba(120,100,80,0.25)'; g.lineWidth = 2;
  for (let i = 0; i < 14; i++) { const y = 655 + Math.pow(i / 13, 1.6) * 640; g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke(); }
  for (let i = -10; i <= 10; i++) { g.beginPath(); g.moveTo(360 + i * 40, 655); g.lineTo(360 + i * 150, H); g.stroke(); }
  // göbek taşı (sekizgen)
  const gt = (rx, ry, dy, renk) => {
    g.fillStyle = renk; g.beginPath();
    for (let i = 0; i < 8; i++) { const a = (i / 8) * Math.PI * 2 + Math.PI / 8; g.lineTo(MERKEZ.x + Math.cos(a) * rx, MERKEZ.y + dy + Math.sin(a) * ry); }
    g.closePath(); g.fill();
  };
  gt(135, 68, 22, '#b3a690');
  g.fillStyle = '#c7bba5'; g.fillRect(MERKEZ.x - 125, MERKEZ.y, 250, 22);
  gt(135, 68, 0, '#efe8dc');
  gt(110, 52, 0, '#e4dccd');
}

function yildizSekli(g, x, y, r1, r2, n, renk) {
  g.fillStyle = renk; g.beginPath();
  for (let i = 0; i < n * 2; i++) {
    const r = i % 2 ? r2 : r1, a = (i / (n * 2)) * Math.PI * 2 - Math.PI / 2;
    g.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r);
  }
  g.closePath(); g.fill();
}

function hamamIsiklari(g) {
  // disko topu ve dönen ışık hüzmeleri
  const bx = 360, by = 190;
  const parlak = 0.5 + S.tempo / 200;
  g.save();
  g.globalCompositeOperation = 'lighter';
  const renkler = ['255,80,160', '80,200,255', '255,220,60', '140,255,120', '190,110,255'];
  for (let i = 0; i < 10; i++) {
    const a = S.zaman * (0.6 + S.tempo / 120) + i * 0.63;
    const hx = 360 + Math.sin(a) * 340, hy = 900 + Math.cos(a * 1.3) * 230;
    g.fillStyle = `rgba(${renkler[i % 5]},${0.07 * parlak})`;
    g.beginPath(); g.moveTo(bx, by); g.lineTo(hx - 50, hy); g.lineTo(hx + 50, hy); g.fill();
    g.fillStyle = `rgba(${renkler[i % 5]},${0.22 * parlak})`;
    g.beginPath(); g.ellipse(hx, hy, 55, 22, 0, 0, Math.PI * 2); g.fill();
  }
  if (S.tempo > 85 && Math.floor(S.zaman * 10) % 2 === 0) { g.fillStyle = 'rgba(255,255,255,0.06)'; g.fillRect(0, 0, W, H); }
  g.restore();
  // ip ve top
  g.strokeStyle = '#555'; g.lineWidth = 2; g.beginPath(); g.moveTo(bx, 0); g.lineTo(bx, by - 40); g.stroke();
  g.save(); g.translate(bx, by);
  g.beginPath(); g.arc(0, 0, 40, 0, Math.PI * 2); g.clip();
  g.fillStyle = '#9aa0a6'; g.fillRect(-40, -40, 80, 80);
  const kay = (S.zaman * 30) % 10;
  for (let yy = -40; yy < 40; yy += 10) for (let xx = -50; xx < 50; xx += 10) {
    const p = Math.sin((xx + kay) * 0.3 + yy * 0.7 + S.zaman * 3);
    g.fillStyle = p > 0.6 ? '#ffffff' : p > 0 ? '#d0d4d8' : '#7d838a';
    g.fillRect(xx + kay, yy, 9, 9);
  }
  g.restore();
}

// ------------------------------------------------------------------ çizim: tavuk
function tavukCiz(g, c, x, y, s, p) {
  // p: {bob, titreme, egim, kanatSol, kanatSag, bacak, goz, yatik, gozluk, donus}
  g.save();
  g.translate(x, y);
  g.scale(s, s);
  // gölge
  g.fillStyle = 'rgba(0,0,0,0.22)';
  g.beginPath(); g.ellipse(0, 0, p.yatik ? 38 : 22, 7, 0, 0, Math.PI * 2); g.fill();

  if (p.yatik) { g.translate(-4, -12); g.rotate(-Math.PI / 2 * 0.95); g.translate(0, 12); }
  g.translate(0, -p.bob);
  if (p.donus) g.scale(Math.cos(p.donus * Math.PI * 4), 1);

  // bacaklar
  g.strokeStyle = '#f59f00'; g.lineWidth = 3.5; g.lineCap = 'round';
  const bacak = (bx, kalk) => {
    g.beginPath(); g.moveTo(bx, -16); g.lineTo(bx + kalk * 0.3, -2 - kalk); g.stroke();
    g.beginPath(); g.moveTo(bx + kalk * 0.3 - 5, -1 - kalk); g.lineTo(bx + kalk * 0.3 + 5, -1 - kalk); g.stroke();
  };
  bacak(-8, p.bacak > 0 ? p.bacak : 0);
  bacak(8, p.bacak < 0 ? -p.bacak : 0);

  g.save();
  g.translate(p.titreme, 0);
  g.rotate(p.egim);

  // kuyruk tüyleri (arkada)
  g.fillStyle = c.renk[1];
  for (let i = -1; i <= 1; i++) { g.beginPath(); g.ellipse(i * 12, -54, 6, 14, i * 0.5, 0, Math.PI * 2); g.fill(); }

  // kanatlar
  const kanat = (yan, aci) => {
    g.save(); g.translate(yan * 19, -38); g.rotate(yan * aci);
    g.fillStyle = c.renk[1];
    g.beginPath(); g.ellipse(yan * 10, 0, 13, 7.5, 0, 0, Math.PI * 2); g.fill();
    g.restore();
  };
  kanat(-1, p.kanatSol); kanat(1, p.kanatSag);

  // gövde
  g.fillStyle = c.renk[0];
  g.beginPath(); g.ellipse(0, -34, 22, 21, 0, 0, Math.PI * 2); g.fill();
  g.strokeStyle = 'rgba(0,0,0,0.15)'; g.lineWidth = 1.5; g.stroke();

  // kıyafet (gövde)
  if (S.mod === 'horon' && c.kiyafet === 1) {
    g.fillStyle = '#212121';
    g.beginPath(); g.moveTo(-20, -44); g.quadraticCurveTo(-6, -30, -10, -15); g.lineTo(-18, -22); g.closePath(); g.fill();
    g.beginPath(); g.moveTo(20, -44); g.quadraticCurveTo(6, -30, 10, -15); g.lineTo(18, -22); g.closePath(); g.fill();
    g.strokeStyle = '#d4af37'; g.lineWidth = 1.5; g.beginPath(); g.moveTo(-8, -30); g.quadraticCurveTo(0, -24, 8, -30); g.stroke();
  } else if (S.mod === 'horon') {
    g.fillStyle = c.yazma;
    g.beginPath(); g.ellipse(0, -22, 19, 8, 0, 0, Math.PI); g.fill();
  } else {
    // peştemal: kırmızı-beyaz çizgili
    g.save(); g.beginPath(); g.ellipse(0, -34, 22, 21, 0, 0, Math.PI * 2); g.clip();
    const ana = c.kiyafet ? '#c92a2a' : '#1971c2';
    for (let i = 0; i < 6; i++) { g.fillStyle = i % 2 ? '#fff' : ana; g.fillRect(-24, -30 + i * 3.2, 48, 3.2); }
    g.restore();
  }

  // kafa
  g.fillStyle = c.renk[0];
  g.beginPath(); g.arc(0, -62, 15, 0, Math.PI * 2); g.fill();
  g.strokeStyle = 'rgba(0,0,0,0.15)'; g.lineWidth = 1.5; g.stroke();
  // ibik
  g.fillStyle = '#e03131';
  [[-6, -76, 5], [0, -79, 6], [6, -76, 5]].forEach(([a, b, r]) => { g.beginPath(); g.arc(a, b, r, 0, Math.PI * 2); g.fill(); });
  // kafa kıyafeti
  if (S.mod === 'horon' && c.kiyafet === 0) {
    g.fillStyle = c.yazma;
    g.beginPath(); g.moveTo(-17, -60); g.quadraticCurveTo(-18, -80, 0, -78); g.quadraticCurveTo(18, -80, 17, -60); g.lineTo(13, -66); g.quadraticCurveTo(0, -74, -13, -66); g.closePath(); g.fill();
    g.fillStyle = 'rgba(255,255,255,0.7)';
    for (let i = -2; i <= 2; i++) { g.beginPath(); g.arc(i * 5.5, -72 + Math.abs(i), 1.4, 0, Math.PI * 2); g.fill(); }
  } else if (S.mod === 'hamam' && c.kiyafet === 0) {
    // havlu türban
    g.fillStyle = '#f8f9fa';
    g.beginPath(); g.ellipse(0, -76, 16, 9, 0, 0, Math.PI * 2); g.fill();
    g.beginPath(); g.ellipse(4, -84, 10, 7, 0.3, 0, Math.PI * 2); g.fill();
    g.strokeStyle = '#dee2e6'; g.lineWidth = 1; g.beginPath(); g.moveTo(-12, -78); g.quadraticCurveTo(0, -72, 12, -79); g.stroke();
  }
  // altın taç
  if (c.altinTac) {
    g.fillStyle = '#ffd43b'; g.strokeStyle = '#e8590c'; g.lineWidth = 1.2;
    g.beginPath(); g.moveTo(-12, -84); g.lineTo(-12, -96); g.lineTo(-6, -90); g.lineTo(0, -100); g.lineTo(6, -90); g.lineTo(12, -96); g.lineTo(12, -84); g.closePath(); g.fill(); g.stroke();
  }

  // gözler
  gozCiz(g, -6, -64, p.goz);
  gozCiz(g, 6, -64, p.goz);
  if (p.gozluk) {
    g.fillStyle = '#111';
    g.beginPath(); g.roundRect(-14, -69, 12, 9, 3); g.fill();
    g.beginPath(); g.roundRect(2, -69, 12, 9, 3); g.fill();
    g.fillRect(-3, -67, 6, 2);
    g.fillStyle = 'rgba(255,255,255,0.5)'; g.fillRect(-12, -67, 4, 2); g.fillRect(4, -67, 4, 2);
  }
  // gaga
  g.fillStyle = '#f59f00';
  g.beginPath();
  if (p.agiz) { g.moveTo(-5, -58); g.lineTo(5, -58); g.lineTo(0, -53); g.closePath(); g.fill(); g.beginPath(); g.moveTo(-4, -52); g.lineTo(4, -52); g.lineTo(0, -47); }
  else { g.moveTo(-5, -58); g.lineTo(5, -58); g.lineTo(0, -50); }
  g.closePath(); g.fill();
  // gıdı
  g.fillStyle = '#e03131';
  g.beginPath(); g.ellipse(0, -47, 3, 4.5, 0, 0, Math.PI * 2); g.fill();

  g.restore();
  g.restore();
}

function gozCiz(g, x, y, tur) {
  if (tur === 'ko') {
    g.strokeStyle = '#222'; g.lineWidth = 2;
    g.beginPath(); g.moveTo(x - 3, y - 3); g.lineTo(x + 3, y + 3); g.moveTo(x + 3, y - 3); g.lineTo(x - 3, y + 3); g.stroke();
    return;
  }
  if (tur === 'mutlu') {
    g.strokeStyle = '#222'; g.lineWidth = 2;
    g.beginPath(); g.arc(x, y + 1, 3.5, Math.PI * 1.1, Math.PI * 1.9); g.stroke();
    return;
  }
  const r = tur === 'cilgin' ? 6 : 4.5;
  g.fillStyle = '#fff';
  g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2); g.fill();
  g.strokeStyle = 'rgba(0,0,0,0.3)'; g.lineWidth = 0.8; g.stroke();
  g.fillStyle = '#111';
  if (tur === 'cilgin') {
    const a = S.zaman * 20 + x;
    g.beginPath(); g.arc(x + Math.cos(a) * 2.5, y + Math.sin(a) * 2.5, 1.8, 0, Math.PI * 2); g.fill();
  } else if (tur === 'kizgin') {
    g.beginPath(); g.arc(x, y + 1, 2.2, 0, Math.PI * 2); g.fill();
    g.strokeStyle = '#111'; g.lineWidth = 2;
    g.beginPath(); g.moveTo(x - 5 * Math.sign(x || 1), y - 7); g.lineTo(x + 4 * Math.sign(x || 1), y - 4); g.stroke();
  } else {
    g.beginPath(); g.arc(x, y + 0.5, 2.2, 0, Math.PI * 2); g.fill();
  }
}

// dans pozunu hesapla
function poz(c) {
  const p = { bob: 0, titreme: 0, egim: 0, kanatSol: 0.2, kanatSag: 0.2, bacak: 0, goz: 'normal', yatik: false, gozluk: false, donus: 0, agiz: false };
  const t = S.dansZamani + c.faz * 0.08;
  const coskun = S.tempo / 100;

  if (c.durum === 'ko') {
    p.yatik = true; p.goz = 'ko';
    return p;
  }
  if (c.durum === 'cilgin') {
    const f = S.zaman * 40 + c.faz * 10;
    p.kanatSol = -0.9 + Math.sin(f) * 1.2;
    p.kanatSag = -0.9 + Math.sin(f + 1) * 1.2;
    p.bob = Math.abs(Math.sin(S.zaman * 18 + c.faz * 6)) * 12;
    p.bacak = Math.sin(S.zaman * 30) * 8;
    p.titreme = Math.sin(S.zaman * 70) * 3;
    p.egim = Math.sin(S.zaman * 9 + c.faz) * 0.35;
    p.goz = 'cilgin'; p.agiz = true;
    p.gozluk = S.mod === 'hamam' && Math.floor(S.zaman * 2 + c.faz * 4) % 3 === 0;
    p.donus = c.donus > 0 ? c.donus : 0;
  } else if (c.durum === 'zafer') {
    p.kanatSol = p.kanatSag = -1.4 + Math.sin(S.zaman * 20) * 0.3;
    p.goz = 'mutlu'; p.agiz = true;
  } else if (c.durum === 'kavga') {
    p.goz = 'kizgin';
    p.kanatSol = -0.5 + Math.sin(S.zaman * 25) * 0.5; p.kanatSag = -0.5 + Math.cos(S.zaman * 25) * 0.5;
    p.bacak = Math.sin(S.zaman * 22) * 6;
    p.egim = 0.15 * (c.x < (c.kavga?.x ?? c.x) ? 1 : -1);
  } else if (c.yuruyor) {
    p.bacak = Math.sin(S.zaman * 22 + c.faz * 6) * 6;
    p.bob = Math.abs(Math.sin(S.zaman * 11 + c.faz * 6)) * 4;
  } else if (S.mod === 'horon') {
    // 7/16 aksak: 2+2+3 vuruş
    const olcu = 0.595;
    const ic = ((t / olcu) % 1) * 7;
    const bas = ic < 2 ? 0 : ic < 4 ? 2 : 4;
    const bp = (ic - bas) / (bas === 4 ? 3 : 2);
    p.bob = Math.sin(bp * Math.PI) * (5 + coskun * 6);
    const olcuNo = Math.floor(t / olcu);
    p.bacak = (bas === 4 ? Math.sin(bp * Math.PI) * 7 : 0) * (olcuNo % 2 ? 1 : -1);
    // horonun meşhur titremesi (omuz)
    p.titreme = Math.sin(S.zaman * 48 + c.faz * 3) * (0.8 + coskun * coskun * 4.5);
    p.egim = Math.sin((t / olcu) * Math.PI) * 0.06;
    // kanatlar yanlardaki komşuya uzanır; coşkuda yukarı kalkar
    const kalk = coskun > 0.85 ? -0.9 : -0.1 - coskun * 0.4;
    p.kanatSol = p.kanatSag = kalk + Math.sin(bp * Math.PI) * 0.15;
    p.goz = coskun > 0.85 ? 'mutlu' : 'normal';
    p.agiz = coskun > 0.6 && bas === 4;
  } else {
    // disko: 4/4, kalça sallama ve parmak kaldırma pozu
    const vurus = 60 / 118;
    const v = (t / vurus) % 1;
    const vNo = Math.floor(t / vurus);
    p.bob = Math.abs(Math.sin(v * Math.PI)) * (5 + coskun * 7);
    p.egim = Math.sin((t / vurus) * Math.PI) * (0.12 + coskun * 0.12);
    const yukari = (vNo + Math.floor(c.faz * 4)) % 4 < 2;
    p.kanatSol = yukari ? -1.5 : 0.5;
    p.kanatSag = yukari ? 0.5 : -1.5;
    p.bacak = Math.sin((t / vurus) * Math.PI) * 4;
    p.gozluk = coskun > 0.55 || c.kiyafet === 1;
    p.titreme = coskun > 0.85 ? Math.sin(S.zaman * 50) * 2.5 : 0;
    p.agiz = v < 0.3;
  }
  if (c.ziplama > 0 && c.durum !== 'ko') {
    const gecikme = c.ziplamaGecikme || 0;
    const z = c.ziplama - gecikme;
    if (z > 0) {
      const k = 1 - z / 0.45;
      p.bob += Math.sin(Math.max(0, k) * Math.PI) * 32;
      p.kanatSol = p.kanatSag = -1.2;
    }
  }
  if (c.yumurtliyor > 0) { p.bob = -6; p.goz = 'cilgin'; p.agiz = true; p.titreme = Math.sin(S.zaman * 60) * 3; }
  return p;
}

// ------------------------------------------------------------------ çizim: sahne
function ciz() {
  g_reset();
  ctx.save();
  if (S.sarsinti > 0) ctx.translate(rnd(-1, 1) * S.sarsinti * 14, rnd(-1, 1) * S.sarsinti * 14);
  ctx.drawImage(sahneHazirla(S.mod), 0, 0);
  if (S.mod === 'hamam') hamamIsiklari(ctx);

  // derinlik sırasına göre: tavuklar, kavga bulutları, yumurtalar, merkez karakter
  const cizilecek = [];
  for (const c of S.tavuklar) if (!(c.durum === 'kavga' && c.kavga && c.kavga.faz === 'kavga')) cizilecek.push({ y: c.y, tur: 't', c });
  for (const k of S.kavgalar) if (k.faz === 'kavga') cizilecek.push({ y: k.y, tur: 'k', k });
  for (const e of S.yumurtalar) cizilecek.push({ y: e.y, tur: 'e', e });
  cizilecek.push({ y: MERKEZ.y + 5, tur: 'm' });
  cizilecek.sort((a, b) => a.y - b.y);

  // el ele tutuşma çizgileri (halkada yan yana olanlar)
  kolCizgileri();

  for (const o of cizilecek) {
    if (o.tur === 't') { const c = o.c; tavukCiz(ctx, c, c.x, c.y, derinlikOlcek(c.y) * c.olcek, poz(c)); }
    else if (o.tur === 'k') bulutCiz(o.k);
    else if (o.tur === 'e') yumurtaCiz(o.e);
    else merkezCiz();
  }
  // ko yıldızları
  for (const c of S.tavuklar) if (c.durum === 'ko') koYildiz(c);

  // isim etiketleri ve balonlar (en üstte)
  for (const c of S.tavuklar) etiketCiz(c);
  for (const k of S.kavgalar) if (k.faz === 'kavga') {
    etiket(ctx, `${kisalt(k.a.ad, 10)} ⚔️ ${kisalt(k.b.ad, 10)}`, k.x, k.y - 150, '#ff6b6b', 15);
  }

  for (const p of S.parcaciklar) parcacikCiz(p);
  ctx.restore();

  arayuzCiz();
  if (S.flas > 0) { ctx.fillStyle = `rgba(255,255,255,${S.flas})`; ctx.fillRect(0, 0, W, H); }
}
function g_reset() { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over'; }

function kolCizgileri() {
  const halkada = (c) => c.durum === 'halka' && !c.yuruyor && Math.hypot(c.x - c.hx, c.y - c.hy) < 12;
  const n = S.tavuklar.length;
  const dis = Math.min(n, DIS_KAPASITE);
  ctx.lineCap = 'round';
  const bagla = (a, b) => {
    if (!halkada(a) || !halkada(b)) return;
    const sa = derinlikOlcek(a.y), sb = derinlikOlcek(b.y);
    const pa = poz(a), pb = poz(b);
    const ya = a.y - (38 + pa.bob) * sa, yb = b.y - (38 + pb.bob) * sb;
    if (Math.hypot(a.x - b.x, ya - yb) > 130) return;
    ctx.strokeStyle = a.renk[1]; ctx.lineWidth = 6 * (sa + sb) / 2;
    const ortaY = (ya + yb) / 2 - (S.tempo > 85 && S.mod === 'horon' ? 18 : 0);
    ctx.beginPath(); ctx.moveTo(a.x, ya); ctx.quadraticCurveTo((a.x + b.x) / 2, ortaY, b.x, yb); ctx.stroke();
  };
  if (S.mod !== 'horon') return;
  for (let i = 0; i < dis; i++) bagla(S.tavuklar[i], S.tavuklar[(i + 1) % dis]);
  const ic = S.tavuklar.slice(dis);
  for (let i = 0; i < ic.length && ic.length > 1; i++) bagla(ic[i], ic[(i + 1) % ic.length]);
}

function merkezCiz() {
  const x = MERKEZ.x, y = MERKEZ.y + 5;
  const merkez = { renk: ['#ffffff', '#d9d2c5'], kiyafet: 1, yazma: '#000', altinTac: false };
  const t = S.dansZamani;
  if (S.mod === 'horon') {
    const p = { bob: Math.abs(Math.sin(t * 5.3)) * 3, titreme: 0, egim: Math.sin(t * 3) * 0.08, kanatSol: -0.3, kanatSag: 0.6, bacak: Math.sin(t * 10.6) > 0.7 ? 5 : 0, goz: 'mutlu', yatik: false, gozluk: false, donus: 0, agiz: false };
    tavukCiz(ctx, merkez, x, y, 1.25, p);
    // kemençe
    ctx.save(); ctx.translate(x - 4, y - 42 - p.bob * 1.25); ctx.rotate(-0.25);
    ctx.fillStyle = '#7a3e1d'; ctx.beginPath(); ctx.ellipse(0, 0, 9, 20, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#5a2c12'; ctx.fillRect(-3, -40, 6, 24);
    ctx.fillStyle = '#3b1d0c'; ctx.beginPath(); ctx.ellipse(0, -42, 6, 4, 0, 0, Math.PI * 2); ctx.fill();
    ctx.restore();
    // yay
    const yay = Math.sin(t * 10.6) * 16;
    ctx.strokeStyle = '#6b4226'; ctx.lineWidth = 2.5;
    ctx.beginPath(); ctx.moveTo(x - 30 + yay, y - 55); ctx.lineTo(x + 26 + yay, y - 40); ctx.stroke();
    etiket(ctx, '🎻 Kemençeci Horoz', x, y - 125, '#ffe066', 14);
    // notalar
    if (Math.random() < 0.05 * (1 + S.tempo / 50)) parcacik('yazi', x + rnd(-30, 30), y - 110, { metin: sec(['♪', '♫', '♬']), renk: '#fff', boyut: 26 });
  } else {
    const p = { bob: Math.abs(Math.sin(t * 6.2)) * 5, titreme: 0, egim: Math.sin(t * 3.1) * 0.15, kanatSol: -0.2 + Math.sin(t * 12) * 0.3, kanatSag: 0.4, bacak: 0, goz: 'normal', yatik: false, gozluk: true, donus: 0, agiz: true };
    // DJ masası
    tavukCiz(ctx, merkez, x, y - 10, 1.2, p);
    ctx.fillStyle = '#212529'; ctx.beginPath(); ctx.roundRect(x - 62, y - 30, 124, 34, 6); ctx.fill();
    ctx.fillStyle = '#495057';
    for (const dx of [-35, 35]) { ctx.beginPath(); ctx.ellipse(x + dx, y - 26, 20, 6, 0, 0, Math.PI * 2); ctx.fill(); }
    ctx.fillStyle = `hsl(${(S.zaman * 200) % 360},90%,60%)`;
    for (let i = 0; i < 6; i++) ctx.fillRect(x - 15 + i * 5, y - 10 - Math.abs(Math.sin(S.zaman * 8 + i)) * 12, 3, Math.abs(Math.sin(S.zaman * 8 + i)) * 12 + 2);
    // kulaklık
    ctx.strokeStyle = '#111'; ctx.lineWidth = 4;
    const hy = y - 10 - 62 * 1.2 - p.bob * 1.2;
    ctx.beginPath(); ctx.arc(x, hy, 19, Math.PI * 1.05, Math.PI * 1.95); ctx.stroke();
    ctx.fillStyle = '#e64980';
    ctx.beginPath(); ctx.ellipse(x - 19, hy + 3, 5, 8, 0, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.ellipse(x + 19, hy + 3, 5, 8, 0, 0, Math.PI * 2); ctx.fill();
    etiket(ctx, '🎧 DJ Tellak', x, y - 135, '#f783ac', 14);
  }
}

function bulutCiz(k) {
  const x = k.x, y = k.y - 40;
  ctx.save();
  // dışarı fırlayan uzuvlar
  for (const u of k.uzuv) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(u.a);
    if (u.tur === 'bacak') {
      ctx.strokeStyle = '#f59f00'; ctx.lineWidth = 4; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(40, 0); ctx.lineTo(70, 0); ctx.moveTo(70, -6); ctx.lineTo(70, 6); ctx.stroke();
    } else if (u.tur === 'kanat') {
      ctx.fillStyle = u.sahip.renk[1]; ctx.beginPath(); ctx.ellipse(62, 0, 18, 9, 0, 0, Math.PI * 2); ctx.fill();
    } else {
      ctx.fillStyle = u.sahip.renk[0]; ctx.beginPath(); ctx.arc(64, 0, 14, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#e03131'; ctx.beginPath(); ctx.arc(64, -14, 5, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#f59f00'; ctx.beginPath(); ctx.moveTo(74, -4); ctx.lineTo(84, 0); ctx.lineTo(74, 4); ctx.fill();
    }
    ctx.restore();
  }
  // toz bulutu
  for (let i = 0; i < 9; i++) {
    const a = i / 9 * Math.PI * 2 + S.zaman * 6;
    const r = 30 + Math.sin(S.zaman * 13 + i * 2) * 6;
    ctx.fillStyle = i % 2 ? '#e9ecef' : '#ced4da';
    ctx.beginPath(); ctx.arc(x + Math.cos(a) * r * 1.3, y + Math.sin(a) * r * 0.8, 30 + (i % 3) * 5, 0, Math.PI * 2); ctx.fill();
  }
  ctx.fillStyle = '#f1f3f5';
  ctx.beginPath(); ctx.arc(x, y, 38, 0, Math.PI * 2); ctx.fill();
  ctx.restore();
}

function koYildiz(c) {
  const s = derinlikOlcek(c.y);
  for (let i = 0; i < 3; i++) {
    const a = S.zaman * 4 + (i / 3) * Math.PI * 2;
    yildizSekli(ctx, c.x - 30 * s + Math.cos(a) * 18 * s, c.y - 28 * s + Math.sin(a) * 6 * s, 7 * s, 3 * s, 5, '#ffd43b');
  }
}

function yumurtaCiz(e) {
  ctx.save();
  ctx.translate(e.x, e.y);
  ctx.globalAlpha = Math.min(1, e.sure);
  if (e.kirik) {
    ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.ellipse(0, 0, 16, 6, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#ffc107'; ctx.beginPath(); ctx.arc(0, -1, 5, 0, Math.PI * 2); ctx.fill();
  } else {
    ctx.rotate(Math.sin(S.zaman * 14) * 0.25 * Math.max(0, e.sallanma));
    ctx.fillStyle = 'rgba(0,0,0,0.2)'; ctx.beginPath(); ctx.ellipse(0, 0, 9, 3, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = e.altin ? '#ffd43b' : '#fff8ee';
    ctx.strokeStyle = 'rgba(0,0,0,0.25)'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.ellipse(0, -11, 8, 11, 0, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
  }
  ctx.restore();
}

function etiketCiz(c) {
  const s = derinlikOlcek(c.y);
  const pz = c.durum === 'ko' ? 30 : 92;
  const y = c.y - pz * s;
  const renk = c.altinTac ? '#ffd43b' : c.hediyeci ? '#ffe8a3' : c.npc ? '#dee2e6' : '#ffffff';
  if (c.durum !== 'kavga' || !c.kavga || c.kavga.faz !== 'kavga') {
    etiket(ctx, (c.takipci ? '❤️' : '') + kisalt(c.ad, 12), c.x, y, renk, 12);
  }
  if (c.balon) {
    const a = Math.min(1, c.balon.sure * 3);
    ctx.globalAlpha = a;
    balonCiz(c.balon.metin, c.x, y - 18);
    ctx.globalAlpha = 1;
  }
}

function etiket(g, metin, x, y, renk = '#fff', boyut = 12) {
  g.font = `700 ${boyut}px "Segoe UI", "Noto Sans", Arial, sans-serif`;
  const w = g.measureText(metin).width + 10;
  g.fillStyle = 'rgba(20,20,30,0.62)';
  g.beginPath(); g.roundRect(x - w / 2, y - boyut, w, boyut + 6, 5); g.fill();
  g.fillStyle = renk; g.textAlign = 'center'; g.textBaseline = 'alphabetic';
  g.fillText(metin, x, y + 1);
}

function balonCiz(metin, x, y) {
  ctx.font = '700 15px "Segoe UI", "Noto Sans", Arial, sans-serif';
  const w = Math.max(40, ctx.measureText(metin).width + 18);
  const h = 26;
  const bx = Math.max(6, Math.min(W - w - 6, x - w / 2));
  ctx.fillStyle = '#fff';
  ctx.strokeStyle = '#222'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.roundRect(bx, y - h, w, h, 10); ctx.fill(); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(x - 6, y - 1); ctx.lineTo(x, y + 8); ctx.lineTo(x + 6, y - 1); ctx.fillStyle = '#fff'; ctx.fill();
  ctx.fillStyle = '#222'; ctx.textAlign = 'center';
  ctx.fillText(metin, bx + w / 2, y - 8);
}

function parcacikCiz(p) {
  const a = Math.max(0, Math.min(1, p.omur / p.maks * 1.5));
  ctx.globalAlpha = a;
  switch (p.tur) {
    case 'tuy':
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.a);
      ctx.fillStyle = p.renk || '#fff'; ctx.strokeStyle = 'rgba(0,0,0,0.2)'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.ellipse(0, 0, 3.5, 9, 0, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.restore(); break;
    case 'konfeti':
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.a);
      ctx.fillStyle = p.renk; ctx.fillRect(-5, -3, 10, 6 * Math.abs(Math.cos(p.a * 2)) + 1);
      ctx.restore(); break;
    case 'kalp':
      ctx.font = '22px sans-serif'; ctx.textAlign = 'center'; ctx.fillText('❤️', p.x, p.y); break;
    case 'yazi': {
      const k = 1 + (1 - p.omur / p.maks) * 0.3;
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.a); ctx.scale(k, k);
      ctx.font = `900 ${p.boyut || 24}px Impact, "Arial Black", sans-serif`; ctx.textAlign = 'center';
      ctx.lineWidth = 5; ctx.strokeStyle = '#222'; ctx.strokeText(p.metin, 0, 0);
      ctx.fillStyle = p.renk; ctx.fillText(p.metin, 0, 0);
      ctx.restore(); break;
    }
    case 'yildiz': yildizSekli(ctx, p.x, p.y, 8, 3.5, 5, '#ffe066'); break;
    case 'duman': {
      const r = 30 + (1 - p.omur / p.maks) * 50;
      ctx.fillStyle = '#f1f3f5';
      for (let i = 0; i < 5; i++) { ctx.beginPath(); ctx.arc(p.x + Math.cos(i * 1.3) * r * 0.6, p.y + Math.sin(i * 1.3) * r * 0.4, r * 0.5, 0, Math.PI * 2); ctx.fill(); }
      break;
    }
    case 'buhar': {
      ctx.globalAlpha = Math.min(1, p.omur / p.maks, (p.maks - p.omur) / 1.5) * 0.18;
      ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.fill(); break;
    }
    case 'kivilcim':
      ctx.fillStyle = p.renk; ctx.beginPath(); ctx.arc(p.x, p.y, 3, 0, Math.PI * 2); ctx.fill(); break;
  }
  ctx.globalAlpha = 1;
}

// ------------------------------------------------------------------ çizim: arayüz
function arayuzCiz() {
  const font = '"Segoe UI", "Noto Sans", Arial, sans-serif';
  // üst başlık
  ctx.fillStyle = 'rgba(15,12,25,0.82)';
  ctx.fillRect(0, 0, W, 132);
  ctx.textAlign = 'center';
  ctx.font = `900 34px Impact, "Arial Black", ${font}`;
  const baslik = S.mod === 'horon' ? '🐔 TAVUK HORONU 🐔' : '🪩 HAMAM DİSKO 🪩';
  ctx.lineWidth = 6; ctx.strokeStyle = '#000'; ctx.strokeText(baslik, W / 2, 44);
  ctx.fillStyle = S.mod === 'horon' ? '#ffe066' : '#f783ac'; ctx.fillText(baslik, W / 2, 44);

  const cipler = [
    ['💬', 'Yorum yaz', 'katıl'], ['🥊', '"kavga"', 'dövüş'], ['🥚', '"yumurta"', 'yumurtla'],
    ['❤️', 'Beğeni', 'tempo'], ['🎁', 'Hediye', 'ÇILDIR!'],
  ];
  const cw = 136, cx0 = (W - cw * 5) / 2;
  cipler.forEach(([ik, ust, alt], i) => {
    const x = cx0 + i * cw;
    ctx.fillStyle = i === 4 ? 'rgba(255,212,59,0.18)' : 'rgba(255,255,255,0.08)';
    ctx.beginPath(); ctx.roundRect(x + 4, 58, cw - 8, 66, 10); ctx.fill();
    ctx.font = `24px ${font}`; ctx.fillStyle = '#fff'; ctx.fillText(ik, x + cw / 2, 84);
    ctx.font = `700 14px ${font}`; ctx.fillStyle = '#fff'; ctx.fillText(ust, x + cw / 2, 102);
    ctx.font = `800 13px ${font}`; ctx.fillStyle = i === 4 ? '#ffd43b' : '#9be15d'; ctx.fillText(alt, x + cw / 2, 118);
  });

  // lider tablosu
  const liste = [...S.puanlar.values()].sort((a, b) => b.puan - a.puan).slice(0, 5);
  const lx = 16, ly = 150, lw = 300, lh = 50 + Math.max(1, liste.length) * 34;
  ctx.fillStyle = 'rgba(15,40,30,0.72)';
  ctx.beginPath(); ctx.roundRect(lx, ly, lw, lh, 16); ctx.fill();
  ctx.textAlign = 'left';
  ctx.font = `800 20px ${font}`; ctx.fillStyle = '#ffe066';
  ctx.fillText('👑 Kümes Kralları', lx + 16, ly + 32);
  if (!liste.length) {
    ctx.font = `600 15px ${font}`; ctx.fillStyle = '#ccc';
    ctx.fillText('Yorum yaz, ilk sen ol!', lx + 16, ly + 66);
  }
  liste.forEach((e, i) => {
    const y = ly + 66 + i * 34;
    ctx.font = `800 17px ${font}`;
    ctx.fillStyle = ['#ffd43b', '#e9ecef', '#e8a76b', '#fff', '#fff'][i];
    ctx.fillText(i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : `${i + 1}.`, lx + 14, y);
    ctx.fillStyle = '#fff'; ctx.fillText(kisalt(e.ad, 15), lx + 50, y);
    ctx.textAlign = 'right'; ctx.fillStyle = '#ffe066';
    ctx.fillText(Math.floor(e.puan).toLocaleString('tr-TR'), lx + lw - 16, y);
    ctx.textAlign = 'left';
  });

  // tempo göstergesi
  const gx = 620, gy = 230, gr = 66;
  ctx.fillStyle = 'rgba(20,20,30,0.75)';
  ctx.beginPath(); ctx.arc(gx, gy, gr + 8, 0, Math.PI * 2); ctx.fill();
  ctx.lineWidth = 12; ctx.lineCap = 'round';
  ctx.strokeStyle = 'rgba(255,255,255,0.15)';
  ctx.beginPath(); ctx.arc(gx, gy, gr - 4, Math.PI * 0.75, Math.PI * 2.25); ctx.stroke();
  const oran = S.tempo / 100;
  ctx.strokeStyle = oran > 0.85 ? (Math.floor(S.zaman * 8) % 2 ? '#ff6b6b' : '#ffd43b') : oran > 0.6 ? '#ff922b' : '#ffa94d';
  ctx.beginPath(); ctx.arc(gx, gy, gr - 4, Math.PI * 0.75, Math.PI * (0.75 + 1.5 * Math.max(0.01, oran))); ctx.stroke();
  ctx.textAlign = 'center';
  const etiketler = S.mod === 'horon' ? ['Ağır', 'Hızlı', 'Coşkulu', 'TİTREME!'] : ['Isınıyor', 'Hareketli', 'Ateşli', 'ÇILGIN!'];
  const ei = oran > 0.85 ? 3 : oran > 0.6 ? 2 : oran > 0.3 ? 1 : 0;
  ctx.font = `20px ${font}`; ctx.fillStyle = '#fff'; ctx.fillText(S.mod === 'horon' ? '🎻' : '🪩', gx, gy - 14);
  ctx.font = `900 ${ei === 3 ? 20 : 18}px ${font}`; ctx.fillStyle = ei === 3 ? '#ffd43b' : '#fff';
  ctx.fillText(etiketler[ei], gx, gy + 14);
  ctx.font = `700 12px ${font}`; ctx.fillStyle = '#adb5bd';
  ctx.fillText('beğen = hızlan', gx, gy + 36);
  // tavuk sayısı
  ctx.fillStyle = 'rgba(20,20,30,0.75)';
  ctx.beginPath(); ctx.roundRect(gx - 55, gy + 86, 110, 36, 18); ctx.fill();
  ctx.font = `800 18px ${font}`; ctx.fillStyle = '#fff';
  ctx.fillText(`🐔 ${S.tavuklar.filter((t) => !t.npc).length}`, gx, gy + 111);

  // olay akışı
  ctx.textAlign = 'left';
  S.akis.forEach((a, i) => {
    const y = 1100 + i * 30;
    ctx.globalAlpha = Math.min(1, a.sure);
    ctx.font = `700 16px ${font}`;
    const w = Math.min(W - 32, ctx.measureText(a.metin).width + 20);
    ctx.fillStyle = 'rgba(15,12,25,0.7)';
    ctx.beginPath(); ctx.roundRect(16, y - 20, w, 27, 8); ctx.fill();
    ctx.fillStyle = a.renk; ctx.fillText(a.metin, 26, y);
    ctx.globalAlpha = 1;
  });

  // hediye rehberi (alt şerit)
  ctx.fillStyle = 'rgba(15,12,25,0.82)';
  ctx.fillRect(0, H - 34, W, 34);
  ctx.textAlign = 'center'; ctx.font = `700 14px ${font}`; ctx.fillStyle = '#ffe066';
  ctx.fillText('🌹 1+ çıldır  •  💎 30+ konfeti  •  🎁 99+ MAHALLE KAVGASI  •  🚀 500+ ALTIN TAÇ', W / 2, H - 12);

  // manşet
  if (S.manset) {
    const m = S.manset;
    const giris = Math.min(1, m.t / 0.25);
    const cikis = Math.min(1, (m.sure - m.t) / 0.3);
    const k = (giris < 1 ? 0.4 + giris * 0.75 : 1 + Math.sin(m.t * 8) * 0.03) * Math.max(0, cikis);
    ctx.save(); ctx.translate(W / 2, 470); ctx.scale(k, k); ctx.rotate(Math.sin(m.t * 3) * 0.03);
    ctx.font = `900 62px Impact, "Arial Black", ${font}`;
    ctx.lineWidth = 12; ctx.strokeStyle = '#111'; ctx.strokeText(m.metin, 0, 0);
    ctx.fillStyle = m.renk; ctx.fillText(m.metin, 0, 0);
    ctx.font = `800 24px ${font}`; ctx.lineWidth = 6; ctx.strokeText(m.alt, 0, 40);
    ctx.fillStyle = '#fff'; ctx.fillText(m.alt, 0, 40);
    ctx.restore();
  }
}

// ------------------------------------------------------------------ demo
const DEMO_ADLAR = ['Ayşe_61', 'karadenizli_temel', 'Hamsi Kızı', 'Mehmet53', 'rizeli.ali', 'Zeynep', 'kemençe_aşkı', 'Fadime', 'Oğuz Yaylalı', 'cemile.bildik', 'Hasan Usta', 'horoncu_dursun', 'Nazlı', 'trabzonlu_emre', 'Elif', 'Bayram', 'artvinli', 'sümeyye24'];
const DEMO_YORUM = ['Selam!', 'Hoppa!', 'kavga', 'Ooo süper', 'yumurta', 'Horon horon!', 'kavga @Zeynep', 'hahaha', 'Bizim köyden selamlar', 'çıldır', 'Tempoyu artır!', '😂😂😂', 'Hamsi var mı?', 'yumurta', 'Ula ne güzel'];
function demoGuncelle(dt) {
  S.demoSayac -= dt;
  if (S.demoSayac > 0) return;
  S.demoSayac = rnd(0.3, 1.4);
  const ad = sec(DEMO_ADLAR);
  const kisi = { id: 'demo_' + ad, ad };
  const r = Math.random();
  if (r < 0.55) olayIsle({ tur: 'yorum', kisi, metin: sec(DEMO_YORUM) });
  else if (r < 0.85) olayIsle({ tur: 'begeni', kisi, adet: rint(1, 15) });
  else if (r < 0.95) olayIsle({ tur: 'hediye', kisi, jeton: sec([1, 1, 1, 5, 10]), hediye: sec(['Gül', 'Kalp', 'Donat']), adet: rint(1, 3) });
  else if (r < 0.985) olayIsle({ tur: 'takip', kisi });
  else olayIsle({ tur: 'hediye', kisi, jeton: sec([99, 100, 199]), hediye: 'Büyük Hediye', adet: 1 });
}

// ------------------------------------------------------------------ bağlantı ve kontrol
function komutIsle(m) {
  switch (m.ad) {
    case 'mod': modDegistir(m.deger); break;
    case 'demo': S.demo = !!m.deger; akisEkle(S.demo ? 'Demo modu açık' : 'Demo modu kapalı', '#adb5bd'); break;
    case 'otoMod': S.otoMod = !!m.deger; S.otoModSayac = 0; break;
    case 'sifirla': S.puanlar.clear(); break;
    case 'temizle': [...S.tavuklar].forEach((c) => !c.npc && tavukCikar(c)); if (!S.tavuklar.length) npcEkle(); break;
    case 'ses': ses.sesAcKapa(); break;
    case 'topluKavga': mansetGoster('MAHALLE KAVGASI!', 'Herkes birbirine girdi', '#ff6b6b'); topluKavga(null); break;
  }
}

function sunucuyaBaglan() {
  if (location.protocol === 'file:') return;
  const ws = new WebSocket(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/ws`);
  ws.onmessage = (e) => {
    let m;
    try { m = JSON.parse(e.data); } catch { return; }
    if (m.type === 'olay') olayIsle(m);
    else if (m.type === 'komut') komutIsle(m);
  };
  ws.onclose = () => setTimeout(sunucuyaBaglan, 3000);
}

// ------------------------------------------------------------------ başlat
function boyutla() {
  const oran = Math.min(window.innerWidth / W, window.innerHeight / H);
  tuval.style.width = `${W * oran}px`;
  tuval.style.height = `${H * oran}px`;
}
window.addEventListener('resize', boyutla);
boyutla();

const sesUyari = document.getElementById('ses-uyari');
function sesiBaslat() {
  ses.baslat();
  setTimeout(() => { if (ses.calisiyor) sesUyari.style.display = 'none'; }, 200);
}
window.addEventListener('pointerdown', sesiBaslat);
window.addEventListener('keydown', (e) => {
  sesiBaslat();
  const k = e.key.toLowerCase();
  const test = { id: 'test_' + rint(1, 6), ad: sec(DEMO_ADLAR) };
  if (k === 'm') modDegistir(S.mod === 'horon' ? 'hamam' : 'horon');
  else if (k === 'd') komutIsle({ ad: 'demo', deger: !S.demo });
  else if (k === 's') ses.sesAcKapa();
  else if (k === '1') olayIsle({ tur: 'yorum', kisi: test, metin: 'Selam!' });
  else if (k === '2') olayIsle({ tur: 'yorum', kisi: test, metin: 'kavga' });
  else if (k === '3') olayIsle({ tur: 'begeni', kisi: test, adet: 30 });
  else if (k === '4') olayIsle({ tur: 'hediye', kisi: test, jeton: 1, hediye: 'Gül', adet: 1 });
  else if (k === '5') olayIsle({ tur: 'hediye', kisi: test, jeton: 99, hediye: 'Büyük Hediye', adet: 1 });
  else if (k === '6') olayIsle({ tur: 'hediye', kisi: test, jeton: 500, hediye: 'Roket', adet: 1 });
  else if (k === '7') olayIsle({ tur: 'yorum', kisi: test, metin: 'yumurta' });
});

const params = new URLSearchParams(location.search);
if (params.get('mod') === 'hamam') { S.mod = 'hamam'; ses.modAyarla('hamam'); }
if (params.get('demo') === '1') S.demo = true;
npcEkle();
sesiBaslat();
sunucuyaBaglan();

let onceki = performance.now();
function dongu(simdi) {
  const dt = Math.min(0.05, (simdi - onceki) / 1000);
  onceki = simdi;
  guncelle(dt);
  ciz();
  requestAnimationFrame(dongu);
}
requestAnimationFrame(dongu);

// test/otomasyon için
window.__oyun = { S, olayIsle, komutIsle, modDegistir };
