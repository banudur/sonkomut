"""WebSocket sunucusu.

Çalıştırma:  uvicorn app.main:app --host 0.0.0.0 --port 8000
İstemci:     ws://<sunucu>:8000/ws

Tüm mesajlar JSON metindir ve bir "type" alanı taşır (bkz. docs/protocol.md).
"""

from __future__ import annotations

import json
import logging
from typing import Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect

from .ai import make_vision
from .game import GameError, Lobby, Player, Room
from .models import AgeBand

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("sonkomut")

MAX_MESSAGE_BYTES = 2_000_000

app = FastAPI(title="Saklı Nesne")
lobby = Lobby(make_vision())


@app.get("/health")
async def health() -> dict[str, Any]:
    return {"ok": True, "rooms": len(lobby.rooms)}


def _band(value: Any) -> AgeBand:
    try:
        return AgeBand(value)
    except ValueError as e:
        raise GameError("Geçersiz yaş grubu.") from e


async def handle(room: Room | None, player: Player | None, msg: dict[str, Any], ws_send) -> tuple[Room | None, Player | None]:
    t = msg.get("type")

    if t in ("create_room", "join_room"):
        if room is not None:
            raise GameError("Zaten bir odadasın.")
        room = lobby.create_room() if t == "create_room" else lobby.get(msg.get("code", ""))
        try:
            player = await room.add_player(msg.get("name", ""), _band(msg.get("age_band", "adult")), ws_send)
        except GameError:
            lobby.cleanup(room)
            raise
        return room, player

    if room is None or player is None:
        raise GameError("Önce bir odaya katıl.")
    pid = player.id

    if t == "set_age_band":
        await room.set_age_band(pid, _band(msg.get("age_band")))
    elif t == "start_game":
        await room.start(pid, msg.get("hider_id"))
    elif t == "back_to_lobby":
        await room.back_to_lobby(pid)
    elif t == "hider_submit":
        await room.hider_submit(pid, msg.get("images"))
    elif t == "hider_confirm":
        await room.hider_confirm(pid, bool(msg.get("accept")), msg.get("name"), msg.get("color"))
    elif t == "hint_request":
        await room.hint_request(pid)
    elif t == "puzzle_answer":
        await room.puzzle_answer(pid, str(msg.get("puzzle_id", "")), msg.get("answer"))
    elif t == "seeker_scan":
        await room.seeker_scan(pid, msg.get("image"))
    elif t == "ping":
        await ws_send({"type": "pong"})
    else:
        raise GameError(f"Bilinmeyen mesaj: {t}")
    return room, player


@app.websocket("/ws")
async def ws_endpoint(ws: WebSocket) -> None:
    await ws.accept()

    async def send(msg: dict[str, Any]) -> None:
        await ws.send_text(json.dumps(msg, ensure_ascii=False))

    room: Room | None = None
    player: Player | None = None
    try:
        while True:
            raw = await ws.receive_text()
            if len(raw) > MAX_MESSAGE_BYTES:
                await send({"type": "error", "message": "Mesaj çok büyük."})
                continue
            try:
                msg = json.loads(raw)
                if not isinstance(msg, dict):
                    raise ValueError
            except ValueError:
                await send({"type": "error", "message": "Geçersiz mesaj."})
                continue
            try:
                room, player = await handle(room, player, msg, send)
            except GameError as e:
                await send({"type": "error", "message": str(e), "for": msg.get("type")})
    except WebSocketDisconnect:
        pass
    finally:
        if room and player:
            await room.remove_player(player.id)
            lobby.cleanup(room)
