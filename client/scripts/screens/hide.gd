extends Control
## Saklayan: nesneyi 1-3 açıdan tara, AI'ın tanımasını onayla.

const MAX_SHOTS := 3

var _camera: CameraView
var _status: Label
var _thumbs: HBoxContainer
var _shots: Array[String] = []
var _actions: VBoxContainer
var _busy := false
var _chosen_name := ""
var _chosen_color := ""
var _summary_label: Label
var _name_edit: LineEdit


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
				_ask_confirm(msg)
			else:
				_reset()
				_status.text = str(msg.get("message", "Nesne tanınamadı."))
		"error":
			# AI hatası vb. — tekrar denemeye izin ver
			_busy = false
			_camera.set_tint(UI.ACCENT)
			_show_capture_actions()


func _ask_confirm(msg: Dictionary) -> void:
	_status.text = ""
	UI.clear(_actions)
	_chosen_name = str(msg.get("name", ""))
	_chosen_color = str(msg.get("color", ""))
	var needs_name: bool = msg.get("needs_name", false)

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 14)
	card.add_child(UI.label("Emin olamadım, bu ne?" if needs_name else "Yapay zekâ şunu gördü:", 26, UI.MUTED))
	_summary_label = UI.label("", 46, UI.ACCENT)
	card.add_child(_summary_label)
	_update_summary()
	UI.pop(_summary_label, 1.2)

	card.add_child(UI.label("Yanlışsa doğrusunu seç:", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	card.add_child(_chips(msg.get("alternatives", []), _chosen_name, func(v: String) -> void:
		_chosen_name = v
		_name_edit.text = ""
		_update_summary()))
	_name_edit = UI.line_edit("ya da kendin yaz (ör. kumbara)")
	_name_edit.max_length = 30
	_name_edit.text_changed.connect(func(t: String) -> void:
		_chosen_name = t.strip_edges().to_lower()
		_update_summary())
	card.add_child(_name_edit)
	card.add_child(UI.label("Rengi:", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	card.add_child(_chips(msg.get("colors", []), _chosen_color, func(v: String) -> void:
		_chosen_color = v
		_update_summary()))
	_actions.add_child(UI.panel(card))

	_actions.add_child(UI.button("Tamam, saklandı!", _confirm_yes, UI.GOOD))
	_actions.add_child(UI.button("Tekrar tara", _confirm_no, UI.BAD))


func _update_summary() -> void:
	var text := ("%s %s" % [_chosen_color, _chosen_name]).strip_edges()
	_summary_label.text = text if _chosen_name != "" else "Adını seç ↓"


## Tek seçimli küçük düğmeler (akışlı satır).
func _chips(values: Array, current: String, on_pick: Callable) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	var group := ButtonGroup.new()
	for v in values:
		var value := str(v)
		var b := Button.new()
		b.text = value
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = value == current
		b.custom_minimum_size.y = 64
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_stylebox_override("normal", UI.button_box(UI.ACCENT, "disabled", false))
		b.add_theme_stylebox_override("pressed", UI.button_box(UI.ACCENT_2, "hover", false))
		b.add_theme_stylebox_override("hover_pressed", UI.button_box(UI.ACCENT_2, "hover", false))
		b.add_theme_color_override("font_color", UI.TEXT)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				on_pick.call(value))
		flow.add_child(b)
	return flow


func _confirm_yes() -> void:
	if _chosen_name == "":
		GameState.error.emit("Önce nesnenin adını seç ya da yaz.")
		return
	UI.clear(_actions)
	Net.send({"type": "hider_confirm", "accept": true, "name": _chosen_name, "color": _chosen_color})


func _confirm_no() -> void:
	Net.send({"type": "hider_confirm", "accept": false})
	_reset()
