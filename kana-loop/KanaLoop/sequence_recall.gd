extends Control

signal back_requested

enum State {
	INIT,
	PLAY_SEQUENCE,
	TRANSITION_TO_SELECTION,
	PLAYER_INPUT,
	VALIDATION,
	FEEDBACK,
}

@export var mode_length := 4
@export var allow_repeats := false
@export var selection_pool_size := 8
@export var playback_delay := 0.6
@export var feedback_delay := 1.5

const DIFFICULTY_LENGTHS := [2, 3, 4, 5]

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var difficulty_option: OptionButton = $MarginContainer/VBoxContainer/OptionsPanel/OptionsVBox/DifficultyRow/DifficultyOption
@onready var pool_size_spin_box: SpinBox = $MarginContainer/VBoxContainer/OptionsPanel/OptionsVBox/PoolRow/PoolSizeSpinBox
@onready var repeats_check_box: CheckBox = $MarginContainer/VBoxContainer/OptionsPanel/OptionsVBox/RepeatsRow/RepeatsCheckBox
@onready var playback_label: Label = $MarginContainer/VBoxContainer/PlaybackLabel
@onready var progress_label: Label = $MarginContainer/VBoxContainer/ProgressLabel
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel
@onready var selection_panel: Control = $MarginContainer/VBoxContainer/SelectionPanel
@onready var selection_grid: GridContainer = $MarginContainer/VBoxContainer/SelectionPanel/SelectionGrid

var played_sequence: Array[String] = []
var player_sequence: Array[String] = []
var available_kana: Array[String] = []
var current_step := 0
var state: State = State.INIT

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_setup_options()
	_start_round()

func _on_back_pressed() -> void:
	back_requested.emit()

func _setup_options() -> void:
	difficulty_option.clear()
	for length in DIFFICULTY_LENGTHS:
		difficulty_option.add_item(str(length))
	var selected_index := DIFFICULTY_LENGTHS.find(mode_length)
	if selected_index == -1:
		mode_length = DIFFICULTY_LENGTHS[0]
		selected_index = 0
	difficulty_option.select(selected_index)
	pool_size_spin_box.value = selection_pool_size
	repeats_check_box.button_pressed = allow_repeats
	difficulty_option.item_selected.connect(_on_difficulty_selected)
	pool_size_spin_box.value_changed.connect(_on_pool_size_changed)
	repeats_check_box.toggled.connect(_on_allow_repeats_toggled)

func _on_difficulty_selected(index: int) -> void:
	if index < 0 or index >= DIFFICULTY_LENGTHS.size():
		return
	mode_length = DIFFICULTY_LENGTHS[index]

func _on_pool_size_changed(value: float) -> void:
	selection_pool_size = int(value)

func _on_allow_repeats_toggled(enabled: bool) -> void:
	allow_repeats = enabled

func _start_round() -> void:
	_set_state(State.INIT)
	_reset_round()
	await _play_sequence()
	_set_state(State.TRANSITION_TO_SELECTION)
	_show_selection()
	_set_state(State.PLAYER_INPUT)

func _reset_round() -> void:
	player_sequence.clear()
	current_step = 0
	feedback_label.text = ""
	progress_label.text = ""
	_set_selection_interactive(false)
	selection_panel.visible = false
	_prepare_available_kana()
	_generate_sequence()
	_build_selection_buttons()

func _prepare_available_kana() -> void:
	available_kana = KanaState.get_selected_kana()
	if available_kana.is_empty():
		available_kana = KanaState.DEFAULT_KANA.duplicate()
	if selection_pool_size > 0 and selection_pool_size < available_kana.size():
		available_kana.shuffle()
		available_kana = available_kana.slice(0, selection_pool_size)

func _generate_sequence() -> void:
	played_sequence.clear()
	if available_kana.is_empty() or mode_length <= 0:
		return
	if allow_repeats:
		for index in mode_length:
			played_sequence.append(available_kana.pick_random())
		return
	var pool := available_kana.duplicate()
	pool.shuffle()
	var pool_index := 0
	for index in mode_length:
		if pool_index >= pool.size():
			pool.shuffle()
			pool_index = 0
		played_sequence.append(pool[pool_index])
		pool_index += 1

func _build_selection_buttons() -> void:
	for child in selection_grid.get_children():
		child.queue_free()
	for kana in available_kana:
		var button := Button.new()
		button.text = kana
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.disabled = true
		button.pressed.connect(func() -> void:
			_on_kana_selected(kana)
		)
		selection_grid.add_child(button)

func _play_sequence() -> void:
	_set_state(State.PLAY_SEQUENCE)
	playback_label.text = ""
	for kana in played_sequence:
		playback_label.text = kana
		await get_tree().create_timer(playback_delay).timeout
		await KanaAudio.play_kana_audio_and_wait(kana)
		playback_label.text = ""
		await get_tree().create_timer(playback_delay).timeout

func _show_selection() -> void:
	selection_panel.visible = true
	_set_selection_interactive(true)
	_update_progress()

func _set_selection_interactive(enabled: bool) -> void:
	selection_panel.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for child in selection_grid.get_children():
		if child is Button:
			child.disabled = not enabled

func _on_kana_selected(kana: String) -> void:
	if state != State.PLAYER_INPUT:
		return
	player_sequence.append(kana)
	current_step = player_sequence.size()
	_update_progress()
	if player_sequence.size() >= played_sequence.size():
		_validate_sequence()

func _validate_sequence() -> void:
	_set_state(State.VALIDATION)
	_set_selection_interactive(false)
	var correct := player_sequence == played_sequence
	_set_state(State.FEEDBACK)
	feedback_label.text = "Correct!" if correct else "Try again!"
	if correct:
		KanaAudio.play_success()
	else:
		KanaAudio.play_failure()
	await get_tree().create_timer(feedback_delay).timeout
	_start_round()

func _update_progress() -> void:
	progress_label.text = "Step %d / %d" % [current_step, played_sequence.size()]

func _set_state(new_state: State) -> void:
	state = new_state
