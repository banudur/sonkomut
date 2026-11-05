extends Node
## İstemci tarafı oyun durumu. Sunucudan gelen mesajları dağıtır.

signal room_changed
signal event(msg: Dictionary)
signal error(text: String)
signal settings_changed

const AGE_BANDS := [
	["child", "7-10"],
	["teen", "11-15"],
	["adult", "16-55"],
	["senior", "56-70"],
]
const SETTINGS_PATH := "user://settings.cfg"

var player_id := ""
var room: Dictionary = {}
var hints: Array[String] = []
var last_game_over: Dictionary = {}

var player_name := ""
var age_band := "adult"
var server_url := "ws://192.168.1.10:8000/ws"


func _ready() -> void:
	_load_settings()
	Net.message.connect(_on_message)
	Net.disconnected.connect(_on_disconnected)


# ------------------------------------------------------------ eylemler

func create_room() -> void:
	_save_settings()
	Net.connect_to(server_url)
	Net.send({"type": "create_room", "name": player_name, "age_band": age_band})


func join_room(code: String) -> void:
	_save_settings()
	Net.connect_to(server_url)
	Net.send({"type": "join_room", "code": code, "name": player_name, "age_band": age_band})


func leave() -> void:
	Net.close()
	_clear_room()


func set_age_band(band: String) -> void:
	age_band = band
	_save_settings()
	if not room.is_empty():
		Net.send({"type": "set_age_band", "age_band": band})
	settings_changed.emit()


# ------------------------------------------------------------ sorgular

func phase() -> String:
	return str(room.get("phase", ""))


func is_host() -> bool:
	return player_id != "" and room.get("host_id", "") == player_id


func is_hider() -> bool:
	return player_id != "" and room.get("hider_id", "") == player_id


func players() -> Array:
	return room.get("players", [])


func player(id: String) -> Dictionary:
	for p in players():
		if p.get("id") == id:
			return p
	return {}


func player_name_of(id: String) -> String:
	return str(player(id).get("name", "?"))


func is_senior() -> bool:
	return age_band == "senior"


func age_label(band: String) -> String:
	for b in AGE_BANDS:
		if b[0] == band:
			return "%s yaş" % b[1]
	return band


# ------------------------------------------------------------ iç

func _on_message(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"welcome":
			player_id = str(msg.get("player_id", ""))
		"room_state":
			var prev := phase()
			room = msg
			if prev != phase() and phase() in ["lobby", "hiding"]:
				hints.clear()
			room_changed.emit()
		"game_over":
			last_game_over = msg
		"puzzle_result":
			if msg.get("correct", false) and msg.has("hint"):
				hints.append(str(msg["hint"].get("text", "")))
		"error":
			error.emit(str(msg.get("message", "Bir hata oluştu.")))
		"notice":
			error.emit(str(msg.get("message", "")))
	event.emit(msg)


func _on_disconnected() -> void:
	var was_in_room := not room.is_empty()
	_clear_room()
	error.emit("Sunucu bağlantısı koptu." if was_in_room else "Sunucuya bağlanılamadı. Adresi kontrol et.")


func _clear_room() -> void:
	room = {}
	player_id = ""
	hints.clear()
	room_changed.emit()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	player_name = str(cfg.get_value("player", "name", player_name))
	age_band = str(cfg.get_value("player", "age_band", age_band))
	server_url = str(cfg.get_value("net", "server_url", server_url))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "age_band", age_band)
	cfg.set_value("net", "server_url", server_url)
	cfg.save(SETTINGS_PATH)
