class_name VoskWebSocketClient
extends Node

signal on_partial(text: String)
signal on_final(text: String)
signal on_error(message: String)
signal grammar_acknowledged(success: bool)

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

func send_bytes(payload: PackedByteArray) -> bool:
	if not _is_open():
		on_error.emit("WebSocket is not connected; cannot send payload.")
		return false
	var err := _peer.send(payload)
	if err != OK:
		on_error.emit("Failed to send WebSocket payload: %s" % str(err))
		return false
	return true

func send_grammar(words: Array[String]) -> bool:
	return send_json({
		"type": "set_grammar",
		"grammar": words,
	})

func send_grammar_and_wait(words: Array[String]) -> bool:
	if words.is_empty():
		return true
	if not send_grammar(words):
		return false
	var success: bool = await grammar_acknowledged
	return success

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
	var payload: Variant = JSON.parse_string(message)
	if typeof(payload) != TYPE_DICTIONARY:
		on_error.emit("Invalid JSON payload: %s" % message)
		return
	var payload_dict: Dictionary = payload
	if payload_dict.has("type"):
		_handle_typed_payload(payload_dict)
		return
	if payload_dict.has("partial"):
		_emit_partial(str(payload_dict["partial"]))
	if payload_dict.has("text"):
		_emit_final(str(payload_dict["text"]))

func _handle_typed_payload(payload: Dictionary) -> void:
	var payload_type := str(payload.get("type", ""))
	if payload_type == "partial":
		var result := _extract_result_payload(payload)
		_emit_partial(str(result.get("partial", "")))
		return
	if payload_type == "final":
		var result := _extract_result_payload(payload)
		_emit_final(str(result.get("text", "")))
		return
	if payload_type == "grammar_ack":
		var ok := bool(payload.get("ok", false))
		grammar_acknowledged.emit(ok)
		return
	on_error.emit("Unhandled payload type: %s" % payload_type)

func _extract_result_payload(payload: Dictionary) -> Dictionary:
	var result: Variant = payload.get("result", {})
	if typeof(result) == TYPE_DICTIONARY:
		return result as Dictionary
	return {}

func _emit_partial(text: String) -> void:
	if text.is_empty():
		return
	on_partial.emit(text)

func _emit_final(text: String) -> void:
	if text.is_empty():
		return
	on_final.emit(text)

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
