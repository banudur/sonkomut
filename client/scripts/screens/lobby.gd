extends Control
## Lobi: oda kodu, oyuncular, yaş grubu, saklayan seçimi ve başlatma.

var _list: VBoxContainer
var _host_box: VBoxContainer
var _hider_pick: OptionButton
var _hider_ids: Array[String] = []


func _ready() -> void:
	var box := UI.page(self, 22)
	box.add_child(UI.label("ODA KODU", 24, UI.MUTED))
	var code := UI.label(str(GameState.room.get("code", "")), 110, UI.ACCENT)
	code.add_theme_constant_override("shadow_outline_size", 16)
	code.add_theme_color_override("font_shadow_color", Color(UI.ACCENT, 0.4))
	box.add_child(code)
	box.add_child(UI.label("Diğer oyuncular bu kodla katılsın", 24, UI.MUTED))

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	box.add_child(UI.panel(_list))

	box.add_child(UI.label("Yaş grubun", 26, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	box.add_child(UI.age_picker(GameState.age_band, GameState.set_age_band))

	_host_box = VBoxContainer.new()
	_host_box.add_theme_constant_override("separation", 16)
	box.add_child(_host_box)

	box.add_child(UI.button("Odadan Çık", GameState.leave, UI.BAD))

	GameState.room_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if GameState.room.is_empty():
		return
	UI.clear(_list)
	for p in GameState.players():
		var row := HBoxContainer.new()
		var crown := "👑 " if p.get("id") == GameState.room.get("host_id") else ""
		var me := "  (sen)" if p.get("id") == GameState.player_id else ""
		var n := UI.label(crown + str(p.get("name")) + me, 32, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(UI.label(str(p.get("age_label", "")), 26, UI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
		_list.add_child(row)

	UI.clear(_host_box)
	if not GameState.is_host():
		_host_box.add_child(UI.label("Oda kurucusunun oyunu başlatması bekleniyor...", 28, UI.MUTED))
		return
	_host_box.add_child(UI.label("Kim saklayacak?", 26, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	_hider_pick = OptionButton.new()
	_hider_pick.custom_minimum_size.y = 84
	_hider_ids = [""]
	_hider_pick.add_item("🎲 Rastgele")
	for p in GameState.players():
		_hider_ids.append(str(p.get("id")))
		_hider_pick.add_item(str(p.get("name")))
	_host_box.add_child(_hider_pick)
	var start := UI.button("Oyunu Başlat", _start, UI.GOOD)
	start.disabled = GameState.players().size() < 2
	_host_box.add_child(start)
	if start.disabled:
		_host_box.add_child(UI.label("Başlamak için en az 2 oyuncu gerekli.", 24, UI.MUTED))


func _start() -> void:
	var msg := {"type": "start_game"}
	var hider := _hider_ids[_hider_pick.selected]
	if hider != "":
		msg["hider_id"] = hider
	Net.send(msg)
