class_name LessonSpeechController
extends Node

@export var fsm: LessonFSM
@export var ws_client: VoskWebSocketClient
@export var grading_target: Node
@export var grading_method := "grade_transcript"
@export var debug_speech := false

const MAX_PARTIAL_HISTORY := 30

var _partial_transcripts: Array[String] = []

func _ready() -> void:
	if ws_client:
		_bind_ws_client(ws_client)
	if fsm and not fsm.state_entered.is_connected(_on_state_entered):
		fsm.state_entered.connect(_on_state_entered)

func set_ws_client(client: VoskWebSocketClient) -> void:
	if ws_client == client:
		return
	_unbind_ws_client()
	ws_client = client
	if ws_client:
		_bind_ws_client(ws_client)

func _bind_ws_client(client: VoskWebSocketClient) -> void:
	if not client.on_partial.is_connected(_on_partial):
		client.on_partial.connect(_on_partial)
	if not client.on_final.is_connected(_on_final):
		client.on_final.connect(_on_final)

func _unbind_ws_client() -> void:
	if not ws_client:
		return
	if ws_client.on_partial.is_connected(_on_partial):
		ws_client.on_partial.disconnect(_on_partial)
	if ws_client.on_final.is_connected(_on_final):
		ws_client.on_final.disconnect(_on_final)

func _on_partial(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	_track_partial(trimmed)
	_submit_transcript(trimmed, false)

func _on_final(text: String) -> void:
	var trimmed := text.strip_edges()
	var candidates := _collect_transcript_candidates(trimmed)
	if candidates.is_empty():
		return
	var best_transcript := _select_best_candidate(candidates)
	var grade := _request_grade(best_transcript)
	if not grade.get("is_correct", false):
		_reset_partial_buffer()
		return
	_submit_transcript(best_transcript, true)
	_submit_grade(grade)
	_reset_partial_buffer()

func _submit_transcript(text: String, is_final: bool) -> void:
	if fsm == null:
		push_warning("LessonSpeechController requires a LessonFSM to submit transcripts.")
		return
	fsm.submit_transcript(text, is_final)

func _submit_grade(grade: Dictionary) -> void:
	if fsm == null:
		push_warning("LessonSpeechController requires a LessonFSM to submit grades.")
		return
	if grade.is_empty():
		return
	fsm.submit_grade(grade)

func _request_grade(text: String) -> Dictionary:
	var normalized := GradingUtils.normalize_transcript(text)
	if grading_target and grading_target.has_method(grading_method):
		var result: Variant = grading_target.call(grading_method, normalized, _get_context())
		if typeof(result) == TYPE_DICTIONARY:
			return result
	return _default_grade(text, normalized)

func _track_partial(text: String) -> void:
	if text.is_empty():
		return
	if _partial_transcripts.size() >= MAX_PARTIAL_HISTORY:
		_partial_transcripts.pop_front()
	_partial_transcripts.append(text)

func _collect_transcript_candidates(final_text: String) -> Array[String]:
	var candidates: Array[String] = []
	var seen: Dictionary = {}
	for partial in _partial_transcripts:
		if partial.is_empty():
			continue
		if seen.has(partial):
			continue
		seen[partial] = true
		candidates.append(partial)
	if not final_text.is_empty() and not seen.has(final_text):
		candidates.append(final_text)
	return candidates

func _select_best_candidate(candidates: Array[String]) -> String:
	if candidates.is_empty():
		return ""
	var expected := _get_expected_text()
	if expected.strip_edges().is_empty():
		return candidates[candidates.size() - 1]
	var normalized_expected := GradingUtils.normalize_transcript(expected)
	var best_text := candidates[0]
	var best_score := -1.0
	var best_distance := 2147483647
	for candidate in candidates:
		var normalized := GradingUtils.normalize_transcript(candidate)
		var grade := GradingUtils.grade_transcript(normalized, normalized_expected)
		var score := float(grade.get("score", -1.0))
		var distance := int(grade.get("distance", 2147483647))
		if score > best_score or (is_equal_approx(score, best_score) and distance < best_distance):
			best_score = score
			best_distance = distance
			best_text = candidate
	return best_text

func _get_expected_text() -> String:
	var context := _get_context()
	var item: Variant = context.get("item", {})
	if typeof(item) == TYPE_DICTIONARY:
		return str(item.get("kana", ""))
	if item != null:
		return str(item)
	return ""

func _reset_partial_buffer() -> void:
	_partial_transcripts.clear()

func _on_state_entered(state: int, _context: Dictionary) -> void:
	if state in [
		LessonFSM.LessonState.PROMPT,
		LessonFSM.LessonState.LISTENING,
		LessonFSM.LessonState.FEEDBACK,
		LessonFSM.LessonState.END,
		LessonFSM.LessonState.IDLE,
		LessonFSM.LessonState.ERROR_NO_MIC,
		LessonFSM.LessonState.ERROR_VOSK_UNAVAILABLE,
	]:
		_reset_partial_buffer()

func _default_grade(text: String, normalized_text: String) -> Dictionary:
	var context := _get_context()
	var item: Variant = context.get("item", {})
	var expected := ""
	if typeof(item) == TYPE_DICTIONARY:
		expected = str(item.get("kana", ""))
	var normalized_expected := GradingUtils.normalize_transcript(expected)
	var grade := GradingUtils.grade_transcript(normalized_text, normalized_expected)
	grade["transcript"] = text
	grade["expected"] = expected
	grade["transcript_normalized"] = normalized_text
	grade["expected_normalized"] = normalized_expected
	if debug_speech:
		print(
			"LessonSpeechController: grading transcript. expected=%s transcript=%s normalized_expected=%s normalized_transcript=%s is_correct=%s"
			% [
				expected,
				text,
				normalized_expected,
				normalized_text,
				grade.get("is_correct", false),
			]
		)
	return grade

func _get_context() -> Dictionary:
	if fsm == null:
		return {}
	return fsm.get_context()
