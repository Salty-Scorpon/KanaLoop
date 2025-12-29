class_name VoskMicStreamer
extends Node

signal speech_finished
signal error_detected(error_code: int, message: String)

const VOSK_SAMPLE_FORMAT := "16kHz mono PCM16LE"

@export var capture_bus_name := "MicCapture"
@export var target_sample_rate := 16000
@export var silence_threshold := 0.01
@export var min_speech_seconds := 0.3
@export var silence_timeout_seconds := 0.6

var _ws_client: VoskWebSocketClient
var _mic_player: AudioStreamPlayer
var _capture_effect: AudioEffectCapture
var _capture_bus_index := -1
var _input_sample_rate := 0
var _resample_buffer: Array[float] = []
var _resample_pos := 0.0
var _speech_seconds := 0.0
var _silence_seconds := 0.0
var _has_speech := false
var _mic_error_reported := false
var _packet_count := 0

func _ready() -> void:
	set_process(false)

func start_streaming(ws_client: VoskWebSocketClient) -> bool:
	_ws_client = ws_client
	_input_sample_rate = AudioServer.get_mix_rate()
	_mic_error_reported = false
	_packet_count = 0
	print("VoskMicStreamer: starting microphone capture.")
	if not _ensure_capture_bus():
		_ws_client = null
		set_process(false)
		return false
	if not _setup_microphone_player():
		_ws_client = null
		set_process(false)
		return false
	_reset_detection_state()
	set_process(true)
	print("VoskMicStreamer: microphone capture started.")
	return true

func start_listening(ws_client: VoskWebSocketClient, grammar: Array[String]) -> bool:
	var acked := await ws_client.send_grammar_and_wait(grammar)
	if not acked:
		return false
	return start_streaming(ws_client)

func stop_streaming() -> void:
	set_process(false)
	if _mic_player:
		_mic_player.stop()
		_mic_player.queue_free()
		_mic_player = null
	_ws_client = null
	print("VoskMicStreamer: microphone capture stopped.")

func _process(_delta: float) -> void:
	if not _capture_effect or not _ws_client:
		return
	var frames_available := _capture_effect.get_frames_available()
	if frames_available <= 0:
		return
	var frames := _capture_effect.get_buffer(frames_available)
	if frames.is_empty():
		return
	var mono_samples := _to_mono_samples(frames)
	_update_silence_detector(mono_samples)
	var resampled := _resample_to_target(mono_samples)
	if resampled.size() > 0:
		var pcm_bytes := _to_pcm16le(resampled)
		_packet_count += 1
		print(
			"VoskMicStreamer: sending packet %d (frames=%d, resampled=%d, bytes=%d)"
			% [_packet_count, frames.size(), resampled.size(), pcm_bytes.size()]
		)
		_ws_client.send_bytes(pcm_bytes)

func _ensure_capture_bus() -> bool:
	_capture_bus_index = _find_bus_index(capture_bus_name)
	if _capture_bus_index < 0:
		var previous_count := AudioServer.get_bus_count()
		AudioServer.add_bus(previous_count)
		_capture_bus_index = _find_bus_index(capture_bus_name)
		if _capture_bus_index < 0 and AudioServer.get_bus_count() > previous_count:
			_capture_bus_index = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(_capture_bus_index, capture_bus_name)
	if _capture_bus_index < 0:
		_report_no_mic("Capture bus not found.")
		return false
	_capture_effect = _get_capture_effect(_capture_bus_index)
	if not _capture_effect:
		_capture_effect = AudioEffectCapture.new()
		AudioServer.add_bus_effect(_capture_bus_index, _capture_effect, 0)
		_capture_effect = _get_capture_effect(_capture_bus_index)
	if not _capture_effect:
		_report_no_mic("Capture effect unavailable.")
		return false
	return true

func _setup_microphone_player() -> bool:
	if _mic_player:
		_mic_player.queue_free()
	_mic_player = AudioStreamPlayer.new()
	var mic_stream := AudioStreamMicrophone.new()
	if mic_stream == null:
		_mic_player.queue_free()
		_mic_player = null
		_report_no_mic("AudioStreamMicrophone unavailable.")
		return false
	_mic_player.stream = mic_stream
	_mic_player.bus = capture_bus_name
	add_child(_mic_player)
	_mic_player.play()
	return true

func _find_bus_index(bus_name: String) -> int:
	for index in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(index) == bus_name:
			return index
	return -1

func _get_capture_effect(bus_index: int) -> AudioEffectCapture:
	for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect := AudioServer.get_bus_effect(bus_index, effect_index)
		if effect is AudioEffectCapture:
			return effect
	return null

func _to_mono_samples(frames: PackedVector2Array) -> PackedFloat32Array:
	var mono := PackedFloat32Array()
	mono.resize(frames.size())
	for i in range(frames.size()):
		var frame := frames[i]
		mono[i] = (frame.x + frame.y) * 0.5
	return mono

func _resample_to_target(input_samples: PackedFloat32Array) -> PackedFloat32Array:
	if input_samples.is_empty():
		return PackedFloat32Array()
	var output := PackedFloat32Array()
	if _input_sample_rate == target_sample_rate:
		output.resize(input_samples.size())
		for i in range(input_samples.size()):
			output[i] = input_samples[i]
		return output
	for sample: float in input_samples:
		_resample_buffer.append(sample)
	var step := float(_input_sample_rate) / float(target_sample_rate)
	while _resample_pos + 1.0 < _resample_buffer.size():
		var index := int(_resample_pos)
		var next_index := index + 1
		var frac := _resample_pos - float(index)
		var sample: float = lerp(_resample_buffer[index], _resample_buffer[next_index], frac)
		output.append(sample)
		_resample_pos += step
	var drop := int(_resample_pos)
	if drop > 0:
		_resample_buffer = _resample_buffer.slice(drop, _resample_buffer.size())
		_resample_pos -= float(drop)
	return output

func _to_pcm16le(samples: PackedFloat32Array) -> PackedByteArray:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in range(samples.size()):
		var clamped: float = clamp(samples[i], -1.0, 1.0)
		var value := int(round(clamped * 32767.0))
		pcm.encode_s16(i * 2, value)
	return pcm

func _update_silence_detector(samples: PackedFloat32Array) -> void:
	if samples.is_empty() or _input_sample_rate <= 0:
		return
	var rms := _calculate_rms(samples)
	var duration := float(samples.size()) / float(_input_sample_rate)
	if rms >= silence_threshold:
		_has_speech = true
		_speech_seconds += duration
		_silence_seconds = 0.0
		return
	if _has_speech and _speech_seconds >= min_speech_seconds:
		_silence_seconds += duration
		if _silence_seconds >= silence_timeout_seconds:
			_request_final()
			stop_streaming()
			speech_finished.emit()

func _calculate_rms(samples: PackedFloat32Array) -> float:
	var sum := 0.0
	for sample in samples:
		sum += sample * sample
	return sqrt(sum / float(samples.size()))

func _request_final() -> void:
	if _ws_client:
		_ws_client.send_json({"type": "final"})

func _reset_detection_state() -> void:
	_resample_buffer.clear()
	_resample_pos = 0.0
	_speech_seconds = 0.0
	_silence_seconds = 0.0
	_has_speech = false

func _report_no_mic(message: String) -> void:
	if _mic_error_reported:
		return
	_mic_error_reported = true
	push_warning(message)
	error_detected.emit(LessonFSM.LessonState.ERROR_NO_MIC, message)
