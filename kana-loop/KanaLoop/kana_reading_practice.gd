extends Control

signal back_requested

@export var fsm: LessonFSM
@export var speech_controller: LessonSpeechController
@export var mic_streamer: VoskMicStreamer
@export var kana_label: Label
@export var status_label: Label
@export var transcript_label: Label
@export var debug_label: RichTextLabel
@export var animation_player: AnimationPlayer
@export var debug_speech := false

@onready var back_button: Button = get_node_or_null("MarginContainer/VBoxContainer/BackButton")

const PROMPT_DELAY_SECONDS := 0.6
const FEEDBACK_DURATION_SECONDS := 1.2

var _prompt_timer: SceneTreeTimer
var _feedback_timer: SceneTreeTimer
var _vosk_service_manager: VoskServiceManager
var _active_kana: Array[String] = []
var _debug_service_status := "unknown"
var _debug_mic_status := "stopped"
var _debug_last_transcript := ""
var _debug_expected_kana := ""

func _ready() -> void:
	if kana_label == null and has_node("KanaLabel"):
		kana_label = $KanaLabel
	if status_label == null and has_node("StatusLabel"):
		status_label = $StatusLabel
	if transcript_label == null and has_node("TranscriptLabel"):
		transcript_label = $TranscriptLabel
	if debug_label == null and has_node("DebugSpeechLabel"):
		debug_label = $DebugSpeechLabel
	if animation_player == null and has_node("AnimationPlayer"):
		animation_player = $AnimationPlayer
	if animation_player and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	_update_debug_label()

	_ensure_fsm()
	_ensure_speech_nodes()

	if fsm and not fsm.state_entered.is_connected(_on_state_entered):
		fsm.state_entered.connect(_on_state_entered)

	if mic_streamer and not mic_streamer.error_detected.is_connected(_on_mic_error):
		mic_streamer.error_detected.connect(_on_mic_error)

	_vosk_service_manager = get_node_or_null("/root/VoskServiceAutoload")
	if _vosk_service_manager and not _vosk_service_manager.unavailable.is_connected(_on_vosk_unavailable):
		_vosk_service_manager.unavailable.connect(_on_vosk_unavailable)
	if _vosk_service_manager and not _vosk_service_manager.service_started.is_connected(_on_vosk_service_started):
		_vosk_service_manager.service_started.connect(_on_vosk_service_started)

	_start_lesson_from_selection()

func _ensure_fsm() -> void:
	if fsm != null:
		return
	if has_node("LessonFSM"):
		fsm = $LessonFSM
		return
	fsm = LessonFSM.new()
	add_child(fsm)

func _ensure_speech_nodes() -> void:
	if mic_streamer == null:
		mic_streamer = VoskMicStreamer.new()
		add_child(mic_streamer)
	if speech_controller == null:
		speech_controller = LessonSpeechController.new()
		add_child(speech_controller)
	if speech_controller and speech_controller.fsm == null and fsm:
		speech_controller.fsm = fsm
	if speech_controller and speech_controller.ws_client == null:
		var ws_client := VoskWebSocketClient.new()
		add_child(ws_client)
		ws_client.configure()
		ws_client.start()
		speech_controller.set_ws_client(ws_client)
	elif speech_controller and speech_controller.ws_client:
		speech_controller.ws_client.start()

func _start_lesson_from_selection() -> void:
	if fsm == null:
		return
	_active_kana = KanaState.get_selected_kana()
	if _active_kana.is_empty():
		_active_kana = KanaState.DEFAULT_KANA.duplicate()
	if speech_controller and speech_controller.debug_speech:
		print("KanaReadingPractice: active kana list: %s" % _active_kana)
	var items: Array = []
	for kana in _active_kana:
		items.append({
			"kana": kana,
		})
	fsm.start_lesson(items)

func _on_state_entered(state: int, context: Dictionary) -> void:
	_clear_timers()
	_set_listening_active(state == LessonFSM.LessonState.LISTENING, context)
	match state:
		LessonFSM.LessonState.PROMPT:
			_set_kana_from_context(context)
			_set_status_text("Get ready")
			_set_transcript_text(_format_transcript(""))
			_play_animation("IdleGlow")
			_start_prompt_delay()
		LessonFSM.LessonState.LISTENING:
			_set_kana_from_context(context)
			_set_status_text("Speak now")
			_set_transcript_text(_format_transcript(""))
			_play_animation("IdleGlow")
		LessonFSM.LessonState.PROCESSING:
			var transcript := str(context.get("transcript", ""))
			print("KanaReadingPractice: processing transcript: %s" % transcript)
			_set_debug_last_transcript(transcript)
			if transcript.strip_edges().is_empty():
				_set_status_text("Checking...")
			else:
				_set_status_text("Checking... Heard: %s" % transcript)
			_set_transcript_text(_format_transcript(transcript))
		LessonFSM.LessonState.FEEDBACK:
			_set_kana_from_context(context)
			_show_feedback(context)
			var feedback_transcript := str(context.get("transcript", ""))
			_set_debug_last_transcript(feedback_transcript)
			_set_transcript_text(_format_transcript(feedback_transcript))
			_start_feedback_delay()
		LessonFSM.LessonState.END:
			_set_status_text("Lesson complete")
			var end_transcript := str(context.get("transcript", ""))
			_set_debug_last_transcript(end_transcript)
			_set_transcript_text(_format_transcript(end_transcript))
		LessonFSM.LessonState.IDLE:
			_set_status_text("")
			_set_transcript_text(_format_transcript(""))
		LessonFSM.LessonState.ERROR_NO_MIC:
			_set_status_text("Microphone not detected")
			var mic_transcript := str(context.get("transcript", ""))
			_set_debug_last_transcript(mic_transcript)
			_set_transcript_text(_format_transcript(mic_transcript))
		LessonFSM.LessonState.ERROR_VOSK_UNAVAILABLE:
			_set_status_text("Speech service unavailable")
			var service_transcript := str(context.get("transcript", ""))
			_set_debug_last_transcript(service_transcript)
			_set_transcript_text(_format_transcript(service_transcript))

func _set_kana_from_context(context: Dictionary) -> void:
	if kana_label == null:
		return
	var item: Variant = context.get("item", {})
	var kana := ""
	if typeof(item) == TYPE_DICTIONARY:
		kana = str(item.get("kana", ""))
	elif item != null:
		kana = str(item)
	kana_label.text = kana
	_set_debug_expected_kana(kana)

func _set_status_text(text: String) -> void:
	if status_label:
		status_label.text = text

func _set_transcript_text(text: String) -> void:
	if transcript_label:
		transcript_label.text = text

func _update_debug_label() -> void:
	if not debug_speech or debug_label == null:
		return
	var transcript_text := _debug_last_transcript
	if transcript_text.strip_edges().is_empty():
		transcript_text = "—"
	var expected_text := _debug_expected_kana
	if expected_text.strip_edges().is_empty():
		expected_text = "—"
	debug_label.text = (
		"Debug speech\n"
		+ "Service: %s\n" % _debug_service_status
		+ "Mic: %s\n" % _debug_mic_status
		+ "Expected: %s\n" % expected_text
		+ "Last transcript: %s" % transcript_text
	)

func _set_debug_service_status(status: String) -> void:
	_debug_service_status = status
	_update_debug_label()

func _set_debug_mic_status(status: String) -> void:
	_debug_mic_status = status
	_update_debug_label()

func _set_debug_last_transcript(transcript: String) -> void:
	_debug_last_transcript = transcript
	_update_debug_label()

func _set_debug_expected_kana(kana: String) -> void:
	_debug_expected_kana = kana
	_update_debug_label()

func _format_transcript(value: Variant) -> String:
	var transcript := str(value).strip_edges()
	if transcript.is_empty():
		return "Transcript: —"
	return "Transcript: %s" % transcript

func _show_feedback(context: Dictionary) -> void:
	var is_correct := _is_grade_correct(context)
	var retry_pending := bool(context.get("retry_pending", false))
	var attempt_count := int(context.get("attempt_count", 0))
	var max_attempts := int(context.get("max_attempts", 0))
	if is_correct:
		_set_status_text("Correct!")
	elif retry_pending:
		if max_attempts > 0:
			_set_status_text("Try again (%d/%d)" % [attempt_count, max_attempts])
		else:
			_set_status_text("Try again")
	else:
		_set_status_text("Incorrect")
	_play_animation(_feedback_animation_name(is_correct))

func _start_prompt_delay() -> void:
	if fsm == null:
		return
	if PROMPT_DELAY_SECONDS <= 0.0:
		fsm.begin_listening()
		return
	_prompt_timer = get_tree().create_timer(PROMPT_DELAY_SECONDS)
	await _prompt_timer.timeout
	if fsm and fsm.get_state() == LessonFSM.LessonState.PROMPT:
		fsm.begin_listening()

func _start_feedback_delay() -> void:
	if fsm == null:
		return
	if FEEDBACK_DURATION_SECONDS <= 0.0:
		fsm.advance(true)
		return
	_feedback_timer = get_tree().create_timer(FEEDBACK_DURATION_SECONDS)
	await _feedback_timer.timeout
	if fsm and fsm.get_state() == LessonFSM.LessonState.FEEDBACK:
		fsm.advance(true)

func _clear_timers() -> void:
	_prompt_timer = null
	_feedback_timer = null

func _set_listening_active(should_listen: bool, context: Dictionary) -> void:
	if mic_streamer == null:
		return
	if not should_listen:
		_stop_mic_streaming()
		return
	if speech_controller == null or speech_controller.ws_client == null:
		return
	var grammar := _build_grammar(context)
	if grammar.is_empty():
		if not mic_streamer.start_streaming(speech_controller.ws_client):
			_set_debug_mic_status("error")
			_handle_error(LessonFSM.LessonState.ERROR_NO_MIC)
		else:
			_set_debug_mic_status("streaming")
		return
	_start_listening_with_grammar(speech_controller.ws_client, grammar)

func _start_listening_with_grammar(ws_client: VoskWebSocketClient, grammar: Array[String]) -> void:
	if not ws_client.send_grammar(grammar):
		return
	if fsm == null or fsm.get_state() != LessonFSM.LessonState.LISTENING:
		return
	if not mic_streamer.start_streaming(ws_client):
		_set_debug_mic_status("error")
		_handle_error(LessonFSM.LessonState.ERROR_NO_MIC)
		return
	_set_debug_mic_status("streaming")

func _play_animation(name: String) -> void:
	if animation_player == null:
		return
	if animation_player.has_animation(name):
		animation_player.play(name)

func _build_grammar(context: Dictionary) -> Array[String]:
	var item: Variant = context.get("item", null)
	if typeof(item) == TYPE_DICTIONARY:
		var grammar_value: Variant = item.get("grammar", null)
		if typeof(grammar_value) == TYPE_ARRAY:
			return Array(grammar_value, TYPE_STRING, "", null)
		var kana := str(item.get("kana", "")).strip_edges()
		if not kana.is_empty():
			return [kana]
	elif item != null:
		var value := str(item).strip_edges()
		if not value.is_empty():
			return [value]
	return []

func _is_grade_correct(context: Dictionary) -> bool:
	var grade: Dictionary = context.get("grade", {})
	if typeof(grade) == TYPE_DICTIONARY:
		return bool(grade.get("is_correct", false))
	return false

func _feedback_animation_name(is_correct: bool) -> String:
	return "feedback_correct" if is_correct else "feedback_incorrect"

func _on_animation_finished(name: StringName) -> void:
	if fsm == null:
		return
	if fsm.get_state() != LessonFSM.LessonState.FEEDBACK:
		return
	if name == "feedback_correct" or name == "feedback_incorrect":
		_play_animation("IdleGlow")

func _handle_error(error_state: LessonFSM.LessonState) -> void:
	if fsm == null:
		return
	_stop_mic_streaming()
	fsm.set_error(error_state)

func _on_mic_error(error_code: int, _message: String) -> void:
	if fsm == null:
		return
	if error_code == LessonFSM.LessonState.ERROR_NO_MIC:
		_handle_error(LessonFSM.LessonState.ERROR_NO_MIC)

func _on_vosk_unavailable(_reason: String) -> void:
	_set_debug_service_status("unavailable")
	_handle_error(LessonFSM.LessonState.ERROR_VOSK_UNAVAILABLE)

func _on_vosk_service_started(_pid: int, _path: String) -> void:
	_set_debug_service_status("ready")
	_set_status_text("Speech service ready")

func _stop_mic_streaming() -> void:
	if mic_streamer:
		mic_streamer.stop_streaming()
		_set_debug_mic_status("stopped")

func _on_back_pressed() -> void:
	_stop_mic_streaming()
	back_requested.emit()
