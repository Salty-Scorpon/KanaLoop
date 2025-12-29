class_name LessonSpeechController
extends Node

@export var fsm: LessonFSM
@export var ws_client: VoskWebSocketClient
@export var grading_target: Node
@export var grading_method := "grade_transcript"

func _ready() -> void:
	if ws_client:
		_bind_ws_client(ws_client)

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
	_submit_transcript(trimmed, false)

func _on_final(text: String) -> void:
	var trimmed := text.strip_edges()
	_submit_transcript(trimmed, true)
	var grade := _request_grade(trimmed)
	_submit_grade(grade)

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
	return grade

func _get_context() -> Dictionary:
	if fsm == null:
		return {}
	return fsm.get_context()
