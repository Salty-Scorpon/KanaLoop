extends Control

@export var fsm: LessonFSM
@export var speech_controller: LessonSpeechController
@export var kana_label: Label
@export var status_label: Label
@export var animation_player: AnimationPlayer
@export var prompt_delay_seconds := 0.6
@export var feedback_duration_seconds := 1.2

var _prompt_timer: SceneTreeTimer
var _feedback_timer: SceneTreeTimer

func _ready() -> void:
	if kana_label == null and has_node("KanaLabel"):
		kana_label = $KanaLabel
	if status_label == null and has_node("StatusLabel"):
		status_label = $StatusLabel
	if animation_player == null and has_node("AnimationPlayer"):
		animation_player = $AnimationPlayer

	if speech_controller and speech_controller.fsm == null and fsm:
		speech_controller.fsm = fsm

	if fsm and not fsm.state_entered.is_connected(_on_state_entered):
		fsm.state_entered.connect(_on_state_entered)

func _on_state_entered(state: int, context: Dictionary) -> void:
	_clear_timers()
	match state:
		LessonFSM.LessonState.PROMPT:
			_set_kana_from_context(context)
			_set_status_text("Get ready")
			_play_animation("IdleGlow")
			_start_prompt_delay()
		LessonFSM.LessonState.LISTENING:
			_set_kana_from_context(context)
			_set_status_text("Speak now")
			_play_animation("IdleGlow")
		LessonFSM.LessonState.PROCESSING:
			_set_status_text("Checking...")
		LessonFSM.LessonState.FEEDBACK:
			_set_kana_from_context(context)
			_show_feedback(context)
			_start_feedback_delay()
		LessonFSM.LessonState.END:
			_set_status_text("Lesson complete")
		LessonFSM.LessonState.IDLE:
			_set_status_text("")

func _set_kana_from_context(context: Dictionary) -> void:
	if kana_label == null:
		return
	var item := context.get("item", {})
	var kana := ""
	if typeof(item) == TYPE_DICTIONARY:
		kana = str(item.get("kana", ""))
	elif item != null:
		kana = str(item)
	kana_label.text = kana

func _set_status_text(text: String) -> void:
	if status_label:
		status_label.text = text

func _show_feedback(context: Dictionary) -> void:
	var grade := context.get("grade", {})
	var is_correct := false
	if typeof(grade) == TYPE_DICTIONARY:
		is_correct = bool(grade.get("is_correct", false))
	if is_correct:
		_set_status_text("Correct!")
		_play_animation("CorrectFeedback")
	else:
		_set_status_text("Try again")
		_play_animation("TryAgainFeedback")

func _start_prompt_delay() -> void:
	if fsm == null:
		return
	if prompt_delay_seconds <= 0.0:
		fsm.begin_listening()
		return
	_prompt_timer = get_tree().create_timer(prompt_delay_seconds)
	await _prompt_timer.timeout
	if fsm and fsm.get_state() == LessonFSM.LessonState.PROMPT:
		fsm.begin_listening()

func _start_feedback_delay() -> void:
	if fsm == null:
		return
	if feedback_duration_seconds <= 0.0:
		fsm.advance(true)
		return
	_feedback_timer = get_tree().create_timer(feedback_duration_seconds)
	await _feedback_timer.timeout
	if fsm and fsm.get_state() == LessonFSM.LessonState.FEEDBACK:
		fsm.advance(true)

func _clear_timers() -> void:
	_prompt_timer = null
	_feedback_timer = null

func _play_animation(name: String) -> void:
	if animation_player == null:
		return
	if animation_player.has_animation(name):
		animation_player.play(name)
