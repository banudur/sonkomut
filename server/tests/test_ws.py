import os

os.environ["AI_MODE"] = "fake"

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


def recv_until(ws, type_):
    while True:
        m = ws.receive_json()
        if m["type"] == type_:
            return m


def test_websocket_round():
    client = TestClient(app)
    with client.websocket_connect("/ws") as host, client.websocket_connect("/ws") as seeker:
        host.send_json({"type": "create_room", "name": "Ayşe", "age_band": "adult"})
        welcome = recv_until(host, "welcome")
        code = welcome["code"]

        seeker.send_json({"type": "join_room", "code": code.lower(), "name": "Can", "age_band": "child"})
        sid = recv_until(seeker, "welcome")["player_id"]

        host.send_json({"type": "start_game", "hider_id": welcome["player_id"]})
        assert recv_until(host, "room_state")["phase"] in ("lobby", "hiding")
        host.send_json({"type": "hider_submit", "images": ["IMG"]})
        assert recv_until(host, "identify_result")["valid"]
        host.send_json({"type": "hider_confirm", "accept": True})
        while recv_until(seeker, "room_state")["phase"] != "seeking":
            pass

        seeker.send_json({"type": "hint_request"})
        pz = recv_until(seeker, "puzzle")
        assert pz["puzzle_type"] in ("matrix", "rotation", "assembly")

        seeker.send_json({"type": "seeker_scan", "image": "IMG"})
        over = recv_until(seeker, "game_over")
        assert over["winner_id"] == sid

        seeker.send_json({"type": "bilinmeyen"})
        assert recv_until(seeker, "error")["message"].startswith("Bilinmeyen")


def test_bad_room_code():
    client = TestClient(app)
    with client.websocket_connect("/ws") as ws:
        ws.send_json({"type": "join_room", "code": "ZZZZ", "name": "x", "age_band": "adult"})
        assert recv_until(ws, "error")["message"] == "Oda bulunamadı."
        ws.send_text("{bozuk")
        assert recv_until(ws, "error")["message"] == "Geçersiz mesaj."
