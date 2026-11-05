extends Control
## Ebelerin bekleme ekranı: saklayan nesnesini seçerken gözler kapalı!

var _eye: Label


func _ready() -> void:
	var box := UI.page(self, 30)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_gap(160))
	_eye = UI.label("🙈", 180)
	box.add_child(_eye)
	box.add_child(UI.title("Gözler kapalı!"))
	var hider := GameState.player_name_of(str(GameState.room.get("hider_id", "")))
	box.add_child(UI.label("%s şu an gizlice bir nesne seçip tarıyor." % hider, 32, UI.MUTED))
	box.add_child(UI.label("Bakmak yok! Hazır olunca arama otomatik başlayacak.", 28, UI.MUTED))
	var tw := create_tween().set_loops()
	tw.tween_property(_eye, "scale", Vector2(1.08, 1.08), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_eye, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	_eye.resized.connect(func() -> void: _eye.pivot_offset = _eye.size / 2)


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c
