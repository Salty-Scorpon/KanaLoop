extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var word_label: Label = $MarginContainer/VBoxContainer/WordLabel
@onready var sentence_jp_label: Label = $MarginContainer/VBoxContainer/SentencePanel/SentenceVBox/SentenceJP
@onready var sentence_kana_label: Label = $MarginContainer/VBoxContainer/SentencePanel/SentenceVBox/SentenceKana
@onready var sentence_en_label: Label = $MarginContainer/VBoxContainer/SentencePanel/SentenceVBox/SentenceEN
@onready var response_input: LineEdit = $MarginContainer/VBoxContainer/ResponseRow/ResponseInput
@onready var submit_button: Button = $MarginContainer/VBoxContainer/ResponseRow/SubmitButton
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel
@onready var replay_button: Button = $MarginContainer/VBoxContainer/ControlsRow/ReplayAudioButton
@onready var kana_toggle: CheckBox = $MarginContainer/VBoxContainer/ControlsRow/KanaToggle
@onready var dyslexia_toggle: CheckBox = $MarginContainer/VBoxContainer/ControlsRow/DyslexiaToggle

const EXPECTED_RESPONSE := "mizu"
const DYSLEXIA_FONT_SCALE := 1.15
const DYSLEXIA_LINE_SPACING := 6

var base_font_sizes: Dictionary = {}
var base_line_spacings: Dictionary = {}

func _ready() -> void:
	if word_label != null and word_label.text.is_empty():
		word_label.text = "水"
	if sentence_jp_label != null:
		sentence_jp_label.text = "水をください。"
	if sentence_kana_label != null:
		sentence_kana_label.text = "みずをください。"
	if sentence_en_label != null:
		sentence_en_label.text = "Please give me water."
	if feedback_label != null and feedback_label.text.is_empty():
		feedback_label.text = "Type the response and submit."

	_cache_text_styles()
	_apply_kana_visibility(kana_toggle.button_pressed if kana_toggle != null else true)

	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
	if replay_button != null:
		replay_button.pressed.connect(_on_replay_audio)
	if submit_button != null:
		submit_button.pressed.connect(_on_submit_pressed)
	if response_input != null:
		response_input.text_submitted.connect(_on_response_submitted)
	if kana_toggle != null:
		kana_toggle.toggled.connect(_on_kana_toggle)
	if dyslexia_toggle != null:
		dyslexia_toggle.toggled.connect(_on_dyslexia_toggled)

	_configure_focus_order()
	if response_input != null:
		response_input.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_submit_response()
			return
		if event.keycode == KEY_R and event.ctrl_pressed:
			_on_replay_audio()
			return
		if event.keycode == KEY_K and event.ctrl_pressed:
			_toggle_kana()
			return

func _configure_focus_order() -> void:
	var focusables: Array[Control] = []
	if response_input != null:
		focusables.append(response_input)
	if submit_button != null:
		focusables.append(submit_button)
	if replay_button != null:
		focusables.append(replay_button)
	if kana_toggle != null:
		focusables.append(kana_toggle)
	if dyslexia_toggle != null:
		focusables.append(dyslexia_toggle)
	if back_button != null:
		focusables.append(back_button)

	if focusables.is_empty():
		return

	for index in range(focusables.size()):
		var control := focusables[index]
		control.focus_mode = Control.FOCUS_ALL
		var next_index := (index + 1) % focusables.size()
		var prev_index := (index - 1 + focusables.size()) % focusables.size()
		control.focus_next = control.get_path_to(focusables[next_index])
		control.focus_previous = control.get_path_to(focusables[prev_index])

func _cache_text_styles() -> void:
	for node in _get_text_nodes():
		base_font_sizes[node] = node.get_theme_font_size("font_size")
		if node is Label:
			base_line_spacings[node] = node.get_theme_constant("line_spacing")

func _get_text_nodes() -> Array[Control]:
	var nodes: Array[Control] = []
	if word_label != null:
		nodes.append(word_label)
	if sentence_jp_label != null:
		nodes.append(sentence_jp_label)
	if sentence_kana_label != null:
		nodes.append(sentence_kana_label)
	if sentence_en_label != null:
		nodes.append(sentence_en_label)
	if feedback_label != null:
		nodes.append(feedback_label)
	if response_input != null:
		nodes.append(response_input)
	return nodes

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_replay_audio() -> void:
	if feedback_label != null:
		feedback_label.text = "Replaying audio prompt..."

func _on_submit_pressed() -> void:
	_submit_response()

func _on_response_submitted(_text: String) -> void:
	_submit_response()

func _submit_response() -> void:
	if response_input == null or feedback_label == null:
		return
	var response := response_input.text.strip_edges().to_lower()
	if response.is_empty():
		feedback_label.text = "Please enter a response before submitting."
		return
	if response == EXPECTED_RESPONSE:
		feedback_label.text = "Correct! You matched the context."
	else:
		feedback_label.text = "Not quite. Try matching the context again."

func _on_kana_toggle(pressed: bool) -> void:
	_apply_kana_visibility(pressed)

func _toggle_kana() -> void:
	if kana_toggle == null:
		return
	kana_toggle.button_pressed = not kana_toggle.button_pressed
	_apply_kana_visibility(kana_toggle.button_pressed)

func _apply_kana_visibility(show_kana: bool) -> void:
	if sentence_kana_label != null:
		sentence_kana_label.visible = show_kana

func _on_dyslexia_toggled(pressed: bool) -> void:
	_apply_dyslexia_mode(pressed)

func _apply_dyslexia_mode(enabled: bool) -> void:
	for node in _get_text_nodes():
		var base_size: int = base_font_sizes.get(node, node.get_theme_font_size("font_size"))
		var size := base_size
		if enabled:
			size = int(round(base_size * DYSLEXIA_FONT_SCALE))
		node.add_theme_font_size_override("font_size", size)
		if node is Label:
			var base_spacing: int = base_line_spacings.get(node, node.get_theme_constant("line_spacing"))
			var spacing := base_spacing
			if enabled:
				spacing = DYSLEXIA_LINE_SPACING
			node.add_theme_constant_override("line_spacing", spacing)
