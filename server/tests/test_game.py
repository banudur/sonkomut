import asyncio

import pytest

from app import puzzles
from app.ai import AIError, FakeVision
from app.game import GameError, Lobby, Phase
from app.models import AgeBand


class Inbox:
    def __init__(self):
        self.msgs = []

    async def __call__(self, msg):
        self.msgs.append(msg)

    def last(self, type_):
        return next(m for m in reversed(self.msgs) if m["type"] == type_)

    def all(self, type_):
        return [m for m in self.msgs if m["type"] == type_]


class Clock:
    def __init__(self):
        self.t = 1000.0

    def __call__(self):
        return self.t


def run(coro):
    return asyncio.run(coro)


async def _setup(n_seekers=2, vision=None):
    lobby = Lobby(vision or FakeVision())
    room = lobby.create_room()
    room.clock = Clock()
    hider_in = Inbox()
    hider = await room.add_player("Ayşe", AgeBand.ADULT, hider_in)
    seekers = []
    for i, band in enumerate([AgeBand.CHILD, AgeBand.SENIOR, AgeBand.TEEN][:n_seekers]):
        inbox = Inbox()
        seekers.append((await room.add_player(f"Ebe{i}", band, inbox), inbox))
    return room, hider, hider_in, seekers


async def _to_seeking(room, hider):
    await room.start(hider.id, hider.id)
    await room.hider_submit(hider.id, ["VAZO1", "VAZO2"])
    await room.hider_confirm(hider.id, True)


def test_full_round_first_correct_scan_wins():
    async def go():
        room, hider, hider_in, [(e0, in0), (e1, in1)] = await _setup()
        assert room.host_id == hider.id
        await room.start(hider.id, hider.id)
        assert room.phase == Phase.HIDING

        await room.hider_submit(hider.id, ["VAZO1", "VAZO2"])
        res = hider_in.last("identify_result")
        assert res["valid"] and res["summary"] == "mavi seramik vazo"
        # Ebeler nesneyi görmemeli
        assert not in0.all("identify_result")

        await room.hider_confirm(hider.id, True)
        assert room.phase == Phase.SEEKING
        # Oyun sırasında durum mesajı nesneyi ele vermemeli
        assert "object" not in in0.last("room_state")

        await room.seeker_scan(e0.id, "BASKA_BIR_SEY")
        assert in0.last("scan_result")["match"] is False
        await room.seeker_scan(e1.id, "VAZO2")
        assert in1.last("scan_result")["match"] is True
        assert room.phase == Phase.FINISHED and room.winner_id == e1.id
        over = in0.last("game_over")
        assert over["winner_name"] == "Ebe1" and over["object"] == "mavi seramik vazo"
        assert room.reference_images == []  # gizlilik
    run(go())


def test_permissions():
    async def go():
        room, hider, _, [(e0, _), _] = await _setup()
        with pytest.raises(GameError):
            await room.start(e0.id, None)  # host değil
        await room.start(hider.id, hider.id)
        with pytest.raises(GameError):
            await room.hider_submit(e0.id, ["X"])  # saklayan değil
        with pytest.raises(GameError):
            await room.seeker_scan(e0.id, "X")  # arama başlamadı
        with pytest.raises(GameError):
            await room.hider_submit(hider.id, [])
        with pytest.raises(GameError):
            await room.hider_submit(hider.id, ["a", "b", "c", "d"])
        await room.hider_submit(hider.id, ["VAZO1"])
        await room.hider_confirm(hider.id, True)
        with pytest.raises(GameError):
            await room.seeker_scan(hider.id, "VAZO1")  # saklayan arayamaz
        with pytest.raises(GameError):
            await room.hint_request(hider.id)
    run(go())


def test_scan_cooldown():
    async def go():
        room, hider, _, [(e0, _), _] = await _setup()
        await _to_seeking(room, hider)
        await room.seeker_scan(e0.id, "X")
        with pytest.raises(GameError):
            await room.seeker_scan(e0.id, "Y")
        room.clock.t += 10
        await room.seeker_scan(e0.id, "Y")
    run(go())


def test_hint_flow_by_age_band():
    async def go():
        room, hider, _, [(child, cin), (senior, sin)] = await _setup()
        await _to_seeking(room, hider)

        await room.hint_request(child.id)
        pz_msg = cin.last("puzzle")
        assert "solution" not in pz_msg
        pz = child.puzzle
        assert pz.band == AgeBand.CHILD and pz.time_limit == 0

        # yanlış cevap -> bekleme süresi
        wrong = [] if pz.type == "assembly" else (pz.solution + 1) % len(pz.data["options"])
        await room.puzzle_answer(child.id, pz.id, wrong)
        assert cin.last("puzzle_result")["correct"] is False
        with pytest.raises(GameError):
            await room.hint_request(child.id)
        room.clock.t += 60

        # doğru cevap -> çocuğa özel ipucu
        for level in range(1, 4):
            await room.hint_request(child.id)
            pz = child.puzzle
            await room.puzzle_answer(child.id, pz.id, _solution(pz))
            res = cin.last("puzzle_result")
            assert res["correct"] and res["hint"]["level"] == level
        hints = [m["hint"]["text"] for m in cin.all("puzzle_result") if m["correct"]]
        assert hints[0] == "Çiçekler bende su içer!"
        with pytest.raises(GameError):
            await room.hint_request(child.id)  # hepsi açıldı

        await room.hint_request(senior.id)
        await room.puzzle_answer(senior.id, senior.puzzle.id, _solution(senior.puzzle))
        assert sin.last("puzzle_result")["hint"]["text"] == "Bayramda gelen çiçekler bende durur."
    run(go())


def test_stale_puzzle_rejected():
    async def go():
        room, hider, _, [(e0, _), _] = await _setup()
        await _to_seeking(room, hider)
        await room.hint_request(e0.id)
        with pytest.raises(GameError):
            await room.puzzle_answer(e0.id, "eski-id", 0)
    run(go())


def test_earlier_scan_wins_even_if_ai_answers_later():
    """Ebe A önce tarar ama AI yavaş cevap verir; B sonra tarar, hızlı cevap gelir. A kazanmalı."""

    class SlowFirst(FakeVision):
        def __init__(self):
            self.gates = {}

        async def verify(self, profile, refs, cand):
            if cand in self.gates:
                await self.gates[cand].wait()
            return await super().verify(profile, refs, cand)

    async def go():
        vision = SlowFirst()
        room, hider, _, [(a, ain), (b, bin_)] = await _setup(vision=vision)
        await _to_seeking(room, hider)
        vision.gates["VAZO1"] = asyncio.Event()
        task_a = asyncio.create_task(room.seeker_scan(a.id, "VAZO1"))
        await asyncio.sleep(0)
        room.clock.t += 1
        await room.seeker_scan(b.id, "VAZO2")
        assert room.phase == Phase.SEEKING  # A'nın sonucu bekleniyor
        vision.gates["VAZO1"].set()
        await task_a
        assert room.phase == Phase.FINISHED and room.winner_id == a.id
    run(go())


def test_ai_error_is_reported_and_scan_not_penalized():
    class Broken(FakeVision):
        async def verify(self, *a):
            raise AIError("AI şu an yoğun")

    async def go():
        room, hider, _, [(e0, _), _] = await _setup(vision=Broken())
        await _to_seeking(room, hider)
        with pytest.raises(GameError, match="yoğun"):
            await room.seeker_scan(e0.id, "VAZO1")
        with pytest.raises(GameError, match="yoğun"):
            await room.seeker_scan(e0.id, "VAZO1")  # bekleme cezası yok
    run(go())


def test_rejected_object_and_hider_leaving():
    class Rejects(FakeVision):
        async def identify(self, images):
            p = await super().identify(images)
            return p.model_copy(update={"valid": False, "rejection_reason": "Görüntüde insan var"})

    async def go():
        room, hider, hider_in, [(e0, in0), _] = await _setup(vision=Rejects())
        await room.start(hider.id, hider.id)
        await room.hider_submit(hider.id, ["X"])
        res = hider_in.last("identify_result")
        assert res["valid"] is False and "insan" in res["message"]
        with pytest.raises(GameError):
            await room.hider_confirm(hider.id, True)
        await room.remove_player(hider.id)
        assert room.phase == Phase.LOBBY and room.host_id == e0.id
    run(go())


def test_join_after_start_rejected():
    async def go():
        room, hider, _, _ = await _setup()
        await room.start(hider.id, None)
        with pytest.raises(GameError):
            await room.add_player("Geç", AgeBand.ADULT, Inbox())
    run(go())


def _solution(pz):
    if pz.type != "assembly":
        return pz.solution
    from tests.test_puzzles import _solve
    return _solve(pz.data)


def test_back_to_lobby_after_round():
    async def go():
        room, hider, _, [(e0, in0), _] = await _setup()
        await _to_seeking(room, hider)
        await room.seeker_scan(e0.id, "VAZO1")
        assert room.phase == Phase.FINISHED
        with pytest.raises(GameError):
            await room.back_to_lobby(e0.id)
        await room.back_to_lobby(hider.id)
        assert room.phase == Phase.LOBBY and room.winner_id is None
        assert all(p.hints_unlocked == 0 for p in room.players.values())
        await room.set_age_band(e0.id, AgeBand.TEEN)
        await room.start(hider.id, e0.id)  # yeni turda başka saklayan
        assert room.hider_id == e0.id
    run(go())
