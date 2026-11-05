extends Control
## Ekran yönlendirici: oda durumuna göre doğru ekranı gösterir.

const SCREENS := {
	"title": preload("res://scripts/screens/title.gd"),
	"menu": preload("res://scripts/screens/menu.gd"),
	"lobby": preload("res://scripts/screens/lobby.gd"),
	"hide": preload("res://scripts/screens/hide.gd"),
	"wait_hide": preload("res://scripts/screens/wait_hide.gd"),
	"seek": preload("res://scripts/screens/seek.gd"),
	"watch": preload("res://scripts/screens/watch.gd"),
	"result": preload("res://scripts/screens/result.gd"),
}

var _current: Control
var _current_key := ""
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/background.gdshader")
	bg.material = mat
	add_child(bg)

	_build_toast()
	_apply_theme()
	GameState.room_changed.connect(_route)
	GameState.settings_changed.connect(_apply_theme)
	GameState.error.connect(show_toast)
	_route()


func _apply_theme() -> void:
	theme = UI.make_theme(GameState.is_senior())


func _screen_key() -> String:
	if GameState.room.is_empty():
		return "menu" if GameState.in_menu else "title"
	match GameState.phase():
		"hiding":
			return "hide" if GameState.is_hider() else "wait_hide"
		"seeking":
			return "watch" if GameState.is_hider() else "seek"
		"finished":
			return "result"
	return "lobby"


func _route() -> void:
	var key := _screen_key()
	if key == _current_key:
		return
	_current_key = key
	if key in ["title", "menu", "lobby", "result"]:
		Music.play_theme()
	else:
		Music.fade_out()
	if _current:
		_current.queue_free()
	_current = (SCREENS[key] as GDScript).new()
	_current.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_current)
	move_child(_toast, -1)
	_current.modulate.a = 0.0
	create_tween().tween_property(_current, "modulate:a", 1.0, 0.25)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_left = 30
	_toast.offset_right = -30
	_toast.offset_top = -190
	_toast.offset_bottom = -60
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.18, 0.95)
	sb.border_color = UI.ACCENT_2
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	_toast.add_theme_stylebox_override("panel", sb)
	_toast_label = UI.label("", 28)
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.modulate.a = 0.0
	add_child(_toast)


func show_toast(text: String) -> void:
	if text.is_empty():
		return
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(2.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
