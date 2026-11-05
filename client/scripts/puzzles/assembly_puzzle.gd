extends Control
## Şekil birleştirme: parçaları sürükleyip ızgaradaki hedefi tamamen doldur.
## Döndürme açıksa parçaya kısa dokunmak onu 90° çevirir.
##
## Döndürme kuralı sunucuyla aynıdır: (x, y) -> (-y, x), ardından (0,0)'a normalize.

signal answered(answer: Variant)

const TRAY_SCALE := 0.55
const TAP_DISTANCE := 14.0

var _w := 1
var _h := 1
var _allow_rotation := false
var _pieces: Array[Dictionary] = []
var _cell := 80.0
var _board_origin := Vector2.ZERO
var _drag: Dictionary = {}   # sürüklenen parça
var _drag_offset := Vector2.ZERO  # parmak ile parçanın sol üstü arası, hücre biriminde
var _press_pos := Vector2.ZERO
var _done := false
var _hint: Label


func setup(data: Dictionary) -> void:
	_w = int(data.get("width", 3))
	_h = int(data.get("height", 2))
	_allow_rotation = bool(data.get("allow_rotation", false))
	for p in data.get("pieces", []):
		var cells: Array[Vector2i] = []
		for c in p.get("cells", []):
			cells.append(Vector2i(int(c[0]), int(c[1])))
		_pieces.append({
			"index": _pieces.size(),  # sunucudaki sıra; sürüklerken dizi sırası değişir
			"base": cells,
			"cells": cells.duplicate(),
			"rot": 0,
			"color": Color(str(p.get("color", "#ffffff"))),
			"placed": false,
			"grid": Vector2i.ZERO,
			"pos": Vector2.ZERO,
			"scale": TRAY_SCALE,
		})
	custom_minimum_size = Vector2(620, 820)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hint = UI.label(
		"Parçaları sürükle, kutuyu tamamen doldur." + (" Döndürmek için parçaya dokun." if _allow_rotation else ""),
		24, UI.MUTED)
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(_hint)
	resized.connect(_layout)
	_layout.call_deferred()


static func rotate_cells(cells: Array[Vector2i], times: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = cells.duplicate()
	for _i in posmod(times, 4):
		var r: Array[Vector2i] = []
		for c in out:
			r.append(Vector2i(-c.y, c.x))
		out = r
	var min_x := 1 << 30
	var min_y := 1 << 30
	for c in out:
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
	var norm: Array[Vector2i] = []
	for c in out:
		norm.append(Vector2i(c.x - min_x, c.y - min_y))
	return norm


func _layout() -> void:
	var top := 70.0
	_cell = clampf(minf((size.x - 40.0) / _w, size.y * 0.42 / _h), 40.0, 110.0)
	_board_origin = Vector2((size.x - _cell * _w) / 2.0, top)
	_arrange_tray()
	queue_redraw()


## Yerleştirilmemiş parçaları alt bölgeye dizer.
func _arrange_tray() -> void:
	var tray_top := _board_origin.y + _cell * _h + 50.0
	var x := 20.0
	var y := tray_top
	var row_h := 0.0
	var c := _cell * TRAY_SCALE
	for p in _pieces:
		if p.placed:
			continue
		var ext := _extent(p.cells)
		var pw := ext.x * c
		if x + pw > size.x - 20.0 and x > 20.0:
			x = 20.0
			y += row_h + 24.0
			row_h = 0.0
		p.pos = Vector2(x, y)
		p.scale = TRAY_SCALE
		x += pw + 30.0
		row_h = maxf(row_h, ext.y * c)


func _extent(cells: Array[Vector2i]) -> Vector2i:
	var e := Vector2i.ZERO
	for c in cells:
		e.x = maxi(e.x, c.x + 1)
		e.y = maxi(e.y, c.y + 1)
	return e


func _piece_at(point: Vector2) -> Dictionary:
	for i in range(_pieces.size() - 1, -1, -1):  # üstteki önce
		var p: Dictionary = _pieces[i]
		var c: float = _cell * p.scale
		for cell in p.cells:
			if Rect2(p.pos + Vector2(cell) * c, Vector2(c, c)).has_point(point):
				return p
	return {}


func _fits(piece: Dictionary, g: Vector2i) -> bool:
	var occupied := {}
	for p in _pieces:
		if p == piece or not p.placed:
			continue
		for c in p.cells:
			occupied[c + p.grid] = true
	for c in piece.cells:
		var cell: Vector2i = c + g
		if cell.x < 0 or cell.y < 0 or cell.x >= _w or cell.y >= _h or occupied.has(cell):
			return false
	return true


func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p := _piece_at(event.position)
			if p.is_empty():
				return
			_drag = p
			_press_pos = event.position
			var c: float = _cell * p.scale
			_drag_offset = (event.position - p.pos) / c
			# Sürüklenen parça en üstte çizilsin
			_pieces.erase(p)
			_pieces.append(p)
			accept_event()
		elif not _drag.is_empty():
			_release(event.position)
			accept_event()
	elif event is InputEventMouseMotion and not _drag.is_empty():
		_drag.scale = 1.0
		_drag.pos = event.position - _drag_offset * _cell
		queue_redraw()
		accept_event()


func _release(point: Vector2) -> void:
	var p := _drag
	_drag = {}
	if point.distance_to(_press_pos) < TAP_DISTANCE:
		if _allow_rotation:
			p.rot = posmod(int(p.rot) + 1, 4)
			p.cells = rotate_cells(p.base, p.rot)
			if p.placed and not _fits(p, p.grid):
				p.placed = false
			_after_change()
		return
	var g := Vector2i(roundi((p.pos.x - _board_origin.x) / _cell), roundi((p.pos.y - _board_origin.y) / _cell))
	if _fits(p, g):
		p.placed = true
		p.grid = g
		p.scale = 1.0
		p.pos = _board_origin + Vector2(g) * _cell
	else:
		p.placed = false
	_after_change()


func _after_change() -> void:
	_arrange_tray()
	queue_redraw()
	for p in _pieces:
		if not p.placed:
			return
	_done = true
	var answer: Array = []
	for p in _pieces:
		answer.append({"piece": _original_index(p), "rotation": p.rot, "x": p.grid.x, "y": p.grid.y})
	# Tamamlanma animasyonu için kısa bekleme
	await get_tree().create_timer(0.35).timeout
	answered.emit(answer)


func _original_index(piece: Dictionary) -> int:
	return int(piece.get("index", 0))


func _draw() -> void:
	# Tahta
	var board := Rect2(_board_origin, Vector2(_w, _h) * _cell)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.08)
	sb.set_corner_radius_all(18)
	sb.border_color = Color(UI.ACCENT, 0.7)
	sb.set_border_width_all(3)
	draw_style_box(sb, board.grow(10))
	for x in _w:
		for y in _h:
			var r := Rect2(_board_origin + Vector2(x, y) * _cell, Vector2(_cell, _cell)).grow(-3)
			draw_rect(r, Color(1, 1, 1, 0.06))
	# Tepsi ayracı
	var tray_y := board.end.y + 28.0
	draw_line(Vector2(30, tray_y), Vector2(size.x - 30, tray_y), Color(1, 1, 1, 0.15), 2.0)
	# Parçalar
	for p in _pieces:
		_draw_piece(p, p == _drag)


func _draw_piece(p: Dictionary, lifted: bool) -> void:
	var c: float = _cell * p.scale
	var col: Color = p.color
	for cell in p.cells:
		var r := Rect2(p.pos + Vector2(cell) * c, Vector2(c, c)).grow(-2)
		if lifted:
			draw_rect(Rect2(r.position + Vector2(6, 10), r.size), Color(0, 0, 0, 0.3))
		var box := StyleBoxFlat.new()
		box.bg_color = col
		box.set_corner_radius_all(int(c * 0.18))
		box.border_color = col.darkened(0.35)
		box.set_border_width_all(maxi(2, int(c * 0.05)))
		draw_style_box(box, r)
		# üst parlama
		draw_rect(Rect2(r.position + Vector2(c * 0.15, c * 0.12), Vector2(r.size.x - c * 0.3, c * 0.14)),
			Color(1, 1, 1, 0.28))
