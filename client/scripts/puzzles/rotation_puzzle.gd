extends VBoxContainer
## Dönen şekil dizisi: sıradaki adımı bul.

signal answered(answer: Variant)

var _done := false


func setup(data: Dictionary) -> void:
	add_theme_constant_override("separation", 22)
	add_child(UI.label("Şekil her adımda nasıl değişiyor? Sıradaki hangisi?", 26, UI.MUTED))
	var shape := str(data.get("shape", "arrow"))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for f in data.get("sequence", []):
		var c := ShapeCell.new({"shape": shape, "color": f.get("color"), "angle": f.get("angle"), "count": 1})
		c.custom_minimum_size = Vector2(118, 118)
		row.add_child(c)
	var q := ShapeCell.new({}, true)
	q.custom_minimum_size = Vector2(118, 118)
	row.add_child(q)
	add_child(row)

	var opts: Array = data.get("options", [])
	var g := GridContainer.new()
	g.columns = 3 if opts.size() != 4 else 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in opts.size():
		var o: Dictionary = opts[i]
		var c := ShapeCell.new({"shape": shape, "color": o.get("color"), "angle": o.get("angle"), "count": 1}, false, true)
		c.custom_minimum_size = Vector2(140, 140)
		var idx := i
		c.tapped.connect(func() -> void:
			if not _done:
				_done = true
				answered.emit(idx))
		g.add_child(c)
	add_child(g)
