class_name AttractLoop
extends Control
## Giriş ekranının arkasında sürekli dönen tanıtım animasyonu ("oyun nasıl oynanır" klibi).
##
## Akış: saklayan vazoyu tarar → AI tanır → ebe yanlış nesneyi tarar → ipucu gelir →
## bulmaca çözülür → ebe vazoyu bulur → kutlama. 16 saniyede bir başa döner.
##
## Tamamen kodla çizilir: dosya boyutu yok, her ekranda keskin. İleride gerçek bir oyun
## kaydı eklemek isterseniz res://media/intro.ogv dosyasını koymanız yeterli; varsa o oynatılır.

const W := 720.0
const H := 1280.0
const LOOP := 16.0
const VIDEO_PATH := "res://media/intro.ogv"

const VASE := Vector2(550, 690)
const LAMP := Vector2(650, 515)
const PHONE_SIZE := Vector2(250, 400)

const C_WALL_TOP := Color("#2B2160")
const C_WALL_BOTTOM := Color("#3E2E73")
const C_FLOOR := Color("#5A3A2E")
const C_SCAN := Color("#5EE6F0")
const C_GOOD := Color("#4ADE80")
const C_BAD := Color("#F87171")
const C_HIDER := Color("#B48CFF")

const CAPTIONS := [
	[0.0, 3.2, "1", "Saklayan gizlice bir nesne tarar"],
	[3.2, 6.0, "2", "Yapay zekâ nesneyi tanır"],
	[6.0, 9.0, "3", "Ebeler arar, ipucu alır"],
	[9.0, 12.4, "4", "İpucu için zekâ oyunu çöz"],
	[12.4, 16.0, "5", "İlk bulan kazanır!"],
]

## Alttaki yazı şeridini göster (başlık ekranı kendi yazısını koyuyorsa kapatılabilir).
@export var show_captions := true

var t := 0.0
var _font: Font
var _bold: FontVariation
var _base_off := Vector2.ZERO
var _base_k := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_bold = FontVariation.new()
	_bold.base_font = _font
	_bold.variation_embolden = 0.9
	if ResourceLoader.exists(VIDEO_PATH):
		var vp := VideoStreamPlayer.new()
		vp.stream = load(VIDEO_PATH)
		vp.expand = true
		vp.loop = true
		vp.autoplay = true
		vp.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(vp)
		set_process(false)


func _process(delta: float) -> void:
	t = fmod(t + delta, LOOP)
	queue_redraw()


# ------------------------------------------------------------ zaman yardımcıları

func _seg(a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func _out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func _inout(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


static func _back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


## Tasarım alanında (720x1280) `pos` noktası yerel (0,0) olacak, `s` ölçekli çizim.
func _xf(pos: Vector2, s := 1.0) -> void:
	draw_set_transform(_base_off + pos * _base_k, 0.0, Vector2.ONE * _base_k * s)


func _xf_reset() -> void:
	draw_set_transform(_base_off, 0.0, Vector2.ONE * _base_k)


func _text(center: Vector2, text: String, fs: int, color: Color, bold := false) -> void:
	var f: Font = _bold if bold else _font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, center + Vector2(-w / 2.0, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _box(rect: Rect2, bg: Color, radius: int, border := Color.TRANSPARENT, bw := 0, shadow := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.4)
	draw_style_box(sb, rect)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		pts.append(c + Vector2(cos(TAU * i / 40.0) * r.x, sin(TAU * i / 40.0) * r.y))
	draw_colored_polygon(pts, col)


# ------------------------------------------------------------ çizim

func _draw() -> void:
	if not is_processing():
		return
	_base_k = maxf(size.x / W, size.y / H)
	_base_off = (size - Vector2(W, H) * _base_k) / 2.0
	_xf_reset()

	_draw_room()
	var ph := _phone_state()
	_draw_phone(ph)
	_draw_ai_chip()
	_draw_hint_card()
	_draw_puzzle_card()
	_draw_found()
	if show_captions:
		_draw_caption()

	# döngü geçişi için karartma
	var fade := maxf(1.0 - _seg(0.0, 0.45), _seg(15.55, 16.0))
	if fade > 0.0:
		draw_rect(Rect2(-W, -H, W * 3, H * 3), Color(0.03, 0.02, 0.08, fade))


func _draw_room() -> void:
	# duvar
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 880), Vector2(0, 880)]),
		PackedColorArray([C_WALL_TOP, C_WALL_TOP, C_WALL_BOTTOM, C_WALL_BOTTOM]))
	# süpürgelik + zemin
	draw_rect(Rect2(0, 868, W, 14), Color("#24183F"))
	draw_polygon(PackedVector2Array([Vector2(0, 880), Vector2(W, 880), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([C_FLOOR.lightened(0.08), C_FLOOR.lightened(0.08), C_FLOOR.darkened(0.3), C_FLOOR.darkened(0.3)]))
	for i in 7:
		var y := 900.0 + pow(i / 6.0, 1.6) * 380.0
		draw_line(Vector2(0, y), Vector2(W, y), Color(0, 0, 0, 0.12), 2.0)

	# pencere: gece, ay, yıldızlar
	var win := Rect2(60, 380, 200, 240)
	_box(win.grow(12), Color("#E8D9B5"), 10)
	draw_rect(win, Color("#121A44"))
	draw_circle(Vector2(200, 440), 26, Color("#FFF3C4"))
	draw_circle(Vector2(212, 432), 22, Color("#121A44"))
	for s in [Vector2(90, 420), Vector2(130, 470), Vector2(100, 560), Vector2(230, 540), Vector2(170, 590)]:
		var tw := 0.6 + 0.4 * sin(t * 3.0 + s.x)
		draw_circle(s, 2.5, Color(1, 1, 1, tw))
	draw_line(Vector2(160, 380), Vector2(160, 620), Color("#E8D9B5"), 8.0)
	draw_line(Vector2(60, 500), Vector2(260, 500), Color("#E8D9B5"), 8.0)
	# perde
	draw_colored_polygon(PackedVector2Array([Vector2(30, 360), Vector2(80, 360), Vector2(60, 650), Vector2(24, 650)]), Color("#C0566B"))
	draw_colored_polygon(PackedVector2Array([Vector2(240, 360), Vector2(290, 360), Vector2(296, 650), Vector2(260, 650)]), Color("#C0566B"))

	# tablo
	_box(Rect2(370, 400, 150, 110), Color("#F4C95D"), 6)
	draw_rect(Rect2(382, 412, 126, 86), Color("#7FD1AE"))
	draw_colored_polygon(PackedVector2Array([Vector2(382, 498), Vector2(430, 440), Vector2(470, 480), Vector2(490, 460), Vector2(508, 498)]), Color("#3C8D6E"))
	draw_circle(Vector2(480, 432), 10, Color("#FFF3C4"))

	# lambader
	var lamp_on := 0.75 + 0.25 * sin(t * 2.0)
	_ellipse(Vector2(650, 600), Vector2(140, 170), Color(1.0, 0.85, 0.5, 0.07 * lamp_on))
	draw_line(Vector2(650, 550), Vector2(650, 875), Color("#2A2A36"), 8.0)
	_ellipse(Vector2(650, 878), Vector2(45, 10), Color("#2A2A36"))
	draw_colored_polygon(PackedVector2Array([Vector2(615, 470), Vector2(685, 470), Vector2(712, 552), Vector2(588, 552)]), Color("#F7D774"))
	draw_line(Vector2(588, 552), Vector2(712, 552), Color("#E0B94F"), 4.0)

	# halı + top
	_ellipse(Vector2(330, 1010), Vector2(270, 58), Color("#3C7EA6"))
	_ellipse(Vector2(330, 1010), Vector2(220, 40), Color("#5BA3C9"))
	_ellipse(Vector2(140, 1062), Vector2(36, 8), Color(0, 0, 0, 0.25))
	draw_circle(Vector2(140, 1036), 30, Color("#EF5B5B"))
	draw_arc(Vector2(140, 1036), 30, -0.6, 1.2, 16, Color.WHITE, 5.0, true)

	# kanepe
	_ellipse(Vector2(210, 878), Vector2(200, 12), Color(0, 0, 0, 0.25))
	_box(Rect2(40, 650, 340, 130), Color("#D16A7C"), 28)
	_box(Rect2(30, 760, 360, 84), Color("#B9566A"), 22)
	_box(Rect2(14, 700, 56, 150), Color("#C35F73"), 24)
	_box(Rect2(350, 700, 56, 150), Color("#C35F73"), 24)
	_box(Rect2(80, 690, 90, 70), Color("#F4C95D"), 18)  # yastık
	for x in [48, 372]:
		draw_rect(Rect2(x, 844, 12, 34), Color("#3A2A2A"))

	# sehpa
	_ellipse(Vector2(550, 880), Vector2(110, 10), Color(0, 0, 0, 0.25))
	_box(Rect2(450, 760, 200, 20), Color("#8B5E3C"), 6)
	draw_rect(Rect2(468, 780, 12, 98), Color("#6E4A30"))
	draw_rect(Rect2(620, 780, 12, 98), Color("#6E4A30"))
	draw_rect(Rect2(472, 830, 156, 8), Color("#6E4A30"))

	# mavi vazo + çiçekler (gizli nesne)
	_draw_vase(Vector2(550, 760))


func _draw_vase(bottom: Vector2) -> void:
	for f in [[Vector2(-26, -168), Color("#FF8FB1")], [Vector2(4, -184), Color("#FFD166")], [Vector2(30, -160), Color("#FF8FB1")]]:
		var p: Vector2 = bottom + f[0]
		draw_line(bottom + Vector2(0, -122), p, Color("#3C8D6E"), 4.0)
		for k in 5:
			draw_circle(p + Vector2.from_angle(TAU * k / 5.0 + t * 0.3) * 9.0, 7.0, f[1])
		draw_circle(p, 6.0, Color("#FFF3C4"))
	var body := PackedVector2Array([
		Vector2(-30, 0), Vector2(30, 0), Vector2(46, -40), Vector2(40, -80), Vector2(16, -108),
		Vector2(20, -124), Vector2(-20, -124), Vector2(-16, -108), Vector2(-40, -80), Vector2(-46, -40)])
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for p in body:
		pts.append(bottom + p)
		cols.append(Color("#3B82F6").lerp(Color("#1E3A8A"), clampf((p.x + 46) / 92.0, 0, 1)))
	draw_polygon(pts, cols)
	# beyaz desen ve parlama
	draw_arc(bottom + Vector2(0, -56), 22, 0.3, PI - 0.3, 16, Color(1, 1, 1, 0.8), 4.0, true)
	draw_circle(bottom + Vector2(-8, -56), 5, Color.WHITE)
	draw_circle(bottom + Vector2(10, -48), 4, Color.WHITE)
	draw_line(bottom + Vector2(-28, -76), bottom + Vector2(-34, -40), Color(1, 1, 1, 0.35), 6.0)


# ------------------------------------------------------------ telefon

func _phone_state() -> Dictionary:
	# konum, görünürlük, renk, rol
	var off_br := Vector2(900, 1300)
	var off_r := Vector2(980, 600)
	var pos := off_br
	var color := C_SCAN
	var role := "SAKLAYAN"
	var role_col := C_HIDER
	var scan := true
	if t < 6.0:
		pos = off_br.lerp(VASE, _out(_seg(0.3, 1.6)))
		if t > 5.2:
			pos = VASE.lerp(off_r, _inout(_seg(5.2, 6.0)))
		if t > 3.2:
			color = C_GOOD
			scan = false
	elif t < 12.4:
		role = "EBE"
		role_col = C_SCAN
		pos = Vector2(-300, 600).lerp(LAMP, _out(_seg(6.0, 7.0)))
		if t > 7.8:
			color = C_BAD
			scan = false
		if t > 8.6:
			pos = LAMP.lerp(Vector2(LAMP.x, -400), _inout(_seg(8.6, 9.2)))
	else:
		role = "EBE"
		role_col = C_SCAN
		pos = Vector2(LAMP.x, -400).lerp(VASE, _out(_seg(12.4, 13.4)))
		if t > 14.0:
			color = C_GOOD
			scan = false
		if t > 15.2:
			pos = VASE.lerp(off_r, _inout(_seg(15.2, 15.9)))
	return {"pos": pos, "color": color, "role": role, "role_col": role_col, "scan": scan}


func _draw_phone(ph: Dictionary) -> void:
	var c: Vector2 = ph.pos
	var col: Color = ph.color
	var r := Rect2(c - PHONE_SIZE / 2.0, PHONE_SIZE)
	# ekran: hafif renk + ızgara (AR görünümü)
	draw_rect(r.grow(-14), Color(col, 0.07))
	for i in range(1, 6):
		var x := r.position.x + r.size.x * i / 6.0
		draw_line(Vector2(x, r.position.y + 14), Vector2(x, r.end.y - 14), Color(col, 0.08), 1.0)
	for i in range(1, 9):
		var y := r.position.y + r.size.y * i / 9.0
		draw_line(Vector2(r.position.x + 14, y), Vector2(r.end.x - 14, y), Color(col, 0.08), 1.0)
	# tarama çizgisi
	if ph.scan:
		var sy := r.position.y + 20 + fmod(t * 1.3, 1.0) * (r.size.y - 40)
		draw_rect(Rect2(r.position.x + 14, sy - 40, r.size.x - 28, 40), Color(col, 0.12))
		draw_line(Vector2(r.position.x + 14, sy), Vector2(r.end.x - 14, sy), Color(col, 0.95), 4.0)
	# hedef köşeleri
	var tb := Rect2(c - Vector2(85, 105), Vector2(170, 210))
	var L := 34.0
	for corner in [tb.position, Vector2(tb.end.x, tb.position.y), tb.end, Vector2(tb.position.x, tb.end.y)]:
		var sx := 1.0 if corner.x < c.x else -1.0
		var sy2 := 1.0 if corner.y < c.y else -1.0
		draw_line(corner, corner + Vector2(L * sx, 0), col, 6.0)
		draw_line(corner, corner + Vector2(0, L * sy2), col, 6.0)
	# çerçeve
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.set_border_width_all(14)
	frame.border_color = Color("#15151F")
	frame.set_corner_radius_all(42)
	frame.anti_aliasing = true
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 18
	draw_style_box(frame, r)
	_box(Rect2(c.x - 40, r.position.y + 6, 80, 18), Color("#15151F"), 9)
	# deklanşör
	draw_circle(Vector2(c.x, r.end.y - 52), 26, Color(1, 1, 1, 0.9))
	draw_arc(Vector2(c.x, r.end.y - 52), 32, 0, TAU, 32, Color(1, 1, 1, 0.6), 3.0, true)
	# rol etiketi
	var role: String = ph.role
	var role_col: Color = ph.role_col
	_box(Rect2(c.x - 70, r.position.y + 34, 140, 40), Color(role_col, 0.9), 20)
	_text(Vector2(c.x, r.position.y + 54), role, 20, Color("#0B1030"), true)
	# yanlış tarama işareti
	if ph.color == C_BAD:
		var k := _back(_seg(7.8, 8.1))
		_xf(c, k)
		draw_circle(Vector2.ZERO, 46, C_BAD)
		draw_line(Vector2(-18, -18), Vector2(18, 18), Color.WHITE, 9.0)
		draw_line(Vector2(18, -18), Vector2(-18, 18), Color.WHITE, 9.0)
		_xf_reset()
		_pill(c + Vector2(0, -250), "Bu değil, aramaya devam!", C_BAD, _seg(7.8, 8.0))


func _pill(center: Vector2, text: String, accent: Color, appear: float) -> void:
	if appear <= 0.0:
		return
	_xf(center, _back(appear))
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 70
	_box(Rect2(-w / 2.0, -34, w, 68), Color(1, 1, 1, 0.96), 34, accent, 4, 10)
	_text(Vector2(0, 0), text, 26, Color("#1A1B3A"), true)
	_xf_reset()


# ------------------------------------------------------------ katmanlar

func _draw_ai_chip() -> void:
	if t < 3.2 or t > 6.0:
		return
	var a := _seg(3.2, 3.6)
	var out := _seg(5.0, 5.3)
	if out >= 1.0:
		return
	var pos := VASE + Vector2(0, -290)
	_xf(pos, _back(a) * (1.0 - out))
	_box(Rect2(-230, -62, 460, 124), Color(1, 1, 1, 0.97), 30, C_GOOD, 5, 14)
	# AI rozeti
	_box(Rect2(-205, -38, 76, 76), Color("#7C5CFF"), 22)
	_text(Vector2(-167, 0), "AI", 34, Color.WHITE, true)
	_text(Vector2(40, -18), "Bunu gördüm:", 22, Color("#6B7280"))
	# yazı harf harf belirir
	var full := "mavi seramik vazo"
	var n := int(clampf((t - 3.5) / 0.9, 0.0, 1.0) * full.length())
	_text(Vector2(40, 20), full.substr(0, n), 32, Color("#1E3A8A"), true)
	if t > 4.4:
		var k := _back(_seg(4.4, 4.7))
		_xf(pos + Vector2(215, -55), k)
		draw_circle(Vector2.ZERO, 26, C_GOOD)
		draw_polyline(PackedVector2Array([Vector2(-11, 0), Vector2(-3, 9), Vector2(12, -9)]), Color.WHITE, 6.0, true)
	_xf_reset()


func _draw_hint_card() -> void:
	if t < 7.0 or t > 9.4:
		return
	var y := lerpf(-200.0, 220.0, _out(_seg(7.0, 7.6)))
	y = lerpf(y, -220.0, _inout(_seg(8.9, 9.4)))
	var rect := Rect2(80, y - 80, 560, 160)
	_box(rect, Color(1, 1, 1, 0.97), 32, Color("#F1C40F"), 5, 16)
	# ampul
	var bulb := Vector2(150, y - 8)
	var glow := 0.5 + 0.5 * sin(t * 8.0)
	draw_circle(bulb, 40 + glow * 6, Color(1, 0.85, 0.2, 0.25))
	draw_circle(bulb, 30, Color("#FFD166"))
	draw_rect(Rect2(bulb.x - 13, bulb.y + 26, 26, 18), Color("#9CA3AF"))
	draw_line(bulb + Vector2(-8, 4), bulb + Vector2(0, -8), Color("#E0A800"), 3.0)
	draw_line(bulb + Vector2(0, -8), bulb + Vector2(8, 4), Color("#E0A800"), 3.0)
	_text(Vector2(410, y - 36), "İPUCU 1", 22, Color("#B7791F"), true)
	_text(Vector2(410, y + 16), "Çiçekler bende su içer!", 32, Color("#1A1B3A"), true)


func _draw_puzzle_card() -> void:
	if t < 9.0 or t > 12.6:
		return
	var a := _out(_seg(9.0, 9.5))
	var out := _inout(_seg(12.1, 12.6))
	var center := Vector2(360, 600)
	_xf(center, lerpf(0.85, 1.0, a) * (1.0 - out * 0.3))
	var mod := a * (1.0 - out)
	_box(Rect2(-280, -360, 560, 720), Color(0.07, 0.07, 0.17, 0.96 * mod), 36, Color(C_SCAN, mod), 4, 20)
	_text(Vector2(0, -312), "İPUCU BULMACASI", 20, Color(C_SCAN, mod), true)
	_text(Vector2(0, -268), "Şekil Matrisi", 40, Color(1, 1, 1, mod), true)
	var shapes := ["circle", "triangle", "square"]
	var colors := [Color("#E74C3C"), Color("#3498DB"), Color("#2ECC71")]
	var cell := 120.0
	var solved := t > 11.3
	for r in 3:
		for c in 3:
			var cr := Rect2(-190 + c * (cell + 10), -220 + r * (cell + 10), cell, cell)
			var last := r == 2 and c == 2
			if last and not solved:
				_box(cr, Color(1, 1, 1, 0.12 * mod), 20, Color(C_SCAN, (0.5 + 0.5 * sin(t * 6.0)) * mod), 4)
				_text(cr.get_center(), "?", 64, Color(C_SCAN, mod), true)
				continue
			_box(cr, Color(1, 1, 1, 0.94 * mod), 20, C_GOOD if last else Color.TRANSPARENT, 5 if last else 0)
			if mod > 0.5:
				ShapeArt.draw_group(self, shapes[r], cr.grow(-14), colors[c], c + 1)
	# seçenekler
	# [şekil, renk] — doğru cevap: yeşil, 3 adet kare (indeks 1)
	var opts := [[2, 1], [2, 2], [1, 2]]
	for i in 3:
		var orect := Rect2(-190 + i * (cell + 10), 200, cell, cell)
		var correct := i == 1
		var tapped := correct and t > 10.9
		var border := C_GOOD if tapped else Color.TRANSPARENT
		_box(orect, Color(1, 1, 1, 0.94 * mod), 20, border, 6 if tapped else 0)
		if mod > 0.5:
			ShapeArt.draw_group(self, shapes[opts[i][0]], orect.grow(-14), colors[opts[i][1]], 3 if correct else (2 if i == 0 else 3))
	# parmak dokunuşu
	if t > 10.3 and t < 11.4:
		var fp := Vector2(-60, 420).lerp(Vector2(0, 270), _out(_seg(10.3, 10.85)))
		var press := 1.0 - 0.2 * _seg(10.85, 10.95) + 0.2 * _seg(10.95, 11.1)
		draw_circle(fp, 30 * press, Color(1, 1, 1, 0.85))
		draw_arc(fp, 42 * press, 0, TAU, 32, Color(1, 1, 1, 0.5), 3.0, true)
	if solved:
		_text(Vector2(0, 160), "Doğru! İpucu açıldı", 28, C_GOOD, true)
	_xf_reset()


func _draw_found() -> void:
	if t < 14.0:
		return
	var k := _back(_seg(14.0, 14.35))
	var out := _seg(15.3, 15.7)
	_xf(Vector2(360, 300), k * (1.0 - out * 0.5))
	var a := 1.0 - out
	_box(Rect2(-250, -70, 500, 140), Color(C_GOOD, 0.95 * a), 40, Color(1, 1, 1, a), 5, 18)
	_text(Vector2(0, -2), "BULDUN!", 64, Color(1, 1, 1, a), true)
	_xf_reset()
	# konfeti
	var dt := t - 14.0
	var palette := [Color("#5EE6F0"), Color("#B48CFF"), Color("#4ADE80"), Color("#F1C40F"), Color("#E74C3C"), Color("#FF8FB1")]
	for i in 80:
		var x0 := fposmod(i * 97.3, W)
		var spd := 260.0 + float((i * 37) % 220)
		var y := -30.0 + spd * dt + 140.0 * dt * dt - float((i * 53) % 300)
		if y < -30 or y > H:
			continue
		var x := x0 + sin(dt * 3.0 + i) * 30.0
		var ang := dt * (3.0 + i % 5) + i
		var col: Color = palette[i % palette.size()]
		var half := Vector2(9, 5)
		var pts := PackedVector2Array()
		for v in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			pts.append(Vector2(x, y) + (v * half).rotated(ang))
		draw_colored_polygon(pts, col)


func _draw_caption() -> void:
	for cap in CAPTIONS:
		if t < cap[0] or t >= cap[1]:
			continue
		var a: float = minf(_seg(cap[0], cap[0] + 0.3), 1.0 - _seg(cap[1] - 0.3, cap[1]))
		var text: String = cap[3]
		var w := _bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 120
		var y := 975.0 + (1.0 - a) * 20.0
		_box(Rect2(360 - w / 2.0, y - 38, w, 76), Color(0.05, 0.04, 0.14, 0.85 * a), 38, Color(C_SCAN, 0.6 * a), 2)
		draw_circle(Vector2(360 - w / 2.0 + 40, y), 22, Color(C_SCAN, a))
		_text(Vector2(360 - w / 2.0 + 40, y), cap[2], 26, Color(0.05, 0.05, 0.15, a), true)
		_text(Vector2(360 + 30, y), text, 28, Color(1, 1, 1, a), true)
		# ilerleme noktaları
		for i in CAPTIONS.size():
			var on: bool = CAPTIONS[i] == cap
			draw_circle(Vector2(360 - 48 + i * 24, y + 62), 6 if on else 4, Color(1, 1, 1, (0.95 if on else 0.35) * a))
