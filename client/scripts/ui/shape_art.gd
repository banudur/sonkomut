class_name ShapeArt
extends RefCounted
## Bulmacalarda kullanılan şekillerin çizimi (gölge + parlama ile).


static func polygon(shape: String, center: Vector2, r: float, angle_deg := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"circle":
			for i in 48:
				pts.append(Vector2.from_angle(TAU * i / 48.0) * r)
		"square":
			var k := r * 0.85
			pts = PackedVector2Array([Vector2(-k, -k), Vector2(k, -k), Vector2(k, k), Vector2(-k, k)])
		"triangle":
			for i in 3:
				pts.append(Vector2.from_angle(-PI / 2 + TAU * i / 3.0) * r * 1.1 + Vector2(0, r * 0.15))
		"diamond":
			pts = PackedVector2Array([Vector2(0, -r), Vector2(r * 0.75, 0), Vector2(0, r), Vector2(-r * 0.75, 0)])
		"hexagon":
			for i in 6:
				pts.append(Vector2.from_angle(TAU * i / 6.0) * r)
		"star":
			for i in 10:
				var rr := r if i % 2 == 0 else r * 0.45
				pts.append(Vector2.from_angle(-PI / 2 + TAU * i / 10.0) * rr)
		"arrow":
			# Sağı gösteren ok (0° = sağ)
			pts = PackedVector2Array([
				Vector2(-r, -r * 0.25), Vector2(r * 0.2, -r * 0.25), Vector2(r * 0.2, -r * 0.6),
				Vector2(r, 0), Vector2(r * 0.2, r * 0.6), Vector2(r * 0.2, r * 0.25), Vector2(-r, r * 0.25)])
		"flag":
			pts = PackedVector2Array([
				Vector2(-r * 0.7, -r), Vector2(r * 0.8, -r * 0.55), Vector2(-r * 0.45, -r * 0.1),
				Vector2(-r * 0.45, r), Vector2(-r * 0.7, r)])
		"key":
			pts = PackedVector2Array([
				Vector2(-r, -r * 0.45), Vector2(-r * 0.3, -r * 0.45), Vector2(-r * 0.3, -r * 0.12),
				Vector2(r, -r * 0.12), Vector2(r, r * 0.4), Vector2(r * 0.7, r * 0.4), Vector2(r * 0.7, r * 0.12),
				Vector2(r * 0.4, r * 0.12), Vector2(r * 0.4, r * 0.3), Vector2(r * 0.1, r * 0.3),
				Vector2(r * 0.1, r * 0.12), Vector2(-r * 0.3, r * 0.12), Vector2(-r * 0.3, r * 0.45),
				Vector2(-r, r * 0.45)])
		_:
			return polygon("circle", center, r, angle_deg)
	var rot := deg_to_rad(angle_deg)
	var out := PackedVector2Array()
	for p in pts:
		out.append(center + p.rotated(rot))
	return out


static func draw(ci: CanvasItem, shape: String, center: Vector2, r: float, color: Color, angle_deg := 0.0) -> void:
	var pts := polygon(shape, center, r, angle_deg)
	# gölge
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, r * 0.12))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	# gövde: alttan üste hafif açılan renk
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - (center.y - r)) / (2.0 * r), 0.0, 1.0)
		cols.append(color.lightened(0.25).lerp(color.darkened(0.2), t))
	ci.draw_polygon(pts, cols)
	# kenar çizgisi
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, color.darkened(0.45), maxf(2.0, r * 0.07), true)
	# parlama
	ci.draw_circle(center + Vector2(-r * 0.3, -r * 0.35), r * 0.14, Color(1, 1, 1, 0.35))


## count adet şekli bir hücre içine dizer.
static func draw_group(ci: CanvasItem, shape: String, rect: Rect2, color: Color, count: int, angle_deg := 0.0) -> void:
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y)
	var offsets: Array[Vector2] = []
	var r := s * 0.3
	match count:
		1:
			offsets = [Vector2.ZERO]
		2:
			offsets = [Vector2(-0.22, 0), Vector2(0.22, 0)]
			r = s * 0.18
		3:
			offsets = [Vector2(0, -0.2), Vector2(-0.22, 0.17), Vector2(0.22, 0.17)]
			r = s * 0.16
		_:
			offsets = [Vector2(-0.2, -0.2), Vector2(0.2, -0.2), Vector2(-0.2, 0.2), Vector2(0.2, 0.2)]
			r = s * 0.15
	for o in offsets:
		draw(ci, shape, c + o * s, r, color, angle_deg)
