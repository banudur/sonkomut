extends Control
## Oyuncu bilgileri: isim, yaş grubu, oda kur / katıl, bağlantı ayarı.

const AVATAR_COLORS := ["#F87171", "#FBBF24", "#4ADE80", "#5EE6F0", "#B48CFF", "#F472B6"]

var _name: LineEdit
var _code: LineEdit
var _server: LineEdit
var _avatar: Label
var _avatar_bg: PanelContainer
var _server_box: VBoxContainer
var _connecting: Control


class Spinner extends Control:
	var _a := 0.0

	func _process(delta: float) -> void:
		_a += delta * 5.0
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 8.0
		draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.15), 10.0, true)
		draw_arc(c, r, _a, _a + 1.8, 32, UI.ACCENT, 10.0, true)


func _ready() -> void:
	var loop := AttractLoop.new()
	loop.show_captions = false
	loop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(loop)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.12, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var box := UI.page(self, 22)

	var top := HBoxContainer.new()
	var back := Button.new()
	back.text = "‹ Geri"
	back.flat = true
	back.add_theme_font_size_override("font_size", 30)
	back.add_theme_color_override("font_color", UI.MUTED)
	back.pressed.connect(GameState.open_title)
	top.add_child(back)
	box.add_child(top)

	box.add_child(UI.title("Hazır mısın?"))

	# --- isim + avatar
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 20)
	_avatar_bg = PanelContainer.new()
	_avatar_bg.custom_minimum_size = Vector2(110, 110)
	_avatar = UI.label("?", 56, Color("#0B1030"))
	_avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar_bg.add_child(_avatar)
	who.add_child(_avatar_bg)
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_child(UI.label("Adın", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	_name = UI.line_edit("Örn. Deniz", GameState.player_name)
	_name.max_length = 20
	_name.text_changed.connect(func(_s: String) -> void: _update_avatar())
	name_col.add_child(_name)
	who.add_child(name_col)
	box.add_child(UI.panel(who))
	_update_avatar()

	# --- yaş
	var age := VBoxContainer.new()
	age.add_theme_constant_override("separation", 12)
	age.add_child(UI.label("Yaş grubun — ipuçları ve bulmacalar buna göre ayarlanır", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	age.add_child(UI.age_picker(GameState.age_band, GameState.set_age_band))
	box.add_child(UI.panel(age))

	# --- oda
	var play := VBoxContainer.new()
	play.add_theme_constant_override("separation", 16)
	var create := UI.button("✨ Yeni Oda Kur", _create, UI.GOOD)
	create.custom_minimum_size.y = 110
	play.add_child(create)
	var or_label := UI.label("ya da arkadaşının odasına katıl", 24, UI.MUTED)
	play.add_child(or_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_code = UI.line_edit("KOD")
	_code.max_length = 4
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.add_theme_font_size_override("font_size", 40)
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.text_changed.connect(_on_code_changed)
	_code.text_submitted.connect(func(_s: String) -> void: _join())
	row.add_child(_code)
	var join := UI.button("Katıl", _join, UI.ACCENT_2)
	join.custom_minimum_size.x = 220
	row.add_child(join)
	play.add_child(row)
	box.add_child(UI.panel(play))

	# --- bağlantı ayarı (gizli)
	var adv := Button.new()
	adv.text = "⚙ Bağlantı ayarları"
	adv.flat = true
	adv.add_theme_color_override("font_color", UI.MUTED)
	adv.add_theme_font_size_override("font_size", 24)
	box.add_child(adv)
	_server_box = VBoxContainer.new()
	_server_box.visible = false
	_server_box.add_theme_constant_override("separation", 8)
	_server = UI.line_edit(GameState.LOCAL_URL, GameState.server_url)
	_server_box.add_child(_server)
	_server_box.add_child(UI.label(
		"Aynı bilgisayarda: %s\nTelefondan: ws://<bilgisayarın-IP'si>:8000/ws" % GameState.LOCAL_URL,
		22, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(_server_box)
	adv.pressed.connect(func() -> void: _server_box.visible = not _server_box.visible)

	GameState.connecting_changed.connect(_on_connecting)


func _update_avatar() -> void:
	var n := _name.text.strip_edges()
	_avatar.text = n.substr(0, 1).to_upper() if n != "" else "?"
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(55)
	sb.bg_color = Color(AVATAR_COLORS[absi(n.hash()) % AVATAR_COLORS.size()]) if n != "" else Color(1, 1, 1, 0.2)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(4)
	_avatar_bg.add_theme_stylebox_override("panel", sb)


func _on_code_changed(s: String) -> void:
	var up := s.to_upper()
	if up != s:
		_code.text = up
		_code.caret_column = up.length()


func _apply() -> bool:
	GameState.player_name = _name.text.strip_edges()
	GameState.server_url = _server.text.strip_edges()
	if GameState.player_name.is_empty():
		UI.shake(_name)
		GameState.error.emit("Önce adını yaz.")
		return false
	return true


func _create() -> void:
	if _apply():
		GameState.create_room()


func _join() -> void:
	if not _apply():
		return
	if _code.text.strip_edges().length() != 4:
		UI.shake(_code)
		GameState.error.emit("4 harfli oda kodunu yaz.")
		return
	GameState.join_room(_code.text.strip_edges())


func _on_connecting(active: bool) -> void:
	if not active:
		if _connecting:
			_connecting.queue_free()
			_connecting = null
		return
	if _connecting:
		return
	_connecting = Control.new()
	_connecting.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_connecting.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 24)
	var sp := Spinner.new()
	sp.custom_minimum_size = Vector2(120, 120)
	sp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(sp)
	box.add_child(UI.label("Sunucuya bağlanılıyor...", 32))
	box.add_child(UI.label(GameState.server_url, 22, UI.MUTED))
	box.add_child(UI.button("İptal", _cancel_connect, UI.BAD))
	_connecting.add_child(box)
	add_child(_connecting)


func _cancel_connect() -> void:
	GameState.leave()
	_on_connecting(false)
