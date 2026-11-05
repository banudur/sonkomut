"""İpucu kilidini açan kısa zekâ oyunları.

Bulmacalar sunucuda üretilir ve doğrulanır; istemci yalnızca çizer ve cevabı
gönderir. Böylece cevap istemciye hiç gitmez ve hile yapılamaz.

Türler:
- matrix:   3x3 şekil matrisi, eksik hücreyi seçenekler arasından bul (Raven tarzı)
- rotation: dönen şekil dizisinin sıradaki adımını bul
- assembly: parçaları ızgaradaki hedef şekle yerleştir (şekil birleştirme)
"""

from __future__ import annotations

import random
import time
import uuid
from dataclasses import dataclass, field
from typing import Any

from .models import AgeBand

SHAPES = ["circle", "square", "triangle", "star", "diamond", "hexagon"]
COLORS = ["#E74C3C", "#3498DB", "#2ECC71", "#F1C40F", "#9B59B6", "#E67E22"]

PUZZLE_TYPES = ["matrix", "rotation", "assembly"]

# Yaş grubuna göre zorluk ayarları
DIFFICULTY: dict[AgeBand, dict[str, Any]] = {
    AgeBand.CHILD: {
        "time_limit": 0,  # 0 = süre yok
        "matrix_varying": 1,
        "matrix_options": 3,
        "rotation_step": [90],
        "rotation_color_cycle": False,
        "rotation_options": 3,
        "assembly_size": (3, 2),
        "assembly_pieces": 2,
        "assembly_scramble": False,
    },
    AgeBand.TEEN: {
        "time_limit": 90,
        "matrix_varying": 2,
        "matrix_options": 4,
        "rotation_step": [45, 90, 135],
        "rotation_color_cycle": True,
        "rotation_options": 4,
        "assembly_size": (4, 3),
        "assembly_pieces": 3,
        "assembly_scramble": True,
    },
    AgeBand.ADULT: {
        "time_limit": 60,
        "matrix_varying": 3,
        "matrix_options": 6,
        "rotation_step": [45, 135, 225, 270],
        "rotation_color_cycle": True,
        "rotation_options": 6,
        "assembly_size": (5, 4),
        "assembly_pieces": 5,
        "assembly_scramble": True,
    },
    AgeBand.SENIOR: {
        "time_limit": 0,
        "matrix_varying": 2,
        "matrix_options": 4,
        "rotation_step": [90, 180],
        "rotation_color_cycle": False,
        "rotation_options": 4,
        "assembly_size": (4, 3),
        "assembly_pieces": 3,
        "assembly_scramble": False,
    },
}

TIME_GRACE_SECONDS = 5


@dataclass
class Puzzle:
    id: str
    type: str
    band: AgeBand
    data: dict[str, Any]          # istemciye gider
    solution: Any                 # sadece sunucuda kalır
    time_limit: int
    created_at: float = field(default_factory=time.monotonic)

    def public(self) -> dict[str, Any]:
        return {
            "puzzle_id": self.id,
            "puzzle_type": self.type,
            "time_limit": self.time_limit,
            "data": self.data,
        }

    def expired(self, now: float | None = None) -> bool:
        if not self.time_limit:
            return False
        now = time.monotonic() if now is None else now
        return now - self.created_at > self.time_limit + TIME_GRACE_SECONDS


# ---------------------------------------------------------------- matrix


def _gen_matrix(band: AgeBand, rng: random.Random) -> tuple[dict, Any]:
    cfg = DIFFICULTY[band]
    attrs = ["shape", "color", "count"]
    varying = rng.sample(attrs, cfg["matrix_varying"])

    pools = {
        "shape": rng.sample(SHAPES, 3),
        "color": rng.sample(COLORS, 3),
        "count": [1, 2, 3],
    }
    # Her değişen nitelik için kural: satıra göre, sütuna göre veya latin kare
    rules = {}
    for a in attrs:
        if a in varying:
            choices = ["row", "col"] + (["latin"] if band in (AgeBand.ADULT, AgeBand.TEEN) else [])
            rules[a] = rng.choice(choices)
        else:
            rules[a] = "const"
    # Değişen niteliklerin hepsi aynı kuralı izlerse bulmaca tek boyutlu kalır; karıştır
    if len(varying) >= 2 and len({rules[a] for a in varying}) == 1:
        rules[varying[1]] = "col" if rules[varying[0]] != "col" else "row"

    def value(a: str, r: int, c: int):
        pool = pools[a]
        rule = rules[a]
        if rule == "const":
            return pool[0]
        if rule == "row":
            return pool[r]
        if rule == "col":
            return pool[c]
        return pool[(r + c) % 3]  # latin

    grid = [
        {a: value(a, r, c) for a in attrs} for r in range(3) for c in range(3)
    ]
    answer_cell = grid[8]

    # Çeldiriciler: doğru cevaptan tek nitelikte farklı (önce değişen niteliklerde)
    options = [answer_cell]
    seen = {tuple(sorted(answer_cell.items()))}
    alt_values = {
        "shape": SHAPES,
        "color": COLORS,
        "count": [1, 2, 3, 4],
    }
    attempts = 0
    while len(options) < cfg["matrix_options"] and attempts < 200:
        attempts += 1
        a = rng.choice(varying) if rng.random() < 0.75 else rng.choice(attrs)
        cand = dict(answer_cell)
        cand[a] = rng.choice([v for v in alt_values[a] if v != answer_cell[a]])
        key = tuple(sorted(cand.items()))
        if key not in seen:
            seen.add(key)
            options.append(cand)
    rng.shuffle(options)
    solution = options.index(answer_cell)
    data = {"cells": grid[:8], "options": options}
    return data, solution


# ---------------------------------------------------------------- rotation


def _gen_rotation(band: AgeBand, rng: random.Random) -> tuple[dict, Any]:
    cfg = DIFFICULTY[band]
    step = rng.choice(cfg["rotation_step"]) * rng.choice([1, -1])
    start = rng.choice([0, 45, 90, 180])
    shape = rng.choice(["arrow", "flag", "key"])
    colors = rng.sample(COLORS, 3) if cfg["rotation_color_cycle"] else [rng.choice(COLORS)]

    def frame(i: int) -> dict:
        return {"angle": (start + step * i) % 360, "color": colors[i % len(colors)]}

    sequence = [frame(i) for i in range(4)]
    answer = frame(4)
    options = [answer]
    seen = {(answer["angle"], answer["color"])}
    attempts = 0
    while len(options) < cfg["rotation_options"] and attempts < 200:
        attempts += 1
        cand = {
            "angle": (answer["angle"] + rng.choice([45, 90, 135, 180, 225, 270, 315])) % 360
            if rng.random() < 0.7 or len(colors) == 1
            else answer["angle"],
            "color": rng.choice(colors) if len(colors) > 1 else answer["color"],
        }
        key = (cand["angle"], cand["color"])
        if key not in seen:
            seen.add(key)
            options.append(cand)
    rng.shuffle(options)
    return {"shape": shape, "sequence": sequence, "options": options}, options.index(answer)


# ---------------------------------------------------------------- assembly

Cell = tuple[int, int]


def rotate_cells(cells: list[Cell], times: int) -> list[Cell]:
    """Hücreleri saat yönünde 90°*times döndürür ve (0,0)'a normalize eder."""
    out = list(cells)
    for _ in range(times % 4):
        out = [(-y, x) for x, y in out]  # (x,y) -> (-y,x): ekran koordinatında saat yönü
    min_x = min(x for x, _ in out)
    min_y = min(y for _, y in out)
    return sorted((x - min_x, y - min_y) for x, y in out)


def _partition(w: int, h: int, n: int, rng: random.Random) -> list[list[Cell]]:
    """w x h dikdörtgeni n adet bağlantılı parçaya böler (rastgele büyüme)."""
    for _ in range(100):
        all_cells = [(x, y) for x in range(w) for y in range(h)]
        seeds = rng.sample(all_cells, n)
        owner: dict[Cell, int] = {s: i for i, s in enumerate(seeds)}
        frontier = list(seeds)
        while len(owner) < w * h and frontier:
            cell = rng.choice(frontier)
            x, y = cell
            free = [
                (x + dx, y + dy)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if 0 <= x + dx < w and 0 <= y + dy < h and (x + dx, y + dy) not in owner
            ]
            if not free:
                frontier.remove(cell)
                continue
            nxt = rng.choice(free)
            owner[nxt] = owner[cell]
            frontier.append(nxt)
        pieces: list[list[Cell]] = [[] for _ in range(n)]
        for c, i in owner.items():
            pieces[i].append(c)
        # Tek hücrelik parça olmasın (çok kolay ve sıkıcı)
        if all(len(p) >= 2 for p in pieces):
            return pieces
    raise RuntimeError("parçalama başarısız")


def _gen_assembly(band: AgeBand, rng: random.Random) -> tuple[dict, Any]:
    cfg = DIFFICULTY[band]
    w, h = cfg["assembly_size"]
    pieces = _partition(w, h, cfg["assembly_pieces"], rng)
    colors = rng.sample(COLORS, len(pieces))
    public_pieces = []
    for i, p in enumerate(pieces):
        rot = rng.randrange(4) if cfg["assembly_scramble"] else 0
        public_pieces.append({"cells": rotate_cells(p, rot), "color": colors[i]})
    rng.shuffle(public_pieces)
    data = {
        "width": w,
        "height": h,
        "allow_rotation": cfg["assembly_scramble"],
        "pieces": public_pieces,
    }
    # Çözüm benzersiz değildir; doğrulama yerleşimi kontrol eder.
    return data, None


def check_assembly(data: dict, answer: Any) -> bool:
    """answer: [{"piece": i, "rotation": 0-3, "x": int, "y": int}, ...]"""
    if not isinstance(answer, list):
        return False
    w, h = data["width"], data["height"]
    pieces = data["pieces"]
    used: set[int] = set()
    covered: set[Cell] = set()
    for placement in answer:
        if not isinstance(placement, dict):
            return False
        try:
            i = int(placement["piece"])
            rot = int(placement.get("rotation", 0))
            ox, oy = int(placement["x"]), int(placement["y"])
        except (KeyError, TypeError, ValueError):
            return False
        if i in used or not 0 <= i < len(pieces):
            return False
        if rot % 4 and not data["allow_rotation"]:
            return False
        used.add(i)
        cells = rotate_cells([tuple(c) for c in pieces[i]["cells"]], rot)
        for cx, cy in cells:
            cell = (cx + ox, cy + oy)
            if not (0 <= cell[0] < w and 0 <= cell[1] < h) or cell in covered:
                return False
            covered.add(cell)
    return len(used) == len(pieces) and len(covered) == w * h


# ---------------------------------------------------------------- genel

_GENERATORS = {
    "matrix": _gen_matrix,
    "rotation": _gen_rotation,
    "assembly": _gen_assembly,
}


def generate(band: AgeBand, puzzle_type: str | None = None, rng: random.Random | None = None) -> Puzzle:
    rng = rng or random.Random()
    puzzle_type = puzzle_type or rng.choice(PUZZLE_TYPES)
    data, solution = _GENERATORS[puzzle_type](band, rng)
    return Puzzle(
        id=uuid.uuid4().hex,
        type=puzzle_type,
        band=band,
        data=data,
        solution=solution,
        time_limit=DIFFICULTY[band]["time_limit"],
    )


def check(puzzle: Puzzle, answer: Any) -> bool:
    if puzzle.expired():
        return False
    if puzzle.type == "assembly":
        return check_assembly(puzzle.data, answer)
    try:
        return int(answer) == puzzle.solution
    except (TypeError, ValueError):
        return False
