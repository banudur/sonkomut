"""Yerel (API anahtarsız) görüntü motoru testleri.

Gerçek fotoğraf yerine sentetik, desenli görüntüler kullanılır: aynı "nesne" farklı açı,
ölçek ve ışıkta çekilmiş gibi dönüştürülür; başka bir nesne ise eşleşmemelidir.
"""

import asyncio
import base64

import cv2
import numpy as np
import pytest

from app import catalog
from app.local_ai import LocalVision, dominant_color
from app.models import AgeBand, ObjectProfile


def _object_image(seed: int, base=(200, 120, 40)) -> np.ndarray:
    """Desenli bir nesne: renkli zemin üstünde rastgele şekiller ve yazı."""
    rng = np.random.default_rng(seed)
    img = np.full((480, 640, 3), 235, np.uint8)
    ox, oy = int(rng.integers(-60, 60)), int(rng.integers(-40, 40))
    cv2.rectangle(img, (160 + ox, 80 + oy), (480 + ox, 400 + oy), base, -1)
    for _ in range(40):
        c = tuple(int(x) for x in rng.integers(0, 255, 3))
        p = tuple(int(x) for x in rng.integers([170 + ox, 90 + oy], [470 + ox, 390 + oy]))
        r = int(rng.integers(5, 30))
        if rng.random() < 0.5:
            cv2.circle(img, p, r, c, -1)
        else:
            cv2.rectangle(img, p, (p[0] + r, p[1] + r // 2), c, -1)
    cv2.putText(img, f"N{seed}", (200 + ox, 260 + oy), cv2.FONT_HERSHEY_SIMPLEX, 2.5, (255, 255, 255), 6)
    return img


def _transform(img: np.ndarray, angle: float, scale: float, bright: float) -> np.ndarray:
    h, w = img.shape[:2]
    m = cv2.getRotationMatrix2D((w / 2, h / 2), angle, scale)
    out = cv2.warpAffine(img, m, (w, h), borderValue=(90, 90, 90))
    return cv2.convertScaleAbs(out, alpha=bright, beta=0)


def _b64(img: np.ndarray) -> str:
    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 85])
    assert ok
    return base64.b64encode(buf.tobytes()).decode()


def _profile(name="vazo", color="mavi") -> ObjectProfile:
    return ObjectProfile(valid=True, rejection_reason="", name=name, color=color, material="",
                         category="", likely_room="salon", distinctive_features=[], summary=f"{color} {name}")


@pytest.fixture(scope="module")
def vision():
    return LocalVision(load_model=False)  # testlerde model indirilmez


def test_same_object_matches_under_viewpoint_changes(vision):
    obj = _object_image(1)
    refs = [_b64(obj), _b64(_transform(obj, 10, 0.95, 1.0))]
    for angle, scale, bright in [(25, 0.8, 1.0), (-15, 1.15, 0.8), (5, 0.7, 1.2)]:
        cand = _b64(_transform(obj, angle, scale, bright))
        v = asyncio.run(vision.verify(_profile(), refs, cand))
        assert v.same_object, (angle, scale, bright)


def test_different_object_does_not_match(vision):
    refs = [_b64(_object_image(1))]
    for seed in (2, 3, 4):
        cand = _b64(_object_image(seed))  # aynı renk zemin, farklı desen
        v = asyncio.run(vision.verify(_profile(), refs, cand))
        assert not v.same_object, seed


def test_blank_wall_does_not_match(vision):
    refs = [_b64(_object_image(1))]
    wall = np.full((480, 640, 3), 200, np.uint8)
    v = asyncio.run(vision.verify(_profile(), refs, _b64(wall)))
    assert not v.same_object and "Bu değil" in v.feedback


@pytest.mark.parametrize("bgr,name", [
    ((220, 120, 30), "mavi"),
    ((40, 40, 220), "kırmızı"),
    ((40, 200, 40), "yeşil"),
    ((30, 220, 240), "sarı"),
    ((245, 245, 245), "beyaz"),
    ((20, 20, 20), "siyah"),
    ((130, 130, 130), "gri"),
    ((200, 50, 150), "mor"),
])
def test_dominant_color(bgr, name):
    img = np.full((300, 300, 3), bgr, np.uint8)
    assert dominant_color(img) == name


def test_identify_without_model_asks_hider_for_name(vision):
    obj = _object_image(1, base=(220, 120, 30))
    ident = asyncio.run(vision.identify([_b64(obj)]))
    assert ident.needs_name
    assert ident.alternatives and ident.colors
    assert ident.profile.valid


def test_catalog_hints_never_reveal_name():
    for item in catalog.ITEMS:
        hints = catalog.build_hints(_profile(item.name, "mavi"))
        for band in AgeBand:
            hs = hints.for_band(band)
            for text in (hs.association, hs.attribute, hs.location):
                assert text
                for word in item.name.split():
                    if len(word) > 3:
                        assert word not in text.lower(), (item.name, text)


def test_hints_differ_by_age():
    hints = catalog.build_hints(_profile("vazo", "mavi"))
    assert hints.child.association == "Çiçekler bende su içer!"
    assert hints.adult.association != hints.child.association
    assert hints.child.attribute == "Gökyüzü gibi bir rengim var."
    assert hints.adult.location == "Misafirlerin ağırlandığı yerde ara."


def test_unknown_object_gets_letter_hint():
    hints = catalog.build_hints(_profile("zımba", "kırmızı").model_copy(update={"likely_room": ""}))
    assert "Z" in hints.child.association
    assert "5 harfli" in hints.adult.association


def test_catalog_labels_exist_in_model_labels():
    from app.local_ai import LABELS_PATH
    labels = set(LABELS_PATH.read_text(encoding="utf-8").splitlines())
    for item in catalog.ITEMS:
        for lab in item.labels:
            assert lab in labels, (item.name, lab)
