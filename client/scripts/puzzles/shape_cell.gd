class_name ShapeCell
extends Control
## Bir matris/dizi hücresi: arka plan kartı + şekil(ler). İsteğe bağlı tıklanabilir.

signal tapped

var data: Dictionary = {}
var question := false
var selectable := false
var highlight := false:
	set(v):
		highlight = v
		queue_redraw()

var _t := 0.0


func _init(cell_data: Dictionary = {}, is_question := false, is_selectable := false) -> void:
	data = cell_data
	question = is_question
	selectable = is_selectable
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if question:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size).grow(-4)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(22)
	sb.bg_color = Color(1, 1, 1, 0.92) if not question else Color(1, 1, 1, 0.12)
	if highlight:
		sb.border_color = UI.ACCENT
		sb.set_border_width_all(6)
	elif question:
		sb.border_color = Color(UI.ACCENT, 0.5 + 0.5 * sin(_t * 4.0))
		sb.set_border_width_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 6
	draw_style_box(sb, rect)
	if question:
		var font := ThemeDB.fallback_font
		var fs := int(rect.size.y * 0.55)
		draw_string(font, Vector2(rect.position.x, rect.get_center().y + fs * 0.35), "?",
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, UI.ACCENT)
		return
	if data.is_empty():
		return
	ShapeArt.draw_group(self, str(data.get("shape", "circle")), rect.grow(-10),
		Color(str(data.get("color", "#ffffff"))), int(data.get("count", 1)), float(data.get("angle", 0.0)))


func _gui_input(event: InputEvent) -> void:
	if not selectable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		highlight = true
		UI.pop(self)
		tapped.emit()
