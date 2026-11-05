extends Control
## Ekranı kaplayan bulmaca penceresi. Cevap verilince ya da süre dolunca `answered` yayar.

signal answered(puzzle_id: String, answer: Variant)

const TITLES := {
	"matrix": "Şekil Matrisi",
	"rotation": "Dönen Şekil",
	"assembly": "Parçaları Birleştir",
}
const WIDGETS := {
	"matrix": preload("res://scripts/puzzles/matrix_puzzle.gd"),
	"rotation": preload("res://scripts/puzzles/rotation_puzzle.gd"),
	"assembly": preload("res://scripts/puzzles/assembly_puzzle.gd"),
}

var _puzzle_id := ""
var _time_limit := 0.0
var _elapsed := 0.0
var _bar: ProgressBar
var _sent := false


func open(msg: Dictionary) -> void:
	_puzzle_id = str(msg.get("puzzle_id", ""))
	_time_limit = float(msg.get("time_limit", 0))
	var kind := str(msg.get("puzzle_type", "matrix"))

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := UI.page(self, 20)
	box.add_child(UI.label("İPUCU BULMACASI", 24, UI.ACCENT))
	box.add_child(UI.title(TITLES.get(kind, "Bulmaca")))
	if _time_limit > 0:
		_bar = ProgressBar.new()
		_bar.max_value = _time_limit
		_bar.value = _time_limit
		_bar.show_percentage = false
		_bar.custom_minimum_size.y = 18
		box.add_child(_bar)

	var widget = (WIDGETS.get(kind, WIDGETS["matrix"]) as GDScript).new()
	widget.setup(msg.get("data", {}))
	widget.answered.connect(_on_answer)
	box.add_child(widget)
	box.add_child(UI.button("Vazgeç", func() -> void: _on_answer(-1), UI.BAD))

	modulate.a = 0.0
	scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _bar == null or _sent:
		return
	_elapsed += delta
	_bar.value = maxf(0.0, _time_limit - _elapsed)
	if _elapsed / _time_limit > 0.75:
		_bar.modulate = UI.BAD
	if _elapsed >= _time_limit:
		_on_answer(-1)


func _on_answer(answer: Variant) -> void:
	if _sent:
		return
	_sent = true
	answered.emit(_puzzle_id, answer)
