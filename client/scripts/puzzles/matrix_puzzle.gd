extends VBoxContainer
## 3x3 şekil matrisi: eksik hücreyi bul.

signal answered(answer: Variant)

var _done := false


func setup(data: Dictionary) -> void:
	add_theme_constant_override("separation", 22)
	add_child(UI.label("Satır ve sütunlardaki kuralı bul. Soru işaretinin yerine hangisi gelir?", 26, UI.MUTED))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for cell in data.get("cells", []):
		grid.add_child(ShapeCell.new(cell))
	grid.add_child(ShapeCell.new({}, true))
	add_child(grid)

	add_child(_options(data.get("options", [])))


func _options(options: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3 if options.size() != 4 else 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in options.size():
		var c := ShapeCell.new(options[i], false, true)
		c.custom_minimum_size = Vector2(130, 130)
		var idx := i
		c.tapped.connect(func() -> void: _choose(idx))
		g.add_child(c)
	return g


func _choose(i: int) -> void:
	if _done:
		return
	_done = true
	answered.emit(i)
