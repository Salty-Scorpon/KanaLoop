extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var single_toggle: Button = $MarginContainer/VBoxContainer/LengthRow/LengthButtons/SingleToggle
@onready var double_toggle: Button = $MarginContainer/VBoxContainer/LengthRow/LengthButtons/DoubleToggle
@onready var triple_toggle: Button = $MarginContainer/VBoxContainer/LengthRow/LengthButtons/TripleToggle
@onready var kana_buttons: Array[Button] = [
	$MarginContainer/VBoxContainer/KanaRow/KanaButton1,
	$MarginContainer/VBoxContainer/KanaRow/KanaButton2,
	$MarginContainer/VBoxContainer/KanaRow/KanaButton3,
]
var selected_kana: Array[String] = []
var current_chain: Array[String] = []
var chain_length := 1
var rng := RandomNumberGenerator.new()
var highlight_color: Color

func _ready() -> void:
	selected_kana = KanaState.get_selected_kana()
	if selected_kana.is_empty():
		selected_kana = KanaState.DEFAULT_KANA.duplicate()
	highlight_color = KanaState.get_highlight_color()
	rng.randomize()
	_setup_length_toggles()
	_apply_highlight_color()
	_connect_kana_buttons()
	_regenerate_chain()
	back_button.pressed.connect(_on_back_pressed)

func _setup_length_toggles() -> void:
	var group := ButtonGroup.new()
	single_toggle.button_group = group
	double_toggle.button_group = group
	triple_toggle.button_group = group

	single_toggle.toggled.connect(_on_length_toggled.bind(1))
	double_toggle.toggled.connect(_on_length_toggled.bind(2))
	triple_toggle.toggled.connect(_on_length_toggled.bind(3))

	single_toggle.button_pressed = true

func _apply_highlight_color() -> void:
	for button in kana_buttons:
		button.add_theme_color_override("font_hover_color", highlight_color)
		button.add_theme_color_override("font_pressed_color", highlight_color)
	for toggle in [single_toggle, double_toggle, triple_toggle]:
		toggle.add_theme_color_override("font_hover_color", highlight_color)
		toggle.add_theme_color_override("font_pressed_color", highlight_color)

func _connect_kana_buttons() -> void:
	for index in kana_buttons.size():
		kana_buttons[index].pressed.connect(_on_kana_pressed.bind(index))

func _on_length_toggled(pressed: bool, length: int) -> void:
	if not pressed:
		return
	chain_length = length
	_regenerate_chain()

func _regenerate_chain() -> void:
	current_chain.clear()
	if selected_kana.is_empty():
		return
	for index in chain_length:
		var kana := selected_kana[rng.randi_range(0, selected_kana.size() - 1)]
		current_chain.append(kana)

	for index in kana_buttons.size():
		var button := kana_buttons[index]
		if index < current_chain.size():
			button.text = current_chain[index]
			button.visible = true
			button.disabled = false
		else:
			button.visible = false
			button.disabled = true

func _on_kana_pressed(index: int) -> void:
	if index >= current_chain.size():
		return
	KanaAudio.play_kana_audio(current_chain[index])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_regenerate_chain()
			accept_event()

func _on_back_pressed() -> void:
	back_requested.emit()
