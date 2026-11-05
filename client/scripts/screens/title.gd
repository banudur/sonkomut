extends Control
## Giriş ekranı: arkada dönen tanıtım klibi, logo, müzik ve BAŞLAT düğmesi.

var _logo: Control
var _start: Button
var _music_btn: Button
var _help: Control


func _ready() -> void:
	var loop := AttractLoop.new()
	loop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(loop)

	# Üst ve alt karartma: yazılar okunur, ortadaki klip görünür kalır.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.22, 0.34, 0.68, 0.8, 1.0])
	grad.colors = PackedColorArray([
		Color(0.04, 0.03, 0.12, 0.92), Color(0.04, 0.03, 0.12, 0.55), Color(0.04, 0.03, 0.12, 0.0),
		Color(0.04, 0.03, 0.12, 0.0), Color(0.04, 0.03, 0.12, 0.7), Color(0.04, 0.03, 0.12, 0.95)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_logo()
	_build_bottom()
	_intro_animation()
	Music.play_theme()


func _build_logo() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = 70
	box.offset_left = 20
	box.offset_right = -20
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var tag := UI.label("YAPAY ZEKÂ DESTEKLİ EV İÇİ HAZİNE AVI", 22, UI.ACCENT)
	box.add_child(tag)

	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 1.1
	bold.spacing_glyph = 2
	var title := Label.new()
	title.text = "Saklı Nesne"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", bold)
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color("#3B1F8C"))
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_shadow_color", Color(UI.ACCENT, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 8)
	title.add_theme_constant_override("shadow_outline_size", 30)
	box.add_child(title)
	_logo = title

	box.add_child(UI.label("7'den 70'e herkes için", 28, Color(1, 1, 1, 0.85)))


func _build_bottom() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -300
	box.offset_bottom = -50
	box.offset_left = 60
	box.offset_right = -60
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 22)
	add_child(box)

	_start = Button.new()
	_start.text = "BAŞLAT"
	_start.custom_minimum_size = Vector2(0, 132)
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 1.0
	bold.spacing_glyph = 6
	_start.add_theme_font_override("font", bold)
	_start.add_theme_font_size_override("font_size", 52)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(66)
		sb.anti_aliasing = true
		sb.bg_color = UI.GOOD if state != "pressed" else UI.GOOD.darkened(0.25)
		if state == "hover":
			sb.bg_color = UI.GOOD.lightened(0.1)
		sb.border_color = Color(1, 1, 1, 0.9)
		sb.set_border_width_all(5)
		sb.shadow_color = Color(UI.GOOD, 0.55)
		sb.shadow_size = 26
		if state == "focus":
			sb.draw_center = false
			sb.shadow_size = 0
		_start.add_theme_stylebox_override(state, sb)
	_start.add_theme_color_override("font_color", Color("#06281A"))
	_start.add_theme_color_override("font_hover_color", Color("#06281A"))
	_start.add_theme_color_override("font_pressed_color", Color("#06281A"))
	_start.pressed.connect(_on_start)
	box.add_child(_start)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_music_btn = _small_button(_music_text(), _toggle_music)
	row.add_child(_music_btn)
	row.add_child(_small_button("❔ Nasıl Oynanır?", _show_help))
	box.add_child(row)


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(250, 76)
	b.add_theme_font_size_override("font_size", 26)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(38)
		sb.bg_color = Color(1, 1, 1, 0.12 if state == "normal" else 0.22)
		sb.border_color = Color(1, 1, 1, 0.35)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.pressed.connect(cb)
	return b


func _music_text() -> String:
	return "🔊 Müzik Açık" if Music.enabled else "🔇 Müzik Kapalı"


func _toggle_music() -> void:
	Music.toggle()
	_music_btn.text = _music_text()


func _intro_animation() -> void:
	# logo yukarıdan düşer, sonra hafifçe süzülür
	_logo.resized.connect(func() -> void: _logo.pivot_offset = _logo.size / 2.0)
	_logo.modulate.a = 0.0
	_logo.scale = Vector2(1.3, 1.3)
	var tw := create_tween().set_parallel()
	tw.tween_property(_logo, "modulate:a", 1.0, 0.5)
	tw.tween_property(_logo, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bob := create_tween().set_loops()
	bob.tween_property(_logo, "rotation", deg_to_rad(-1.2), 1.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_logo, "rotation", deg_to_rad(1.2), 1.6).set_trans(Tween.TRANS_SINE)

	# BAŞLAT nabız gibi atar
	_start.resized.connect(func() -> void: _start.pivot_offset = _start.size / 2.0)
	_start.modulate.a = 0.0
	var appear := create_tween()
	appear.tween_interval(0.5)
	appear.tween_property(_start, "modulate:a", 1.0, 0.4)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_start, "scale", Vector2(1.05, 1.05), 0.55).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_start, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)


func _on_start() -> void:
	var tw := create_tween()
	tw.tween_property(_start, "scale", Vector2(0.92, 0.92), 0.06)
	tw.tween_property(_start, "scale", Vector2(1.1, 1.1), 0.12)
	tw.tween_callback(GameState.open_menu)


func _show_help() -> void:
	if _help:
		return
	_help = Control.new()
	_help.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_help.add_child(dim)
	var box := UI.page(_help, 22)
	box.add_child(UI.title("Nasıl Oynanır?"))
	var steps := [
		["📸", "Saklayan", "Ebeler gözlerini kapatır. Saklayan evde bir nesne seçer ve 2-3 açıdan tarar."],
		["🤖", "Yapay zekâ", "Nesneyi tanır (ör. mavi vazo) ve her yaşa uygun ipuçları hazırlar."],
		["🔍", "Ebeler", "Evi dolaşır, şüphelendikleri nesneyi kameraya gösterip tarar."],
		["🧩", "İpucu", "İpucu isteyen ebe önce kısa bir zekâ oyunu çözer. İpucu nesnenin adını söylemez, çağrıştırır."],
		["🏆", "Kazanan", "Doğru nesneyi ilk tarayan kazanır!"],
	]
	for s in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var icon := UI.label(s[0], 54)
		icon.custom_minimum_size.x = 80
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.label(s[1], 30, UI.ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
		col.add_child(UI.label(s[2], 26, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
		row.add_child(col)
		box.add_child(UI.panel(row))
	box.add_child(UI.button("Anladım", _close_help))
	add_child(_help)


func _close_help() -> void:
	if _help:
		_help.queue_free()
		_help = null
