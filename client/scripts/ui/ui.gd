class_name UI
extends RefCounted
## Ortak tema ve küçük arayüz yardımcıları.

const ACCENT := Color("#5EE6F0")
const ACCENT_2 := Color("#B48CFF")
const GOOD := Color("#4ADE80")
const BAD := Color("#F87171")
const TEXT := Color("#F4F6FF")
const MUTED := Color("#A9B1D6")
const PANEL := Color(1, 1, 1, 0.08)


static func make_theme(large: bool) -> Theme:
	var s := 1.25 if large else 1.0
	var t := Theme.new()
	t.default_font_size = int(30 * s)

	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", int(30 * s))

	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "Button", button_box(ACCENT, state, large))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color.WHITE
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(int(26 * s))
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color("#0B1030"))
	t.set_color("font_hover_color", "Button", Color("#0B1030"))
	t.set_color("font_pressed_color", "Button", Color("#0B1030"))
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font_size("font_size", "Button", int(32 * s))

	var le := StyleBoxFlat.new()
	le.bg_color = Color(1, 1, 1, 0.1)
	le.set_corner_radius_all(int(20 * s))
	le.content_margin_left = 22 * s
	le.content_margin_right = 22 * s
	le.content_margin_top = 16 * s
	le.content_margin_bottom = 16 * s
	le.border_color = Color(1, 1, 1, 0.25)
	le.set_border_width_all(2)
	t.set_stylebox("normal", "LineEdit", le)
	var le_focus := le.duplicate() as StyleBoxFlat
	le_focus.border_color = ACCENT
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_font_size("font_size", "LineEdit", int(30 * s))

	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = PANEL
	panel_box.set_corner_radius_all(int(28 * s))
	panel_box.border_color = Color(1, 1, 1, 0.12)
	panel_box.set_border_width_all(1)
	panel_box.content_margin_left = 24 * s
	panel_box.content_margin_right = 24 * s
	panel_box.content_margin_top = 20 * s
	panel_box.content_margin_bottom = 20 * s
	t.set_stylebox("panel", "PanelContainer", panel_box)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(1, 1, 1, 0.12)
	bar_bg.set_corner_radius_all(10)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ACCENT
	bar_fill.set_corner_radius_all(10)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t


## Düğme arka planı (tema ve renkli düğmeler ortak kullanır).
static func button_box(color: Color, state: String, large: bool) -> StyleBoxFlat:
	var s := 1.25 if large else 1.0
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(26 * s))
	sb.content_margin_left = 28 * s
	sb.content_margin_right = 28 * s
	sb.content_margin_top = 20 * s
	sb.content_margin_bottom = 20 * s
	match state:
		"normal":
			sb.bg_color = color.darkened(0.15)
			sb.shadow_color = Color(0, 0, 0, 0.35)
			sb.shadow_size = 8
			sb.shadow_offset = Vector2(0, 4)
		"hover":
			sb.bg_color = color
		"pressed":
			sb.bg_color = color.darkened(0.35)
		_:
			sb.bg_color = Color(1, 1, 1, 0.12)
	return sb


## Ekrana sığan (gerekirse küçülen), kenar boşluklu dikey sayfa oluşturur ve içteki VBox'u döner.
static func page(parent: Control, separation := 24) -> VBoxContainer:
	var fit := FitBox.new()
	fit.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(fit)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 28)
	fit.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	margin.add_child(box)
	return box


static func label(text: String, size := 0, color := TEXT, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	if size > 0:
		var scale := 1.25 if GameState.is_senior() else 1.0
		l.add_theme_font_size_override("font_size", int(size * scale))
	return l


static func title(text: String) -> Label:
	var l := label(text, 64, TEXT)
	l.add_theme_color_override("font_shadow_color", Color(ACCENT_2, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_outline_size", 12)
	return l


static func button(text: String, on_press: Callable, color := ACCENT) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 96
	b.pressed.connect(on_press)
	if color != ACCENT:
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, button_box(color, state, GameState.is_senior()))
	b.button_down.connect(func() -> void: pop(b, 0.95))
	return b


## Küçük, çerçevesiz bağlantı düğmesi (ikincil eylemler için).
static func link(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", MUTED)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.pressed.connect(on_press)
	return b


## Düğmeleri eşit genişlikte yan yana dizer.
static func row(buttons: Array) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 14)
	for b in buttons:
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(b)
	return r


static func panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(child)
	return p


static func line_edit(placeholder: String, text := "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.custom_minimum_size.y = 84
	return e


## Yaş grubu seçici: dört büyük geçiş düğmesi.
static func age_picker(current: String, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var group := ButtonGroup.new()
	for b in GameState.AGE_BANDS:
		var btn := Button.new()
		btn.text = "%s\n%s" % [b[2], b[1]]
		btn.toggle_mode = true
		btn.button_group = group
		btn.button_pressed = b[0] == current
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 124
		var big := GameState.is_senior()
		btn.add_theme_stylebox_override("normal", button_box(ACCENT, "disabled", big))
		btn.add_theme_stylebox_override("pressed", button_box(ACCENT_2, "hover", big))
		btn.add_theme_stylebox_override("hover_pressed", button_box(ACCENT_2, "hover", big))
		btn.add_theme_color_override("font_color", TEXT)
		var band: String = b[0]
		btn.toggled.connect(func(on: bool) -> void:
			if on:
				on_change.call(band))
		row.add_child(btn)
	return row


## Basılma hissi veren küçük ölçek animasyonu.
static func pop(c: Control, to := 1.08) -> void:
	c.pivot_offset = c.size / 2
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(to, to), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func shake(c: Control) -> void:
	var x := c.position.x
	var tw := c.create_tween()
	for i in 4:
		tw.tween_property(c, "position:x", x + (14 if i % 2 == 0 else -14), 0.05)
	tw.tween_property(c, "position:x", x, 0.05)


static func clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()
