"""API anahtarı gerektirmeyen yerel görüntü motoru.

- Nesne tanıma: MobileNetV2 (ImageNet, ~14 MB, ilk çalıştırmada indirilir) + Türkçe katalog.
- Renk: görüntünün ortasındaki baskın renk (HSV).
- "Aynı nesne mi?": ORB anahtar noktaları + RANSAC homografi (ayırt edici desenler),
  renk histogramı benzerliği ve sınıf benzerliğinin birleşimi.
- İpuçları: elle yazılmış bilmece bankasından (catalog.py), yaş grubuna göre.

Model indirilemezse tanıma kapanır; saklayan nesnenin adını kendisi seçer/yazar ve
eşleştirme yalnızca desen + renkle yapılır.
"""

from __future__ import annotations

import asyncio
import base64
import hashlib
import logging
import os
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

from . import catalog
from .ai import AIError
from .models import AllHints, Identification, MatchVerdict, ObjectProfile

log = logging.getLogger(__name__)

MODEL_URL = (
    "https://media.githubusercontent.com/media/onnx/models/main/validated/vision/"
    "classification/mobilenet/model/mobilenetv2-12.onnx"
)
MODEL_SHA256 = "c0c3f76d93fa3fd6580652a45618618a220fced18babf65774ed169de0432ad5"
MODEL_DIR = Path(os.environ.get("MODEL_DIR", Path(__file__).resolve().parent.parent / "models"))
LABELS_PATH = Path(__file__).resolve().parent / "data" / "imagenet_labels.txt"

MAX_SIDE = 640
NAME_THRESHOLD = 0.08     # bu skorun altında ad önerisi "emin değilim" sayılır
ALTERNATIVES = 5

# Eşleştirme eşikleri (gerçek cihazlarda ayarlanmalı)
STRONG_INLIERS = 30       # bu kadar tutarlı nokta = kesin aynı nesne
MEDIUM_INLIERS = 18
WEAK_INLIERS = 8
COLOR_SIMILAR = 0.45
COLOR_VERY_SIMILAR = 0.75
CLASS_SIMILAR = 0.10
CLASS_STRONG = 0.30


@dataclass
class Features:
    gray: np.ndarray
    keypoints: list
    descriptors: np.ndarray | None
    hist: np.ndarray
    class_scores: dict[str, float]   # katalog adı -> skor


def decode_jpeg_b64(b64: str) -> np.ndarray:
    try:
        raw = base64.b64decode(b64, validate=False)
    except ValueError as e:
        raise AIError("Fotoğraf okunamadı.") from e
    img = cv2.imdecode(np.frombuffer(raw, np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        raise AIError("Fotoğraf okunamadı.")
    h, w = img.shape[:2]
    k = MAX_SIDE / max(h, w)
    if k < 1:
        img = cv2.resize(img, (int(w * k), int(h * k)), interpolation=cv2.INTER_AREA)
    return img


def center_crop(img: np.ndarray, frac: float) -> np.ndarray:
    h, w = img.shape[:2]
    ch, cw = int(h * frac), int(w * frac)
    y, x = (h - ch) // 2, (w - cw) // 2
    return img[y:y + ch, x:x + cw]


# ------------------------------------------------------------------ renk

def dominant_color(img: np.ndarray) -> str:
    """Görüntünün ortasındaki baskın rengi Türkçe adıyla döner."""
    hsv = cv2.cvtColor(center_crop(img, 0.5), cv2.COLOR_BGR2HSV).reshape(-1, 3).astype(np.float32)
    h, s, v = hsv[:, 0] * 2.0, hsv[:, 1] / 255.0, hsv[:, 2] / 255.0  # h: 0-360
    colorful = (s > 0.28) & (v > 0.18)
    if colorful.mean() < 0.25:
        vv = np.median(v)
        if vv < 0.25:
            return "siyah"
        if vv > 0.75 and np.median(s) < 0.15:
            return "beyaz"
        return "gri"
    hh, ss, vv = h[colorful], s[colorful], v[colorful]
    names = []
    for hue, sat, val in zip(hh, ss, vv):
        names.append(_hue_name(hue, sat, val))
    values, counts = np.unique(names, return_counts=True)
    return str(values[counts.argmax()])


def _hue_name(h: float, s: float, v: float) -> str:
    if h < 15 or h >= 340:
        if v < 0.55 and s > 0.4:
            return "kahverengi" if h < 15 else "kırmızı"
        return "pembe" if s < 0.5 and v > 0.7 else "kırmızı"
    if h < 40:
        return "kahverengi" if v < 0.6 else "turuncu"
    if h < 68:
        return "sarı" if v > 0.5 else "kahverengi"
    if h < 165:
        return "yeşil"
    if h < 250:
        return "lacivert" if v < 0.4 else "mavi"
    if h < 290:
        return "mor"
    return "pembe"


def color_hist(img: np.ndarray) -> np.ndarray:
    hsv = cv2.cvtColor(center_crop(img, 0.7), cv2.COLOR_BGR2HSV)
    hist = cv2.calcHist([hsv], [0, 1], None, [30, 16], [0, 180, 0, 256])
    cv2.normalize(hist, hist, 0, 1, cv2.NORM_MINMAX)
    return hist


# ------------------------------------------------------------------ sınıflandırıcı

class Classifier:
    MEAN = np.array([0.485, 0.456, 0.406], np.float32).reshape(1, 3, 1, 1)
    STD = np.array([0.229, 0.224, 0.225], np.float32).reshape(1, 3, 1, 1)

    def __init__(self, model_path: Path) -> None:
        self.net = cv2.dnn.readNetFromONNX(str(model_path))
        labels = LABELS_PATH.read_text(encoding="utf-8").splitlines()
        self.index_to_item: dict[int, str] = {}
        by_label = {lab: it.name for it in catalog.ITEMS for lab in it.labels}
        for i, lab in enumerate(labels):
            if lab in by_label:
                self.index_to_item[i] = by_label[lab]

    def probabilities(self, img: np.ndarray) -> np.ndarray:
        blob = cv2.dnn.blobFromImage(img, 1 / 255.0, (224, 224), swapRB=True, crop=True)
        blob = ((blob - self.MEAN) / self.STD).astype(np.float32)
        self.net.setInput(blob)
        logits = self.net.forward()[0].astype(np.float64)
        e = np.exp(logits - logits.max())
        return e / e.sum()

    def item_scores(self, img: np.ndarray) -> dict[str, float]:
        # Oyuncu nesneyi ortalar; ortadan kırpılmış görüntüye daha çok ağırlık ver.
        p = 0.4 * self.probabilities(img) + 0.6 * self.probabilities(center_crop(img, 0.65))
        scores: dict[str, float] = {}
        for idx, name in self.index_to_item.items():
            scores[name] = scores.get(name, 0.0) + float(p[idx])
        return scores


def ensure_model() -> Path | None:
    """Modeli gerekiyorsa indirir. Başarısızsa None (tanıma kapalı çalışılır)."""
    path = MODEL_DIR / "mobilenetv2-12.onnx"
    if path.exists() and _sha256(path) == MODEL_SHA256:
        return path
    try:
        MODEL_DIR.mkdir(parents=True, exist_ok=True)
        log.info("Görüntü modeli indiriliyor (14 MB): %s", MODEL_URL)
        tmp = path.with_suffix(".part")
        urllib.request.urlretrieve(MODEL_URL, tmp)
        if _sha256(tmp) != MODEL_SHA256:
            tmp.unlink(missing_ok=True)
            raise ValueError("model dosyası doğrulanamadı")
        tmp.replace(path)
        return path
    except Exception:
        log.exception("Model indirilemedi; nesne tanıma kapalı, saklayan adı kendisi seçecek")
        return None


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ------------------------------------------------------------------ motor

class LocalVision:
    def __init__(self, classifier: Classifier | None = None, load_model: bool = True) -> None:
        self._orb = cv2.ORB_create(nfeatures=1500)
        self._matcher = cv2.BFMatcher(cv2.NORM_HAMMING)
        self._classifier = classifier
        self._load_model = load_model and classifier is None
        self._lock = asyncio.Lock()

    async def _get_classifier(self) -> Classifier | None:
        if self._classifier is None and self._load_model:
            async with self._lock:
                if self._classifier is None and self._load_model:
                    path = await asyncio.to_thread(ensure_model)
                    self._load_model = False
                    if path:
                        self._classifier = Classifier(path)
        return self._classifier

    def _features(self, img: np.ndarray, clf: Classifier | None) -> Features:
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        gray = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(gray)
        kps, desc = self._orb.detectAndCompute(gray, None)
        return Features(
            gray=gray,
            keypoints=list(kps),
            descriptors=desc,
            hist=color_hist(img),
            class_scores=clf.item_scores(img) if clf else {},
        )

    def _inliers(self, a: Features, b: Features) -> int:
        if a.descriptors is None or b.descriptors is None or len(a.keypoints) < 8 or len(b.keypoints) < 8:
            return 0
        pairs = self._matcher.knnMatch(a.descriptors, b.descriptors, k=2)
        good = [m for m, *rest in pairs if rest and m.distance < 0.75 * rest[0].distance]
        if len(good) < 8:
            return 0
        src = np.float32([a.keypoints[m.queryIdx].pt for m in good]).reshape(-1, 1, 2)
        dst = np.float32([b.keypoints[m.trainIdx].pt for m in good]).reshape(-1, 1, 2)
        _, mask = cv2.findHomography(src, dst, cv2.RANSAC, 6.0)
        return int(mask.sum()) if mask is not None else 0

    # -------------------------------------------------- Vision arayüzü

    async def identify(self, images_b64: list[str]) -> Identification:
        clf = await self._get_classifier()
        return await asyncio.to_thread(self._identify_sync, images_b64, clf)

    def _identify_sync(self, images_b64: list[str], clf: Classifier | None) -> Identification:
        imgs = [decode_jpeg_b64(b) for b in images_b64]
        totals: dict[str, float] = {}
        if clf:
            for img in imgs:
                for name, sc in clf.item_scores(img).items():
                    totals[name] = totals.get(name, 0.0) + sc / len(imgs)
        ranked = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)
        colors = [dominant_color(img) for img in imgs]
        color = max(set(colors), key=colors.count)

        sure = bool(ranked) and ranked[0][1] >= NAME_THRESHOLD
        name = ranked[0][0] if sure else ""
        alternatives = [n for n, _ in ranked[:ALTERNATIVES]]
        for n in ("vazo", "kupa", "yastık", "oyuncak ayı", "kitaplık", "abajur"):
            if len(alternatives) >= ALTERNATIVES:
                break
            if n not in alternatives:
                alternatives.append(n)

        item = catalog.find(name) if name else None
        profile = ObjectProfile(
            valid=True,
            rejection_reason="",
            name=name or "eşya",
            color=color,
            material=item.material if item else "",
            category="ev eşyası",
            likely_room=item.room if item else "",
            distinctive_features=[],
            summary=f"{color} {name}".strip() if name else f"{color} bir eşya",
        )
        log.info("tanıma: %s (emin=%s) adaylar=%s", profile.summary, sure, ranked[:3])
        return Identification(profile=profile, alternatives=alternatives, needs_name=not sure,
                              colors=catalog.COLOR_NAMES)

    async def make_hints(self, profile: ObjectProfile) -> AllHints:
        return catalog.build_hints(profile)

    async def verify(self, profile: ObjectProfile, reference_b64: list[str], candidate_b64: str) -> MatchVerdict:
        clf = await self._get_classifier()
        return await asyncio.to_thread(self._verify_sync, profile, reference_b64, candidate_b64, clf)

    def _verify_sync(self, profile: ObjectProfile, reference_b64: list[str], candidate_b64: str,
                     clf: Classifier | None) -> MatchVerdict:
        cand = self._features(decode_jpeg_b64(candidate_b64), clf)
        refs = [self._features(decode_jpeg_b64(b), None) for b in reference_b64]
        inliers = max((self._inliers(r, cand) for r in refs), default=0)
        color = max((float(cv2.compareHist(r.hist, cand.hist, cv2.HISTCMP_CORREL)) for r in refs), default=0.0)
        cls = cand.class_scores.get(profile.name, 0.0)

        if inliers >= STRONG_INLIERS:
            same, conf = True, 0.95
        elif inliers >= MEDIUM_INLIERS and (color >= COLOR_SIMILAR or cls >= CLASS_SIMILAR):
            same, conf = True, 0.85
        elif inliers >= WEAK_INLIERS and color >= COLOR_VERY_SIMILAR and cls >= CLASS_STRONG:
            # Deseni az olan düz nesneler (tek renk vazo gibi): tür + renk + biraz desen
            same, conf = True, 0.7
        else:
            same, conf = False, min(0.5, inliers / STRONG_INLIERS * 0.5 + max(color, 0) * 0.2)

        log.info("eşleştirme: inliers=%d renk=%.2f sınıf=%.2f -> %s", inliers, color, cls, same)
        if same:
            feedback = "Buldun! Tebrikler!"
        elif inliers >= WEAK_INLIERS or color >= COLOR_VERY_SIMILAR:
            feedback = "Yaklaştın! Başka bir açıdan ya da daha yakından dene."
        else:
            feedback = "Bu değil, aramaya devam!"
        return MatchVerdict(same_object=same, confidence=conf, feedback=feedback)
