extends Node
## Giriş müziği. Menü ve lobide çalar, oyun sırasında susar (oyuncular odaklansın).

const THEME := preload("res://audio/intro_theme.ogg")
const SETTINGS_PATH := "user://audio.cfg"
const VOLUME_DB := -6.0

var enabled := true
var _player: AudioStreamPlayer
var _tween: Tween


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		enabled = bool(cfg.get_value("audio", "music", true))
	var stream := THEME.duplicate() as AudioStreamOggVorbis
	stream.loop = true
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.volume_db = -60.0
	add_child(_player)


func play_theme() -> void:
	if not enabled:
		return
	if not _player.playing:
		_player.play()
	_fade_to(VOLUME_DB, 1.2)


func fade_out() -> void:
	if _player.playing:
		_fade_to(-60.0, 1.0, true)


## Müziği açar/kapatır, yeni durumu döner.
func toggle() -> bool:
	enabled = not enabled
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", enabled)
	cfg.save(SETTINGS_PATH)
	if enabled:
		play_theme()
	else:
		fade_out()
	return enabled


func _fade_to(db: float, secs: float, stop_after := false) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", db, secs)
	if stop_after:
		_tween.tween_callback(_player.stop)
