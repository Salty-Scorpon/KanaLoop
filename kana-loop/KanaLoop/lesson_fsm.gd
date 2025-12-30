class_name LessonFSM
extends Node

signal state_changed(previous_state: int, new_state: int)
signal state_entered(state: int, context: Dictionary)
signal state_exited(state: int, context: Dictionary)

enum LessonState {
	IDLE,
	PROMPT,
	LISTENING,
	PROCESSING,
	FEEDBACK,
	END,
	ERROR_NO_MIC,
	ERROR_VOSK_UNAVAILABLE
}

var state: LessonState = LessonState.IDLE
var lesson_items: Array = []
var current_index: int = -1
var current_item: Variant = null
var last_transcript: String = ""
var last_grade: Dictionary = {}
var last_error_message: String = ""
var attempt_count: int = 0
var max_attempts: int = 1
var retry_pending: bool = false
@export var default_max_attempts := 2

func get_state() -> LessonState:
	return state

func get_state_name() -> String:
	return LessonState.keys()[state]

func get_context() -> Dictionary:
	return _build_context()

func start_lesson(items: Array) -> void:
	lesson_items = items.duplicate()
	last_transcript = ""
	last_grade = {}
	last_error_message = ""
	attempt_count = 0
	max_attempts = default_max_attempts
	retry_pending = false

	if lesson_items.is_empty():
		current_index = -1
		current_item = null
		_transition_to(LessonState.END, _build_context())
		return

	current_index = 0
	current_item = lesson_items[0]
	max_attempts = _resolve_max_attempts(current_item)
	_transition_to(LessonState.PROMPT, _build_context())

func begin_listening() -> void:
	if state != LessonState.PROMPT:
		return
	_transition_to(LessonState.LISTENING, _build_context())

func submit_transcript(transcript: String, is_final: bool = true) -> void:
	last_transcript = transcript
	if not is_final:
		return
	if state != LessonState.LISTENING:
		return
	_transition_to(LessonState.PROCESSING, _build_context())

func submit_grade(grade: Dictionary) -> void:
	last_grade = grade.duplicate()
	if state != LessonState.PROCESSING:
		return
	_update_retry_state(grade)
	_transition_to(LessonState.FEEDBACK, _build_context())

func advance(to_next: bool = true) -> void:
	if state != LessonState.FEEDBACK:
		return
	if not to_next:
		_transition_to(LessonState.END, _build_context())
		return

	if retry_pending:
		retry_pending = false
		last_transcript = ""
		last_grade = {}
		_transition_to(LessonState.PROMPT, _build_context())
		return

	current_index += 1
	if current_index >= lesson_items.size():
		_transition_to(LessonState.END, _build_context())
		return

	current_item = lesson_items[current_index]
	last_transcript = ""
	last_grade = {}
	attempt_count = 0
	max_attempts = _resolve_max_attempts(current_item)
	retry_pending = false
	_transition_to(LessonState.PROMPT, _build_context())

func reset() -> void:
	lesson_items.clear()
	current_index = -1
	current_item = null
	last_transcript = ""
	last_grade = {}
	last_error_message = ""
	attempt_count = 0
	max_attempts = default_max_attempts
	retry_pending = false
	_transition_to(LessonState.IDLE, _build_context())

func set_error(error_state: LessonState, message: String = "") -> void:
	if error_state != LessonState.ERROR_NO_MIC \
			and error_state != LessonState.ERROR_VOSK_UNAVAILABLE:
		return
	last_error_message = message
	_transition_to(error_state, _build_context())

func _build_context() -> Dictionary:
	var attempts_remaining: int = max(0, max_attempts - attempt_count)
	return {
		"item": current_item,
		"index": current_index,
		"total": lesson_items.size(),
		"transcript": last_transcript,
		"grade": last_grade,
		"attempt_count": attempt_count,
		"max_attempts": max_attempts,
		"attempts_remaining": attempts_remaining,
		"retry_pending": retry_pending,
		"error_message": last_error_message,
		"error_state": state,
	}

func _update_retry_state(grade: Dictionary) -> void:
	var is_correct := _grade_is_correct(grade)
	attempt_count += 1
	if is_correct:
		retry_pending = false
		return
	retry_pending = attempt_count < max_attempts

func _grade_is_correct(grade: Dictionary) -> bool:
	if typeof(grade) != TYPE_DICTIONARY:
		return false
	if grade.has("is_correct"):
		return bool(grade.get("is_correct", false))
	var distance := int(grade.get("distance", 0))
	var score := float(grade.get("score", 0.0))
	return distance == 0 or score >= 1.0

func _resolve_max_attempts(item: Variant) -> int:
	if typeof(item) == TYPE_DICTIONARY and item.has("max_attempts"):
		var value := int(item.get("max_attempts", default_max_attempts))
		return max(1, value)
	return max(1, default_max_attempts)

func _transition_to(next_state: LessonState, context: Dictionary) -> void:
	if state == next_state:
		return
	var previous_state := state
	var previous_context := context
	state_exited.emit(previous_state, previous_context)
	state = next_state
	state_changed.emit(previous_state, next_state)
	state_entered.emit(state, context)
