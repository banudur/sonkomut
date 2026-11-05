extends Control
## Ebe: evi dolaş, şüphelendiğin nesneyi tara. İpucu için bulmaca çöz.

const PuzzleOverlay := preload("res://scripts/puzzles/puzzle_overlay.gd")
const MAX_HINTS := 3

var _camera: CameraView
var _status: Label
var _scan_btn: Button
var _hint_btn: Button
var _hints_box: VBoxContainer
var _rivals: Label
var _overlay: PuzzleOverlay
var _scan_ready_at := 0.0
var _hint_ready_at := 0.0
var _scanning := false


func _ready() -> void:
	var box := UI.page(self, 16)
	box.add_child(UI.label("EBE SENSİN", 24, UI.ACCENT))
	box.add_child(UI.label("Gizli nesneyi bul ve kameraya göster!", 30))
	_camera = CameraView.new()
	_camera.custom_minimum_size.y = 680
	_camera.status_changed.connect(_on_camera_status)
	box.add_child(_camera)
	_status = UI.label("", 28, UI.MUTED)
	box.add_child(_status)

	_scan_btn = UI.button("🔍 Tara", _scan, UI.GOOD)
	_scan_btn.custom_minimum_size.y = 120
	box.add_child(_scan_btn)
	_hint_btn = UI.button("", _ask_hint, UI.ACCENT_2)
	box.add_child(_hint_btn)
	box.add_child(UI.button("Dosyadan Görüntü Seç (test)", _camera.open_file_picker))

	box.add_child(UI.label("İpuçların", 26, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	_hints_box = VBoxContainer.new()
	_hints_box.add_theme_constant_override("separation", 12)
	box.add_child(_hints_box)
	for h in GameState.hints:
		_add_hint_card(h, false)
	_rivals = UI.label("", 24, UI.MUTED)
	box.add_child(_rivals)

	GameState.event.connect(_on_event)
	GameState.room_changed.connect(_refresh_rivals)
	_refresh_rivals()
	_update_buttons()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	_update_buttons()


func _update_buttons() -> void:
	var now := _now()
	if _scanning:
		_scan_btn.disabled = true
		_scan_btn.text = "⏳ Kontrol ediliyor..."
	elif now < _scan_ready_at:
		_scan_btn.disabled = true
		_scan_btn.text = "Bekle %d" % ceili(_scan_ready_at - now)
	else:
		_scan_btn.disabled = false
		_scan_btn.text = "🔍 Tara"

	var left := MAX_HINTS - GameState.hints.size()
	if left <= 0:
		_hint_btn.disabled = true
		_hint_btn.text = "Tüm ipuçları açıldı"
	elif now < _hint_ready_at:
		_hint_btn.disabled = true
		_hint_btn.text = "Yeni bulmaca için %d sn" % ceili(_hint_ready_at - now)
	else:
		_hint_btn.disabled = _overlay != null
		_hint_btn.text = "💡 İpucu Al — bulmaca çöz (%d kaldı)" % left


func _on_camera_status(text: String) -> void:
	if text != "":
		_status.text = text


func _scan() -> void:
	var b64: String = await _camera.capture_base64()
	if b64.is_empty():
		_status.text = "Görüntü alınamadı."
		return
	_scanning = true
	_camera.set_tint(UI.ACCENT_2)
	Net.send({"type": "seeker_scan", "image": b64})


func _ask_hint() -> void:
	Net.send({"type": "hint_request"})
	_hint_btn.disabled = true


func _on_event(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"scan_result":
			_scanning = false
			_scan_ready_at = _now() + float(msg.get("cooldown", 0))
			_status.text = str(msg.get("message", ""))
			if msg.get("match", false):
				_camera.set_tint(UI.GOOD)
			else:
				_camera.set_tint(UI.BAD)
				UI.shake(_camera)
				get_tree().create_timer(1.2).timeout.connect(func() -> void:
					if is_instance_valid(_camera):
						_camera.set_tint(UI.ACCENT))
		"puzzle":
			_open_puzzle(msg)
		"puzzle_result":
			_close_puzzle()
			if msg.get("correct", false):
				var hint: Dictionary = msg.get("hint", {})
				_add_hint_card(str(hint.get("text", "")), true)
				_status.text = "Yeni ipucu açıldı!"
			else:
				_hint_ready_at = _now() + float(msg.get("cooldown", 0))
				_status.text = "Süre doldu!" if msg.get("expired", false) else "Yanlış cevap, biraz bekle."
		"error":
			_scanning = false
			_camera.set_tint(UI.ACCENT)
			if msg.get("for") == "hint_request" or msg.get("for") == "puzzle_answer":
				_close_puzzle()


func _open_puzzle(msg: Dictionary) -> void:
	_close_puzzle()
	_overlay = PuzzleOverlay.new()
	add_child(_overlay)
	_overlay.open(msg)
	_overlay.answered.connect(_on_puzzle_answer)


func _on_puzzle_answer(puzzle_id: String, answer: Variant) -> void:
	Net.send({"type": "puzzle_answer", "puzzle_id": puzzle_id, "answer": answer})


func _close_puzzle() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _add_hint_card(text: String, animate: bool) -> void:
	var n := _hints_box.get_child_count() + 1
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var badge := UI.label(str(n), 40, UI.ACCENT)
	badge.custom_minimum_size.x = 56
	row.add_child(badge)
	var l := UI.label(text, 30, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var card := UI.panel(row)
	_hints_box.add_child(card)
	if animate:
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.4)
		UI.pop(card, 1.06)


func _refresh_rivals() -> void:
	var parts: Array[String] = []
	for p in GameState.players():
		if p.get("id") == GameState.player_id or p.get("id") == GameState.room.get("hider_id"):
			continue
		parts.append("%s: %d ipucu" % [p.get("name"), int(p.get("hints_unlocked", 0))])
	_rivals.text = ("Rakipler — " + ", ".join(PackedStringArray(parts))) if parts.size() > 0 else ""
