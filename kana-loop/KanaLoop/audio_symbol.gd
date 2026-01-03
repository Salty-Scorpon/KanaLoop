extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel
@onready var choices_grid: GridContainer = $MarginContainer/VBoxContainer/ChoicesGrid
var selected_kana: Array[String] = []
var prompt_order: Array[String] = []
var prompt_index := 0
var active_prompt := ""
var awaiting_answer := false
var choice_buttons: Array[Button] = []

const FEEDBACK_SECONDS := 1.0
const CHOICE_FONT_SIZE := 64
const CHOICE_MULTI_FONT_SIZE := 52

func _ready() -> void:
	selected_kana = KanaState.get_selected_kana()
	prompt_order = selected_kana.duplicate()
	prompt_order.shuffle()
	_start_round()
	back_button.pressed.connect(_on_back_pressed)

func _build_choice_buttons(choices: Array[String]) -> void:
	for child in choices_grid.get_children():
		child.queue_free()
	choice_buttons.clear()
	for kana in choices:
		var button := Button.new()
		button.text = kana
		_apply_choice_font_size(button, kana)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_choice_pressed.bind(kana))
		choices_grid.add_child(button)
		choice_buttons.append(button)

func _start_round() -> void:
	if selected_kana.is_empty():
		feedback_label.text = "No kana selected."
		_set_choices_enabled(false)
		return
	active_prompt = _next_prompt()
	feedback_label.text = "Listen and choose."
	_build_choice_buttons(_build_round_choices(active_prompt))
	_set_choices_enabled(true)
	awaiting_answer = true
	KanaAudio.play_kana_audio(active_prompt)

func _build_round_choices(active_prompt: String) -> Array[String]:
	var choices: Array[String] = [active_prompt]
	if selected_kana.size() < 4:
		for kana in selected_kana:
			if not choices.has(kana):
				choices.append(kana)
	else:
		var distractors: Array[String] = []
		for kana in selected_kana:
			if kana != active_prompt:
				distractors.append(kana)
		distractors.shuffle()
		var limit: int = min(3, distractors.size())
		for i in limit:
			choices.append(distractors[i])
	choices.shuffle()
	return choices

func _next_prompt() -> String:
	if prompt_order.is_empty():
		return ""
	if prompt_index >= prompt_order.size():
		prompt_order.shuffle()
		prompt_index = 0
	var kana := prompt_order[prompt_index]
	prompt_index += 1
	return kana

func _set_choices_enabled(enabled: bool) -> void:
	for button in choice_buttons:
		button.disabled = not enabled

func _on_choice_pressed(kana: String) -> void:
	if not awaiting_answer:
		return
	awaiting_answer = false
	_set_choices_enabled(false)
	if kana == active_prompt:
		feedback_label.text = "Correct!"
	else:
		feedback_label.text = "Not quite. It was %s." % active_prompt
	await get_tree().create_timer(FEEDBACK_SECONDS).timeout
	_start_round()

func _apply_choice_font_size(button: Button, kana: String) -> void:
	var font_size := CHOICE_FONT_SIZE if kana.length() <= 1 else CHOICE_MULTI_FONT_SIZE
	button.add_theme_font_size_override("font_size", font_size)

func _on_back_pressed() -> void:
	awaiting_answer = false
	back_requested.emit()
