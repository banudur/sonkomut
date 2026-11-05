import random

import pytest

from app import puzzles
from app.models import AgeBand


@pytest.mark.parametrize("band", list(AgeBand))
@pytest.mark.parametrize("ptype", ["matrix", "rotation"])
def test_choice_puzzles_have_unique_correct_option(band, ptype):
    for seed in range(200):
        pz = puzzles.generate(band, ptype, random.Random(seed))
        opts = pz.data["options"]
        assert len(opts) == len({str(sorted(o.items())) for o in opts}), "seçenekler tekrar etmemeli"
        assert 0 <= pz.solution < len(opts)
        assert puzzles.check(pz, pz.solution)
        assert not puzzles.check(pz, (pz.solution + 1) % len(opts))
        assert "solution" not in pz.public() and "solution" not in pz.public()["data"]


@pytest.mark.parametrize("band", list(AgeBand))
def test_matrix_is_unambiguous(band):
    """Görünen 8 hücreyle tutarlı her kural aynı cevabı vermeli ve bu doğru seçenek olmalı."""
    predictors = {
        "row": lambda r, c: r,
        "col": lambda r, c: c,
        "latin": lambda r, c: (r + c) % 3,
        "anti": lambda r, c: (r - c) % 3,
        "const": lambda r, c: 0,
    }
    for seed in range(200):
        pz = puzzles.generate(band, "matrix", random.Random(seed))
        cells = pz.data["cells"]
        answer = pz.data["options"][pz.solution]
        for attr in ("shape", "color", "count"):
            predictions = set()
            for f in predictors.values():
                mapping, ok = {}, True
                for i, cell in enumerate(cells):
                    k = f(i // 3, i % 3)
                    if mapping.setdefault(k, cell[attr]) != cell[attr]:
                        ok = False
                        break
                key = f(2, 2)
                if ok and key in mapping:
                    predictions.add(mapping[key])
            assert predictions == {answer[attr]}, (seed, attr, predictions)


@pytest.mark.parametrize("band", list(AgeBand))
def test_assembly_is_solvable_and_checked(band):
    rng = random.Random(7)
    for _ in range(50):
        pz = puzzles.generate(band, "assembly", rng)
        data = pz.data
        # Kaba kuvvet çözücü: üretilen bulmaca gerçekten çözülebilir olmalı
        solution = _solve(data)
        assert solution is not None
        assert puzzles.check(pz, solution)
        # Bir parçayı eksik bırakmak geçersiz
        assert not puzzles.check(pz, solution[:-1])


def test_assembly_rejects_overlap_and_out_of_bounds():
    data = {"width": 2, "height": 1, "allow_rotation": False,
            "pieces": [{"cells": [(0, 0)], "color": "#fff"}, {"cells": [(0, 0)], "color": "#000"}]}
    assert puzzles.check_assembly(data, [{"piece": 0, "x": 0, "y": 0}, {"piece": 1, "x": 1, "y": 0}])
    assert not puzzles.check_assembly(data, [{"piece": 0, "x": 0, "y": 0}, {"piece": 1, "x": 0, "y": 0}])
    assert not puzzles.check_assembly(data, [{"piece": 0, "x": 0, "y": 0}, {"piece": 1, "x": 2, "y": 0}])
    assert not puzzles.check_assembly(data, [{"piece": 0, "x": 0, "y": 0}, {"piece": 0, "x": 1, "y": 0}])
    assert not puzzles.check_assembly(data, "çöp")
    assert not puzzles.check_assembly(data, [{"piece": 0, "rotation": 1, "x": 0, "y": 0},
                                             {"piece": 1, "x": 1, "y": 0}])


def test_rotate_cells():
    l_shape = [(0, 0), (0, 1), (1, 1)]
    assert puzzles.rotate_cells(l_shape, 4) == sorted(l_shape)
    assert puzzles.rotate_cells(puzzles.rotate_cells(l_shape, 1), 3) == sorted(l_shape)


def test_time_limit_expiry():
    pz = puzzles.generate(AgeBand.ADULT, "matrix", random.Random(1))
    assert not pz.expired()
    pz.created_at -= pz.time_limit + puzzles.TIME_GRACE_SECONDS + 1
    assert pz.expired()
    assert not puzzles.check(pz, pz.solution)


def _solve(data):
    w, h = data["width"], data["height"]
    pieces = data["pieces"]
    rots = range(4) if data["allow_rotation"] else [0]

    def rec(i, covered, acc):
        if i == len(pieces):
            return acc if len(covered) == w * h else None
        for r in rots:
            cells = puzzles.rotate_cells([tuple(c) for c in pieces[i]["cells"]], r)
            for ox in range(w):
                for oy in range(h):
                    placed = {(x + ox, y + oy) for x, y in cells}
                    if all(0 <= x < w and 0 <= y < h for x, y in placed) and not placed & covered:
                        res = rec(i + 1, covered | placed, acc + [{"piece": i, "rotation": r, "x": ox, "y": oy}])
                        if res:
                            return res
        return None

    return rec(0, set(), [])
