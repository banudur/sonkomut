extends Control
## Saklayan: nesneyi 1-3 açıdan tara, AI'ın tanımasını onayla.

const MAX_SHOTS := 3

var _camera: CameraView
var _status: Label
var _thumbs: HBoxContainer
var _shots: Array[String] = []
var _actions: VBoxContainer
var _busy := false


func _ready() -> void:
	var box := UI.page(self, 18)
	box.add_child(UI.label("SAKLAYAN SENSİN", 24, UI.ACCENT))
	box.add_child(UI.label("Ebeler bakmasın! Bir nesne seç ve farklı açılardan 1-3 fotoğraf çek.", 28))
	_camera = CameraView.new()
	_camera.status_changed.connect(_on_camera_status)
	box.add_child(_camera)
	_status = UI.label("", 26, UI.MUTED)
	box.add_child(_status)
	_thumbs = HBoxContainer.new()
	_thumbs.alignment = BoxContainer.ALIGNMENT_CENTER
	_thumbs.add_theme_constant_override("separation", 12)
	box.add_child(_thumbs)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 14)
	box.add_child(_actions)
	GameState.event.connect(_on_event)
	_show_capture_actions()


func _on_camera_status(text: String) -> void:
	if text != "":
		_status.text = text


func _show_capture_actions() -> void:
	UI.clear(_actions)
	var shoot := UI.button("📸 Fotoğraf Çek (%d/%d)" % [_shots.size(), MAX_SHOTS], _shoot)
	shoot.disabled = _shots.size() >= MAX_SHOTS
	_actions.add_child(shoot)
	if _shots.size() > 0:
		_actions.add_child(UI.button("Gönder ve Tanıt", _submit, UI.GOOD))
		_actions.add_child(UI.button("Baştan Başla", _reset, UI.BAD))
	_actions.add_child(UI.button("Dosyadan Görüntü Seç (test)", _camera.open_file_picker, UI.ACCENT_2))


func _shoot() -> void:
	if _busy:
		return
	var b64: String = await _camera.capture_base64()
	if b64.is_empty():
		_status.text = "Görüntü alınamadı. Kamerayı kontrol et."
		return
	_shots.append(b64)
	var img := Image.new()
	if img.load_jpg_from_buffer(Marshalls.base64_to_raw(b64)) == OK:
		var rect := TextureRect.new()
		rect.texture = ImageTexture.create_from_image(img)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.custom_minimum_size = Vector2(130, 170)
		_thumbs.add_child(rect)
		UI.pop(rect, 1.15)
	_status.text = "Güzel! Bir açı daha çekebilir ya da gönderebilirsin."
	_show_capture_actions()


func _reset() -> void:
	_shots.clear()
	UI.clear(_thumbs)
	_status.text = ""
	_show_capture_actions()


func _submit() -> void:
	_busy = true
	UI.clear(_actions)
	Net.send({"type": "hider_submit", "images": _shots})


func _on_event(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"busy":
			_status.text = "⏳ " + str(msg.get("message", ""))
			_camera.set_tint(UI.ACCENT_2)
		"identify_result":
			_busy = false
			_camera.set_tint(UI.ACCENT)
			if msg.get("valid", false):
				_ask_confirm(str(msg.get("summary", "")))
			else:
				_reset()
				_status.text = str(msg.get("message", "Nesne tanınamadı."))
		"error":
			# AI hatası vb. — tekrar denemeye izin ver
			_busy = false
			_camera.set_tint(UI.ACCENT)
			_show_capture_actions()


func _ask_confirm(summary: String) -> void:
	_status.text = ""
	UI.clear(_actions)
	var card := VBoxContainer.new()
	card.add_child(UI.label("Yapay zekâ şunu gördü:", 26, UI.MUTED))
	var name_label := UI.label(summary, 46, UI.ACCENT)
	card.add_child(name_label)
	card.add_child(UI.label("Doğru mu? Onaylarsan ipuçları hazırlanır ve arama başlar.", 24, UI.MUTED))
	_actions.add_child(UI.panel(card))
	UI.pop(name_label, 1.2)
	_actions.add_child(UI.button("Evet, bu!", _confirm_yes, UI.GOOD))
	_actions.add_child(UI.button("Hayır, tekrar tara", _confirm_no, UI.BAD))


func _confirm_yes() -> void:
	UI.clear(_actions)
	Net.send({"type": "hider_confirm", "accept": true})


func _confirm_no() -> void:
	Net.send({"type": "hider_confirm", "accept": false})
	_reset()
