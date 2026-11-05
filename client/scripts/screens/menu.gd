extends Control
## Başlangıç: isim, yaş grubu, oda kur / katıl.

var _name: LineEdit
var _code: LineEdit
var _server: LineEdit


func _ready() -> void:
	var box := UI.page(self, 26)
	var t := UI.title("Saklı Nesne")
	box.add_child(t)
	box.add_child(UI.label("Biri saklar, ebeler arar. İpucu için zekâ oyununu çöz!", 28, UI.MUTED))
	_float(t)

	box.add_child(_spacer(10))
	box.add_child(UI.label("Adın", 26, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	_name = UI.line_edit("Örn. Deniz", GameState.player_name)
	_name.max_length = 20
	box.add_child(_name)

	box.add_child(UI.label("Yaş grubun (ipuçları ve bulmacalar buna göre)", 26, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(UI.age_picker(GameState.age_band, GameState.set_age_band))

	box.add_child(_spacer(10))
	box.add_child(UI.button("Oda Kur", _create))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_code = UI.line_edit("Oda kodu")
	_code.max_length = 4
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.text_changed.connect(func(s: String) -> void:
		var up := s.to_upper()
		if up != s:
			_code.text = up
			_code.caret_column = up.length())
	row.add_child(_code)
	var join := UI.button("Katıl", _join, UI.ACCENT_2)
	join.custom_minimum_size.x = 220
	row.add_child(join)
	box.add_child(row)

	box.add_child(_spacer(20))
	box.add_child(UI.label("Sunucu adresi", 22, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	_server = UI.line_edit("ws://192.168.1.10:8000/ws", GameState.server_url)
	box.add_child(_server)

	box.add_child(_spacer(10))
	var how := UI.label(
		"Nasıl oynanır?\n"
		+ "1. Saklayan, ebeler bakmazken evdeki bir nesneyi 2-3 açıdan tarar.\n"
		+ "2. Yapay zekâ nesneyi tanır ve yaş grubuna göre ipuçları hazırlar.\n"
		+ "3. Ebeler evi dolaşıp şüphelendikleri nesneyi tarar.\n"
		+ "4. İpucu isteyen önce kısa bir zekâ oyununu çözer.\n"
		+ "5. Doğru nesneyi ilk tarayan kazanır!", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(UI.panel(how))


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


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _float(c: Control) -> void:
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "modulate", Color(1, 1, 1, 1), 1.2)
	tw.tween_property(c, "modulate", Color(0.85, 0.95, 1, 1), 1.2)
