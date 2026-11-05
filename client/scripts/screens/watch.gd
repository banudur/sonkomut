extends Control
## Saklayan, arama sürerken ebelerin ilerlemesini izler.

var _list: VBoxContainer
var _timer: Label
var _start := 0.0


func _ready() -> void:
	_start = Time.get_ticks_msec() / 1000.0
	var box := UI.page(self, 22)
	box.add_child(UI.label("ARAMA BAŞLADI", 24, UI.ACCENT))
	box.add_child(UI.title("Ebeler arıyor!"))
	_timer = UI.label("00:00", 80, UI.ACCENT)
	box.add_child(_timer)
	box.add_child(UI.label("Telefonunu sakla, nesneye bakarak ipucu verme 🤫", 28, UI.MUTED))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	box.add_child(UI.panel(_list))
	if GameState.is_host():
		box.add_child(UI.button("Turu İptal Et", func() -> void: Net.send({"type": "back_to_lobby"}), UI.BAD))
	GameState.room_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	var t := int(Time.get_ticks_msec() / 1000.0 - _start)
	_timer.text = "%02d:%02d" % [floori(t / 60.0), t % 60]


func _refresh() -> void:
	UI.clear(_list)
	for p in GameState.players():
		if p.get("id") == GameState.player_id:
			continue
		var row := HBoxContainer.new()
		var n := UI.label(str(p.get("name")), 32, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		var h := int(p.get("hints_unlocked", 0))
		var progress := UI.label("💡".repeat(h) + "○".repeat(3 - h), 30, UI.ACCENT_2, HORIZONTAL_ALIGNMENT_RIGHT)
		progress.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(progress)
		_list.add_child(row)
