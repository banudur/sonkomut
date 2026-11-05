"""Giriş müziğini sentezler: client/audio/intro_theme.ogg

Telif sorunu olmasın diye tamamen kodla üretilen özgün, döngüye uygun bir parça.
Çalıştırma:  python tools/make_intro_music.py   (numpy ve ffmpeg gerekir)
"""

from __future__ import annotations

import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
BPM = 104
BEAT = 60.0 / BPM
BARS = 8
LENGTH = BARS * 4 * BEAT
N = int(LENGTH * SR)
rng = np.random.default_rng(7)


def midi_hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def env(n: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


def add(buf: np.ndarray, start_beat: float, sig: np.ndarray) -> None:
    """Sinyali döngüyü sarmalayarak ekler (kuyruk başa taşar → kesintisiz döngü)."""
    s = int(start_beat * BEAT * SR)
    idx = (np.arange(len(sig)) + s) % N
    np.add.at(buf, idx, sig)


def pluck(m: float, dur: float, vol: float) -> np.ndarray:
    n = int((dur + 0.6) * SR)
    t = np.arange(n) / SR
    f = midi_hz(m)
    s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) + 0.12 * np.sin(6 * np.pi * f * t)
    return vol * s * env(n, 0.004, 0.22)


def bell(m: float, dur: float, vol: float) -> np.ndarray:
    n = int((dur + 1.2) * SR)
    t = np.arange(n) / SR
    f = midi_hz(m)
    mod = 1.6 * np.exp(-t / 0.35) * np.sin(2 * np.pi * f * 3.5 * t)
    s = np.sin(2 * np.pi * f * t + mod) + 0.25 * np.sin(2 * np.pi * f * 2 * t)
    return vol * s * env(n, 0.003, 0.55)


def pad(notes: list[int], dur: float, vol: float) -> np.ndarray:
    n = int((dur + 0.5) * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for m in notes:
        for det in (-0.08, 0.08):
            f = midi_hz(m + det)
            s += np.sin(2 * np.pi * f * t) + 0.2 * np.sin(4 * np.pi * f * t)
    a = np.clip(t / 0.35, 0, 1) * np.clip((dur + 0.5 - t) / 0.5, 0, 1)
    return vol * s * a / len(notes)


def bass(m: float, dur: float, vol: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = midi_hz(m)
    s = np.tanh(1.8 * (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t)))
    return vol * s * env(n, 0.006, 0.35)


def kick(vol: float) -> np.ndarray:
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 45 + 90 * np.exp(-t / 0.04)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return vol * np.sin(phase) * np.exp(-t / 0.12)


def noise_hit(dur: float, decay: float, vol: float, highpass: bool) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = rng.standard_normal(n)
    if highpass:
        s = np.diff(s, prepend=0.0)
    else:  # alçak frekansları hafifçe süzerek "el çırpma"
        s = np.convolve(s, np.ones(6) / 6, mode="same") - np.convolve(s, np.ones(40) / 40, mode="same")
    return vol * s * np.exp(-t / decay)


# Akorlar (bar başına): C  Am  F  G  C  Em  F/G  C
CHORDS = [
    [60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62],
    [60, 64, 67], [52, 55, 59], [53, 57, 60], [60, 64, 67],
]
BASS = [36, 33, 29, 31, 36, 28, 29, 36]
# (vuruş, midi, süre)
MELODY = [
    (0, 76, 1), (1, 79, .5), (1.5, 81, .5), (2, 79, 1), (3, 76, 1),
    (4, 72, 1), (5, 76, .5), (5.5, 74, .5), (6, 72, 2),
    (8, 69, 1), (9, 72, 1), (10, 74, .5), (10.5, 76, .5), (11, 74, 1),
    (12, 74, 1), (13, 79, 1), (14, 76, .5), (14.5, 74, .5), (15, 71, 1),
    (16, 76, .5), (16.5, 79, .5), (17, 84, 1), (18, 81, 1), (19, 79, 1),
    (20, 79, 1), (21, 76, 1), (22, 74, .5), (22.5, 76, .5), (23, 79, 1),
    (24, 81, 1), (25, 79, 1), (26, 77, 1), (27, 74, 1),
    (28, 72, 2), (30, 76, .5), (30.5, 79, .5), (31, 84, 1),
]

left = np.zeros(N)
right = np.zeros(N)
mono = np.zeros(N)

for bar, chord in enumerate(CHORDS):
    b0 = bar * 4
    p = pad([c + 12 for c in chord], 4 * BEAT, 0.10)
    add(left, b0, p)
    add(right, b0, p)
    # bar 7 (F/G): ikinci yarıda G akoru
    halves = [chord] if bar != 6 else [chord, [55, 59, 62]]
    for i in range(8):  # sekizlik arpej
        ch = halves[min(i // 4, len(halves) - 1)]
        tones = ch + [ch[0] + 12]
        m = tones[[0, 1, 2, 3, 2, 1, 2, 3][i]] + 12
        sig = pluck(m, BEAT / 2, 0.11)
        add(left if i % 2 == 0 else right, b0 + i * 0.5, sig * 1.0)
        add(right if i % 2 == 0 else left, b0 + i * 0.5, sig * 0.45)
    bm = BASS[bar]
    for beat, m in ((0, bm), (1.5, bm), (2, bm + (7 if bar != 6 else 2)), (3, bm + 12)):
        add(mono, b0 + beat, bass(m, BEAT * 0.9, 0.22))
    for beat in (0, 2, 2.75):
        add(mono, b0 + beat, kick(0.5))
    for beat in (1, 3):
        add(mono, b0 + beat, noise_hit(0.25, 0.06, 0.12, False))
    for i in range(8):
        add(mono, b0 + i * 0.5, noise_hit(0.08, 0.018 if i % 2 else 0.03, 0.04, True))

for beat, m, d in MELODY:
    sig = bell(m, d * BEAT, 0.16)
    add(left, beat, sig * 0.8)
    add(right, beat, sig)

L = left + mono
R = right + mono
stereo = np.stack([L, R], axis=1)
stereo = np.tanh(1.2 * stereo / np.max(np.abs(stereo)))  # yumuşak sınırlayıcı
stereo *= 0.85 / np.max(np.abs(stereo))

out_dir = Path(__file__).resolve().parent.parent / "client" / "audio"
out_dir.mkdir(parents=True, exist_ok=True)
wav_path = out_dir / "intro_theme.wav"
with wave.open(str(wav_path), "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((stereo * 32767).astype("<i2").tobytes())

ogg_path = out_dir / "intro_theme.ogg"
subprocess.run(
    ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "5", str(ogg_path)],
    check=True,
)
wav_path.unlink()
print(f"{ogg_path}  ({LENGTH:.1f} sn, {ogg_path.stat().st_size // 1024} KB)", file=sys.stderr)
