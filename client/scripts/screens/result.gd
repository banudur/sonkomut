extends Control
## Tur sonu: kazanan, nesne, süre. Kurucu yeni tura geçirir.


func _ready() -> void:
	var room := GameState.room
	var winner_id := str(room.get("winner_id", ""))
	var won := winner_id == GameState.player_id

	var box := UI.page(self, 24)
	box.add_child(_gap(80))
	var trophy := UI.label("🏆" if won else "🎉", 200)
	box.add_child(trophy)
	box.add_child(UI.title("Kazandın!" if won else "%s buldu!" % GameState.player_name_of(winner_id)))
	box.add_child(UI.label("Gizli nesne:", 28, UI.MUTED))
	box.add_child(UI.label(str(room.get("object", "?")), 52, UI.ACCENT))
	var secs := int(_last_game_over().get("seconds", 0))
	if secs > 0:
		box.add_child(UI.label("Süre: %d dk %d sn" % [floori(secs / 60.0), secs % 60], 28, UI.MUTED))

	if GameState.is_host():
		box.add_child(UI.button("Yeni Tur", func() -> void: Net.send({"type": "back_to_lobby"}), UI.GOOD))
	else:
		box.add_child(UI.label("Kurucu yeni turu başlatacak...", 26, UI.MUTED))
	box.add_child(UI.button("Odadan Çık", GameState.leave, UI.BAD))

	trophy.pivot_offset = Vector2(trophy.size.x / 2, trophy.size.y / 2)
	trophy.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(trophy, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_confetti()


## game_over mesajı room_state'ten önce gelir; GameState son mesajı saklar.
func _last_game_over() -> Dictionary:
	return GameState.last_game_over


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _confetti() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(get_viewport_rect().size.x / 2, -20)
	p.amount = 160
	p.lifetime = 4.0
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(get_viewport_rect().size.x / 2, 10)
	p.direction = Vector2(0, 1)
	p.spread = 35.0
	p.gravity = Vector2(0, 420)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 380.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 12.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	grad.colors = PackedColorArray([UI.ACCENT, UI.ACCENT_2, UI.GOOD, Color("#F1C40F"), Color("#E74C3C")])
	p.color_initial_ramp = grad
	add_child(p)
	p.emitting = true
