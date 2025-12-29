class_name VoskServiceManager
extends Node

signal ready

const WS_URL := "ws://127.0.0.1:2700"
const CONNECT_TIMEOUT_SECONDS := 2.0
const MAX_RETRIES := 6
const BACKOFF_BASE_SECONDS := 0.25
const BACKOFF_MAX_SECONDS := 2.0

var _service_pid := -1
var _is_ready := false
var _is_starting := false

func _ready() -> void:
	ensure_service_ready()

func is_ready() -> bool:
	return _is_ready

func can_enter_listening() -> bool:
	return _is_ready

func wait_until_ready() -> void:
	if _is_ready:
		return
	await ready

func ensure_service_ready() -> void:
	if _is_starting or _is_ready:
		return
	_is_starting = true
	call_deferred("_start_or_connect")

func _start_or_connect() -> void:
	if _is_ready:
		_is_starting = false
		return
	var running := await _probe_websocket(CONNECT_TIMEOUT_SECONDS)
	if running:
		_mark_ready()
		return
	_start_service_process()
	await _wait_for_ready_with_backoff()
	_is_starting = false

func _start_service_process() -> void:
	var service_path := RuntimePaths.resolve_vosk_service_path()
	if service_path.is_empty() or not FileAccess.file_exists(service_path):
		push_warning("Vosk service binary is missing, cannot launch.")
		return
	_service_pid = OS.create_process(service_path, PackedStringArray())
	if _service_pid <= 0:
		push_warning("Failed to launch Vosk service at %s" % service_path)

func _wait_for_ready_with_backoff() -> void:
	for attempt in range(MAX_RETRIES):
		if await _probe_websocket(CONNECT_TIMEOUT_SECONDS):
			_mark_ready()
			return
		var delay := min(BACKOFF_BASE_SECONDS * pow(2.0, float(attempt)), BACKOFF_MAX_SECONDS)
		await get_tree().create_timer(delay).timeout
	push_warning("Vosk service did not become ready after retries.")

func _probe_websocket(timeout_seconds: float) -> bool:
	var peer := WebSocketPeer.new()
	var err := peer.connect_to_url(WS_URL)
	if err != OK:
		return false
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		peer.poll()
		var state := peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			peer.close()
			return true
		if state == WebSocketPeer.STATE_CLOSED:
			return false
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	peer.close()
	return false

func _mark_ready() -> void:
	if _is_ready:
		return
	_is_ready = true
	ready.emit()

func _exit_tree() -> void:
	if _service_pid > 0 and OS.is_process_running(_service_pid):
		OS.kill(_service_pid)
