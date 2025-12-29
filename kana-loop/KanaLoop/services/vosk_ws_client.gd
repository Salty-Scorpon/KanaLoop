class_name VoskWebSocketClient
extends Node

signal on_partial(text: String)
signal on_final(text: String)
signal on_error(message: String)

const DEFAULT_HOST := "localhost"
const DEFAULT_PORT := 2700
const RECONNECT_BASE_SECONDS := 0.25
const RECONNECT_MAX_SECONDS := 2.0

var _peer: WebSocketPeer
var _ws_url := ""
var _connected := false
var _stop_requested := false
var _reconnect_delay := RECONNECT_BASE_SECONDS
var _next_reconnect_at_msec := 0

func _ready() -> void:
	set_process(false)

func configure(port: int = DEFAULT_PORT, host: String = DEFAULT_HOST) -> void:
	_ws_url = "ws://%s:%d" % [host, port]

func start() -> void:
	_stop_requested = false
	if _ws_url.is_empty():
		configure()
	_attempt_connect()
	set_process(true)

func stop() -> void:
	_stop_requested = true
	set_process(false)
	if _peer:
		_peer.close()
	_peer = null
	_connected = false

func send_json(payload: Dictionary) -> bool:
	if not _is_open():
		on_error.emit("WebSocket is not connected; cannot send payload.")
		return false
	var message := JSON.stringify(payload)
	var err := _peer.send_text(message)
	if err != OK:
		on_error.emit("Failed to send WebSocket payload: %s" % str(err))
		return false
	return true

func _process(_delta: float) -> void:
	if not _peer:
		if _should_reconnect():
			_attempt_connect()
		return
	_peer.poll()
	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			_reset_reconnect()
		_read_packets()
		return
	if state == WebSocketPeer.STATE_CLOSED:
		_handle_close()

func _attempt_connect() -> void:
	_peer = WebSocketPeer.new()
	var err := _peer.connect_to_url(_ws_url)
	if err != OK:
		on_error.emit("Failed to connect to %s: %s" % [_ws_url, str(err)])
		_peer = null
		_schedule_reconnect()

func _read_packets() -> void:
	while _peer and _peer.get_available_packet_count() > 0:
		var packet := _peer.get_packet()
		if not _peer.was_string_packet():
			continue
		_handle_text(packet.get_string_from_utf8())

func _handle_text(message: String) -> void:
	var payload := JSON.parse_string(message)
	if typeof(payload) != TYPE_DICTIONARY:
		on_error.emit("Invalid JSON payload: %s" % message)
		return
	if payload.has("partial"):
		var partial := str(payload["partial"])
		if not partial.is_empty():
			on_partial.emit(partial)
	if payload.has("text"):
		var final_text := str(payload["text"])
		if not final_text.is_empty():
			on_final.emit(final_text)

func _handle_close() -> void:
	var close_code := _peer.get_close_code()
	var close_reason := _peer.get_close_reason()
	if not _stop_requested:
		on_error.emit("WebSocket closed: %s (%s)" % [str(close_code), close_reason])
	_peer = null
	_connected = false
	if not _stop_requested:
		_schedule_reconnect()

func _schedule_reconnect() -> void:
	_next_reconnect_at_msec = Time.get_ticks_msec() + int(_reconnect_delay * 1000.0)
	_reconnect_delay = min(_reconnect_delay * 2.0, RECONNECT_MAX_SECONDS)

func _should_reconnect() -> bool:
	if _stop_requested:
		return false
	return Time.get_ticks_msec() >= _next_reconnect_at_msec

func _reset_reconnect() -> void:
	_reconnect_delay = RECONNECT_BASE_SECONDS
	_next_reconnect_at_msec = 0

func _is_open() -> bool:
	return _peer and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN
