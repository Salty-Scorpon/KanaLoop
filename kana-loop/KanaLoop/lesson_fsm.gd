extends Node

signal state_changed(previous_state: int, new_state: int)
signal state_entered(state: int, context: Dictionary)
signal state_exited(state: int, context: Dictionary)

enum LessonState { IDLE, PROMPT, LISTENING, PROCESSING, FEEDBACK, END }

var state: LessonState = LessonState.IDLE
var lesson_items: Array = []
var current_index: int = -1
var current_item: Variant = null
var last_transcript: String = ""
var last_grade: Dictionary = {}

func get_state() -> LessonState:
	return state

func get_state_name() -> String:
	return LessonState.keys()[state]

func start_lesson(items: Array) -> void:
	lesson_items = items.duplicate()
	last_transcript = ""
	last_grade = {}

	if lesson_items.is_empty():
		current_index = -1
		current_item = null
		_transition_to(LessonState.END, _build_context())
		return

	current_index = 0
	current_item = lesson_items[0]
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
	_transition_to(LessonState.FEEDBACK, _build_context())

func advance(to_next: bool = true) -> void:
	if state != LessonState.FEEDBACK:
		return
	if not to_next:
		_transition_to(LessonState.END, _build_context())
		return

	current_index += 1
	if current_index >= lesson_items.size():
		_transition_to(LessonState.END, _build_context())
		return

	current_item = lesson_items[current_index]
	last_transcript = ""
	last_grade = {}
	_transition_to(LessonState.PROMPT, _build_context())

func reset() -> void:
	lesson_items.clear()
	current_index = -1
	current_item = null
	last_transcript = ""
	last_grade = {}
	_transition_to(LessonState.IDLE, _build_context())

func _build_context() -> Dictionary:
	return {
		"item": current_item,
		"index": current_index,
		"total": lesson_items.size(),
		"transcript": last_transcript,
		"grade": last_grade,
	}

func _transition_to(next_state: LessonState, context: Dictionary) -> void:
	if state == next_state:
		return
	var previous_state := state
	var previous_context := context
	state_exited.emit(previous_state, previous_context)
	state = next_state
	state_changed.emit(previous_state, next_state)
	state_entered.emit(state, context)
