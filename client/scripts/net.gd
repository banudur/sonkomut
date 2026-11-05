extends Node
## WebSocket istemcisi. Sunucuyla JSON mesajlaşır.

signal connected
signal disconnected
signal message(msg: Dictionary)

var _ws := WebSocketPeer.new()
var _queue: Array[String] = []
var _connecting := false
var _open := false


func connect_to(url: String) -> void:
	close()
	_ws = WebSocketPeer.new()
	# Fotoğraflar base64 olarak gönderiliyor; tampon büyük olmalı.
	_ws.outbound_buffer_size = 4 * 1024 * 1024
	_ws.inbound_buffer_size = 1024 * 1024
	var err := _ws.connect_to_url(url)
	if err != OK:
		push_warning("Bağlantı başlatılamadı: %s" % error_string(err))
		disconnected.emit()
		return
	_connecting = true


## Bilerek kapatma: `disconnected` sinyali gönderilmez.
func close() -> void:
	if _ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws.close()
	_queue.clear()
	_open = false
	_connecting = false


func is_open() -> bool:
	return _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func send(msg: Dictionary) -> void:
	var text := JSON.stringify(msg)
	if is_open():
		_ws.send_text(text)
	else:
		_queue.append(text)


func _process(_delta: float) -> void:
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _open:
			_open = true
			_connecting = false
			for t in _queue:
				_ws.send_text(t)
			_queue.clear()
			connected.emit()
		while _ws.get_available_packet_count() > 0:
			var raw := _ws.get_packet().get_string_from_utf8()
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary:
				message.emit(parsed)
	elif state == WebSocketPeer.STATE_CLOSED and (_open or _connecting):
		_open = false
		_connecting = false
		disconnected.emit()
