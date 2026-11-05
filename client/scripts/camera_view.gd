class_name CameraView
extends Control
## Kamera önizlemesi + AR tarama efekti + fotoğraf yakalama.
##
## Görüntü bir SubViewport içinde çizilir; böylece kamera formatından (RGB veya
## ayrı Y/CbCr düzlemleri) bağımsız olarak aynı yoldan JPEG'e çevrilebilir.
## Kamera yoksa (masaüstü, emülatör) test için dosyadan görüntü seçilebilir.

signal status_changed(text: String)

const CAPTURE_SIZE := Vector2i(720, 960)
const MAX_SIDE := 1024
const JPEG_QUALITY := 0.8

var _viewport: SubViewport
var _feed: CameraFeed
var _source: Control
var _overlay: ColorRect
var _flash: ColorRect
var _has_image := false


func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(0, 760)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_viewport = SubViewport.new()
	_viewport.size = CAPTURE_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var vp_bg := ColorRect.new()
	vp_bg.color = Color(0.05, 0.05, 0.1)
	vp_bg.size = CAPTURE_SIZE
	_viewport.add_child(vp_bg)

	var display := TextureRect.new()
	display.set_anchors_preset(Control.PRESET_FULL_RECT)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	display.texture = _viewport.get_texture()
	add_child(display)

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/scan_overlay.gdshader")
	_overlay.material = mat
	add_child(_overlay)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)

	_start_camera()


func _exit_tree() -> void:
	if _feed:
		_feed.feed_is_active = false


func has_image() -> bool:
	return _has_image


## Tarama efektinin rengini değiştirir (ör. başarılıda yeşil, hatada kırmızı).
func set_tint(color: Color) -> void:
	(_overlay.material as ShaderMaterial).set_shader_parameter("tint", color)


## O anki görüntüyü JPEG olarak base64 döner. Görüntü yoksa boş dize.
func capture_base64() -> String:
	if not _has_image:
		return ""
	await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	if img == null or img.is_empty():
		return ""
	var k := float(MAX_SIDE) / maxf(img.get_width(), img.get_height())
	if k < 1.0:
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGB8)
	_flash.color.a = 0.85
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	return Marshalls.raw_to_base64(img.save_jpg_to_buffer(JPEG_QUALITY))


## Kamerasız ortamlarda test için: dosyadan görüntü seç.
func open_file_picker() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.jpg, *.jpeg, *.png, *.webp ; Görüntüler"])
	fd.use_native_dialog = true
	fd.file_selected.connect(func(path: String) -> void:
		var img := Image.load_from_file(path)
		if img and not img.is_empty():
			show_image(img)
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered_ratio(0.8)


func show_image(img: Image) -> void:
	_stop_feed()
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	_set_source(tr)
	status_changed.emit("")


# ------------------------------------------------------------ kamera

func _start_camera() -> void:
	if OS.get_name() == "Android":
		# Dışa aktarma ayarlarında CAMERA izni açık olmalı.
		if not get_tree().on_request_permissions_result.is_connected(_on_permission):
			get_tree().on_request_permissions_result.connect(_on_permission)
		OS.request_permissions()
	# Godot 4.4+: bazı platformlarda kameralar ancak izleme açılınca listelenir.
	if "monitoring_feeds" in CameraServer:
		CameraServer.set("monitoring_feeds", true)
	if not CameraServer.camera_feed_added.is_connected(_on_feed_added):
		CameraServer.camera_feed_added.connect(_on_feed_added)
	_pick_feed()


func _on_permission(_permission: String, granted: bool) -> void:
	if granted:
		_pick_feed()
	else:
		status_changed.emit("Kamera izni verilmedi.")


func _on_feed_added(_id: int) -> void:
	_pick_feed()


func _pick_feed() -> void:
	if _feed or _has_image:
		return
	var best: CameraFeed = null
	for f in CameraServer.feeds():
		if best == null or f.get_position() == CameraFeed.FEED_BACK:
			best = f
	if best == null:
		status_changed.emit("Kamera bulunamadı. Test için dosyadan görüntü seçebilirsin.")
		return
	_feed = best
	var formats := _feed.get_formats()
	if formats.size() > 0:
		_feed.set_format(0, {})
	_feed.feed_is_active = true
	status_changed.emit("")


func _process(_delta: float) -> void:
	# Görüntü formatı ancak ilk kareler gelince belli olur.
	if _feed and _source == null:
		var dt := _feed.get_datatype()
		if dt != CameraFeed.FEED_NOIMAGE:
			_build_feed_source(dt)


func _build_feed_source(datatype: int) -> void:
	var id := _feed.get_id()
	if datatype == CameraFeed.FEED_YCBCR_SEP:
		var rect := ColorRect.new()
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/ycbcr.gdshader")
		var ty := CameraTexture.new()
		ty.camera_feed_id = id
		ty.which_feed = CameraServer.FEED_Y_IMAGE
		var tc := CameraTexture.new()
		tc.camera_feed_id = id
		tc.which_feed = CameraServer.FEED_CBCR_IMAGE
		m.set_shader_parameter("y_tex", ty)
		m.set_shader_parameter("cbcr_tex", tc)
		rect.material = m
		_set_source(rect)
	else:
		var tr := TextureRect.new()
		var t := CameraTexture.new()
		t.camera_feed_id = id
		t.which_feed = CameraServer.FEED_RGBA_IMAGE
		tr.texture = t
		_set_source(tr)


func _set_source(c: Control) -> void:
	if _source:
		_source.queue_free()
	_source = c
	if c is TextureRect:
		var tr := c as TextureRect
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	c.position = Vector2.ZERO
	c.size = CAPTURE_SIZE
	_viewport.add_child(c)
	_has_image = true


func _stop_feed() -> void:
	if _feed:
		_feed.feed_is_active = false
		_feed = null
