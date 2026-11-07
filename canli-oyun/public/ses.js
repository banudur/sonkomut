// Ses motoru: tamamen kodla üretilen müzik ve efektler (dosya gerekmez).
// Horon: 7/16 aksak ritim (2+2+3), davul + kemençe benzeri ezgi.
// Disko: 4/4 tekme, el çırpma, zil, oktav bas ve akor vuruşları.

export class Ses {
  constructor() {
    this.ctx = null;
    this.mod = 'horon';
    this.hiz = 1;          // 1 = normal, 1.6 = çılgın
    this.acik = true;
    this.adim = 0;
    this.sonrakiZaman = 0;
    this.vuruslar = [];    // görsel senkron için {zaman, guclu}
    this.sonEfekt = {};
  }

  baslat() {
    if (this.ctx) { if (this.ctx.state !== 'running') this.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    this.ctx = new AC();
    const c = this.ctx;
    this.ana = c.createGain();
    this.ana.gain.value = 0.7;
    const komp = c.createDynamicsCompressor();
    komp.threshold.value = -14;
    komp.ratio.value = 4;
    this.ana.connect(komp).connect(c.destination);
    this.muzikKazanc = c.createGain();
    this.muzikKazanc.gain.value = 0.55;
    this.muzikKazanc.connect(this.ana);
    this.efektKazanc = c.createGain();
    this.efektKazanc.gain.value = 0.8;
    this.efektKazanc.connect(this.ana);

    const len = c.sampleRate;
    this.gurultu = c.createBuffer(1, len, c.sampleRate);
    const d = this.gurultu.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;

    this.sonrakiZaman = c.currentTime + 0.1;
    setInterval(() => this.zamanla(), 25);
  }

  get calisiyor() { return this.ctx && this.ctx.state === 'running'; }

  modAyarla(m) { this.mod = m; this.adim = 0; }
  sesAcKapa() {
    this.acik = !this.acik;
    if (this.ana) this.ana.gain.setTargetAtTime(this.acik ? 0.7 : 0, this.ctx.currentTime, 0.05);
    return this.acik;
  }

  // ---------------------------------------------------------------- zamanlayıcı
  zamanla() {
    const c = this.ctx;
    if (!c || c.state !== 'running') return;
    if (this.sonrakiZaman < c.currentTime - 0.2) this.sonrakiZaman = c.currentTime + 0.05;
    while (this.sonrakiZaman < c.currentTime + 0.12) {
      if (this.mod === 'horon') this.horonAdim(this.adim, this.sonrakiZaman);
      else this.diskoAdim(this.adim, this.sonrakiZaman);
      this.adim++;
      this.sonrakiZaman += this.adimSuresi();
    }
  }

  adimSuresi() {
    // horon: 16'lık ≈ 0.085 sn → ölçü (7 adım) ≈ 0.6 sn; disko: 118 bpm 16'lık
    const temel = this.mod === 'horon' ? 0.085 : 60 / 118 / 4;
    return temel / this.hiz;
  }

  // Görsel tarafın vuruşa göre zıplaması için: 0..1 arası faz
  vurusFazi() {
    if (!this.ctx) return (performance.now() / 600) % 1;
    const t = this.ctx.currentTime;
    while (this.vuruslar.length > 1 && this.vuruslar[1].zaman <= t) this.vuruslar.shift();
    const v = this.vuruslar[0];
    if (!v || v.zaman > t) return 0.5;
    const sure = this.mod === 'horon' ? this.adimSuresi() * 2 : this.adimSuresi() * 4;
    return Math.min(1, (t - v.zaman) / sure);
  }

  vurusEkle(zaman, guclu) {
    this.vuruslar.push({ zaman, guclu });
    if (this.vuruslar.length > 32) this.vuruslar.shift();
  }

  // ---------------------------------------------------------------- horon
  horonAdim(i, t) {
    const olcu = Math.floor(i / 7);
    const k = i % 7; // 2+2+3
    if (k === 0) { this.davul(t, 1); this.vurusEkle(t, true); }
    if (k === 2 || k === 4) { this.tokmak(t, k === 4 ? 0.9 : 0.6); this.vurusEkle(t, false); }
    if (k === 6 && olcu % 2 === 1) this.tokmak(t, 0.4);
    if (k === 5 && olcu % 4 === 3) this.davul(t, 0.6);

    // kemençe ezgisi: dorian makama yakın (Re-Mi-Fa-Sol-La-Si♭-Do)
    const derece = HORON_EZGI[(olcu % 8) * 7 + k];
    if (derece !== null) {
      const midi = 62 + DORIAN[((derece % 7) + 7) % 7] + 12 * Math.floor(derece / 7);
      const sure = (k === 4 || k === 5) ? this.adimSuresi() * 1.4 : this.adimSuresi() * 0.95;
      this.kemence(t, midi, sure);
    }
  }

  davul(t, guc) {
    const c = this.ctx;
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = 'sine';
    o.frequency.setValueAtTime(140, t);
    o.frequency.exponentialRampToValueAtTime(45, t + 0.18);
    g.gain.setValueAtTime(0.9 * guc, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
    o.connect(g).connect(this.muzikKazanc);
    o.start(t); o.stop(t + 0.32);
    this.gurultuPatla(t, 0.05, 900, 'lowpass', 0.3 * guc, this.muzikKazanc);
  }

  tokmak(t, guc) {
    this.gurultuPatla(t, 0.04, 3200, 'bandpass', 0.35 * guc, this.muzikKazanc);
  }

  kemence(t, midi, sure) {
    const c = this.ctx;
    const f = 440 * Math.pow(2, (midi - 69) / 12);
    const o = c.createOscillator();
    o.type = 'sawtooth';
    o.frequency.setValueAtTime(f, t);
    const vib = c.createOscillator();
    const vibG = c.createGain();
    vib.frequency.value = 6.5;
    vibG.gain.value = f * 0.012;
    vib.connect(vibG).connect(o.frequency);
    const filtre = c.createBiquadFilter();
    filtre.type = 'bandpass';
    filtre.frequency.value = 1400;
    filtre.Q.value = 0.9;
    const tepe = c.createBiquadFilter();
    tepe.type = 'peaking';
    tepe.frequency.value = 2600; tepe.gain.value = 6;
    const g = c.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(0.22, t + 0.015);
    g.gain.setValueAtTime(0.2, t + sure * 0.7);
    g.gain.exponentialRampToValueAtTime(0.001, t + sure + 0.04);
    o.connect(filtre).connect(tepe).connect(g).connect(this.muzikKazanc);
    o.start(t); vib.start(t);
    o.stop(t + sure + 0.06); vib.stop(t + sure + 0.06);
  }

  // ---------------------------------------------------------------- disko
  diskoAdim(i, t) {
    const k = i % 16;
    const olcu = Math.floor(i / 16);
    if (k % 4 === 0) { this.tekme(t); this.vurusEkle(t, true); }
    if (k === 4 || k === 12) this.alkis(t);
    if (k % 4 === 2) this.gurultuPatla(t, 0.12, 7000, 'highpass', 0.13, this.muzikKazanc);
    else this.gurultuPatla(t, 0.025, 9000, 'highpass', 0.05, this.muzikKazanc);

    const akor = DISKO_AKOR[olcu % 4];
    if (k % 2 === 0) {
      const nota = akor[0] + (k % 4 === 2 ? 12 : 0);
      this.bas(t, nota, this.adimSuresi() * 1.6);
    }
    if (k === 2 || k === 6 || k === 10 || k === 14) {
      for (const n of akor) this.akorVurus(t, n + 24, this.adimSuresi() * 0.9);
    }
    // ufak lead ezgi
    const lead = DISKO_LEAD[(olcu % 2) * 16 + k];
    if (lead !== null) this.lead(t, akor[0] + 36 + lead, this.adimSuresi() * 1.8);
  }

  tekme(t) {
    const c = this.ctx;
    const o = c.createOscillator();
    const g = c.createGain();
    o.frequency.setValueAtTime(160, t);
    o.frequency.exponentialRampToValueAtTime(42, t + 0.12);
    g.gain.setValueAtTime(1, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.25);
    o.connect(g).connect(this.muzikKazanc);
    o.start(t); o.stop(t + 0.26);
  }

  alkis(t) {
    for (let j = 0; j < 3; j++) this.gurultuPatla(t + j * 0.011, 0.05, 1600, 'bandpass', 0.35, this.muzikKazanc);
  }

  bas(t, midi, sure) {
    const c = this.ctx;
    const f = 440 * Math.pow(2, (midi - 69) / 12);
    const o = c.createOscillator();
    o.type = 'square';
    o.frequency.value = f;
    const fl = c.createBiquadFilter();
    fl.type = 'lowpass';
    fl.frequency.setValueAtTime(900, t);
    fl.frequency.exponentialRampToValueAtTime(200, t + sure);
    const g = c.createGain();
    g.gain.setValueAtTime(0.28, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + sure);
    o.connect(fl).connect(g).connect(this.muzikKazanc);
    o.start(t); o.stop(t + sure + 0.02);
  }

  akorVurus(t, midi, sure) {
    const c = this.ctx;
    const o = c.createOscillator();
    o.type = 'sawtooth';
    o.frequency.value = 440 * Math.pow(2, (midi - 69) / 12);
    const fl = c.createBiquadFilter();
    fl.type = 'lowpass'; fl.frequency.value = 2400;
    const g = c.createGain();
    g.gain.setValueAtTime(0.06, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + sure);
    o.connect(fl).connect(g).connect(this.muzikKazanc);
    o.start(t); o.stop(t + sure + 0.02);
  }

  lead(t, midi, sure) {
    const c = this.ctx;
    const o = c.createOscillator();
    o.type = 'triangle';
    o.frequency.value = 440 * Math.pow(2, (midi - 69) / 12);
    const g = c.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(0.12, t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.001, t + sure);
    o.connect(g).connect(this.muzikKazanc);
    o.start(t); o.stop(t + sure + 0.02);
  }

  // ---------------------------------------------------------------- efektler
  gurultuPatla(t, sure, frekans, tur, guc, hedef) {
    const c = this.ctx;
    const k = c.createBufferSource();
    k.buffer = this.gurultu;
    const f = c.createBiquadFilter();
    f.type = tur; f.frequency.value = frekans;
    const g = c.createGain();
    g.gain.setValueAtTime(guc, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + sure);
    k.connect(f).connect(g).connect(hedef || this.efektKazanc);
    k.start(t, Math.random() * 0.5); k.stop(t + sure + 0.01);
  }

  sinirla(ad, aralik) {
    const simdi = performance.now();
    if (this.sonEfekt[ad] && simdi - this.sonEfekt[ad] < aralik) return false;
    this.sonEfekt[ad] = simdi;
    return true;
  }

  gidak(kac = 1, perde = 1) {
    if (this.mod === 'hamam') { this.islik(perde); return; }
    if (!this.calisiyor || !this.sinirla('gidak', 120)) return;
    const c = this.ctx;
    let t = c.currentTime + 0.01;
    for (let i = 0; i < kac; i++) {
      const o = c.createOscillator();
      o.type = 'square';
      const f0 = (700 + Math.random() * 250) * perde;
      o.frequency.setValueAtTime(f0, t);
      o.frequency.exponentialRampToValueAtTime(f0 * 0.55, t + 0.07);
      const fl = c.createBiquadFilter();
      fl.type = 'bandpass'; fl.frequency.value = 1500; fl.Q.value = 2;
      const g = c.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.linearRampToValueAtTime(0.35, t + 0.008);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.09);
      o.connect(fl).connect(g).connect(this.efektKazanc);
      o.start(t); o.stop(t + 0.1);
      t += 0.11 + Math.random() * 0.04;
    }
    // son "gıdaaak" uzun
    if (kac >= 3) {
      const o = c.createOscillator();
      o.type = 'square';
      o.frequency.setValueAtTime(900 * perde, t);
      o.frequency.linearRampToValueAtTime(1300 * perde, t + 0.08);
      o.frequency.exponentialRampToValueAtTime(600 * perde, t + 0.3);
      const fl = c.createBiquadFilter();
      fl.type = 'bandpass'; fl.frequency.value = 1700; fl.Q.value = 2;
      const g = c.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.linearRampToValueAtTime(0.35, t + 0.02);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.32);
      o.connect(fl).connect(g).connect(this.efektKazanc);
      o.start(t); o.stop(t + 0.34);
    }
  }

  yumruk() {
    if (!this.calisiyor || !this.sinirla('yumruk', 90)) return;
    const c = this.ctx, t = c.currentTime + 0.005;
    const o = c.createOscillator();
    const g = c.createGain();
    o.frequency.setValueAtTime(220, t);
    o.frequency.exponentialRampToValueAtTime(50, t + 0.12);
    g.gain.setValueAtTime(0.8, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.16);
    o.connect(g).connect(this.efektKazanc);
    o.start(t); o.stop(t + 0.17);
    this.gurultuPatla(t, 0.08, 1800, 'lowpass', 0.6);
  }

  pat() {
    if (!this.calisiyor || !this.sinirla('pat', 60)) return;
    const c = this.ctx, t = c.currentTime + 0.005;
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = 'sine';
    o.frequency.setValueAtTime(500, t);
    o.frequency.exponentialRampToValueAtTime(1400, t + 0.06);
    g.gain.setValueAtTime(0.35, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.1);
    o.connect(g).connect(this.efektKazanc);
    o.start(t); o.stop(t + 0.11);
  }

  ziplama() {
    if (!this.calisiyor || !this.sinirla('zip', 80)) return;
    const c = this.ctx, t = c.currentTime + 0.005;
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = 'triangle';
    o.frequency.setValueAtTime(300, t);
    o.frequency.exponentialRampToValueAtTime(900, t + 0.15);
    g.gain.setValueAtTime(0.25, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.18);
    o.connect(g).connect(this.efektKazanc);
    o.start(t); o.stop(t + 0.2);
  }

  fanfar(buyuk = false) {
    if (!this.calisiyor) return;
    const c = this.ctx;
    const notalar = buyuk ? [60, 64, 67, 72, 76, 79, 84] : [67, 72, 76, 79];
    notalar.forEach((n, i) => {
      const t = c.currentTime + 0.02 + i * 0.08;
      const o = c.createOscillator();
      o.type = 'square';
      o.frequency.value = 440 * Math.pow(2, (n - 69) / 12);
      const g = c.createGain();
      const sure = i === notalar.length - 1 ? 0.6 : 0.15;
      g.gain.setValueAtTime(0.0001, t);
      g.gain.linearRampToValueAtTime(0.16, t + 0.01);
      g.gain.exponentialRampToValueAtTime(0.001, t + sure);
      o.connect(g).connect(this.efektKazanc);
      o.start(t); o.stop(t + sure + 0.02);
    });
  }

  havaiFisek() {
    if (!this.calisiyor || !this.sinirla('fisek', 150)) return;
    const c = this.ctx, t = c.currentTime + 0.01;
    const o = c.createOscillator();
    const g = c.createGain();
    o.frequency.setValueAtTime(600, t);
    o.frequency.exponentialRampToValueAtTime(2200, t + 0.5);
    g.gain.setValueAtTime(0.08, t);
    g.gain.linearRampToValueAtTime(0.001, t + 0.5);
    o.connect(g).connect(this.efektKazanc);
    o.start(t); o.stop(t + 0.52);
    this.gurultuPatla(t + 0.5, 0.6, 1200, 'lowpass', 0.7);
  }

  islik(perde = 1) {
    if (!this.calisiyor || !this.sinirla('islik', 260)) return;
    const c = this.ctx, t = c.currentTime + 0.01;
    const o = c.createOscillator();
    o.type = 'sine';
    const f = (800 + Math.random() * 300) * perde;
    o.frequency.setValueAtTime(f * 0.7, t);
    o.frequency.exponentialRampToValueAtTime(f * 1.6, t + 0.16);
    o.frequency.exponentialRampToValueAtTime(f * 1.05, t + 0.34);
    const g = c.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(0.16, t + 0.03);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.38);
    o.connect(g).connect(this.efektKazanc);
    o.start(t); o.stop(t + 0.4);
  }

  kese() {
    if (!this.calisiyor || !this.sinirla('kese', 130)) return;
    this.gurultuPatla(this.ctx.currentTime + 0.005, 0.12, 2800, 'bandpass', 0.3);
  }

  su() {
    if (!this.calisiyor || !this.sinirla('su', 300)) return;
    const c = this.ctx, t = c.currentTime + 0.005;
    this.gurultuPatla(t, 0.7, 1400, 'lowpass', 0.55);
    for (let i = 0; i < 6; i++) {
      const tt = t + 0.5 + i * 0.05 + Math.random() * 0.03;
      const o = c.createOscillator();
      const g = c.createGain();
      o.type = 'sine';
      o.frequency.setValueAtTime(rndF(500, 900), tt);
      o.frequency.exponentialRampToValueAtTime(rndF(1200, 1800), tt + 0.05);
      g.gain.setValueAtTime(0.12, tt);
      g.gain.exponentialRampToValueAtTime(0.001, tt + 0.06);
      o.connect(g).connect(this.efektKazanc);
      o.start(tt); o.stop(tt + 0.07);
    }
  }

  dusus() {
    if (!this.calisiyor || !this.sinirla('dusus', 200)) return;
    const c = this.ctx, t = c.currentTime + 0.005;
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = 'sine';
    o.frequency.setValueAtTime(900, t);
    o.frequency.exponentialRampToValueAtTime(120, t + 0.6);
    g.gain.setValueAtTime(0.25, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.65);
    o.connect(g).connect(this.efektKazanc);
    o.start(t); o.stop(t + 0.66);
  }
}

const DORIAN = [0, 2, 3, 5, 7, 9, 10];
const _ = null;
// 8 ölçü x 7 adım; sayılar dorian derecesi (0 = Re)
const HORON_EZGI = [
  4, 4, 3, 4, 2, 3, 1,
  2, 2, 1, 2, 0, 1, _,
  4, 4, 3, 4, 5, 4, 3,
  2, 3, 2, 1, 0, _, 0,
  7, 6, 5, 6, 4, 5, 3,
  4, 3, 2, 3, 1, 2, _,
  2, 3, 4, 5, 4, 3, 2,
  1, 2, 1, 0, 0, _, -1,
];
const DISKO_AKOR = [
  [45, 48, 52], // La minör
  [41, 45, 48], // Fa
  [48, 52, 55], // Do
  [43, 47, 50], // Sol
];
const DISKO_LEAD = [
  0, _, 7, _, 12, _, 7, _, 10, _, 7, _, 3, _, 5, _,
  0, _, 7, _, 12, 14, 12, _, 10, _, 12, _, 7, _, _, _,
];

function rndF(a, b) { return a + Math.random() * (b - a); }
