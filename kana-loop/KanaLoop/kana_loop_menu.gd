extends Control

@onready var main_menu: Control = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu
@onready var options_menu: Control = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options
@onready var options_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/OptionsButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/BackButton

@onready var vowels_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/VowelsCheckBox
@onready var k_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/KRowCheckBox
@onready var s_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/SRowCheckBox
@onready var custom_mix_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/CustomMixCheckBox
@onready var custom_grid: GridContainer = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/CustomMixGrid

@onready var background_rect: ColorRect = $Background
@onready var background_picker: ColorPickerButton = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/VisualOptions/BackgroundRow/BackgroundPicker
@onready var kana_picker: ColorPickerButton = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/VisualOptions/KanaRow/KanaPicker
@onready var highlight_picker: ColorPickerButton = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/VisualOptions/HighlightRow/HighlightPicker
@onready var kana_preview: Label = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/VisualOptions/KanaPreview

@onready var volume_slider: HSlider = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/AudioOptions/VolumeRow/VolumeSlider
@onready var voice_selector: OptionButton = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/AudioOptions/VoiceRow/VoiceSelector

var selected_kana: Array[String] = []

func _ready() -> void:
	options_button.pressed.connect(_show_options)
	back_button.pressed.connect(_show_main)

	vowels_toggle.toggled.connect(_on_row_toggle)
	k_row_toggle.toggled.connect(_on_row_toggle)
	s_row_toggle.toggled.connect(_on_row_toggle)
	custom_mix_toggle.toggled.connect(_on_custom_mix_toggle)

	for child in custom_grid.get_children():
		if child is CheckBox:
			child.toggled.connect(_on_custom_kana_toggle)

	background_picker.color_changed.connect(_on_background_color_changed)
	kana_picker.color_changed.connect(_on_kana_color_changed)
	highlight_picker.color_changed.connect(_on_highlight_color_changed)

	volume_slider.value_changed.connect(_on_volume_changed)
	voice_selector.clear()
	voice_selector.add_item("Voice 1")
	voice_selector.add_item("Voice 2")
	voice_selector.select(0)

	_apply_custom_mix_state(custom_mix_toggle.button_pressed)
	_update_kana_selection()
	_apply_highlight_color(highlight_picker.color)
	_on_background_color_changed(background_picker.color)
	_on_kana_color_changed(kana_picker.color)

func _show_options() -> void:
	main_menu.visible = false
	options_menu.visible = true

func _show_main() -> void:
	main_menu.visible = true
	options_menu.visible = false

func _on_row_toggle(_pressed: bool) -> void:
	if custom_mix_toggle.button_pressed:
		return
	_update_kana_selection()
	_ensure_kana_selection()

func _on_custom_mix_toggle(pressed: bool) -> void:
	_apply_custom_mix_state(pressed)
	_update_kana_selection()
	_ensure_kana_selection()

func _on_custom_kana_toggle(_pressed: bool) -> void:
	if not custom_mix_toggle.button_pressed:
		return
	_update_kana_selection()
	_ensure_kana_selection()

func _apply_custom_mix_state(pressed: bool) -> void:
	custom_grid.visible = pressed
	for toggle in [vowels_toggle, k_row_toggle, s_row_toggle]:
		toggle.disabled = pressed
	for child in custom_grid.get_children():
		if child is CheckBox:
			child.disabled = not pressed

func _update_kana_selection() -> void:
	selected_kana.clear()

	if custom_mix_toggle.button_pressed:
		for child in custom_grid.get_children():
			if child is CheckBox and child.button_pressed:
				selected_kana.append(child.text)
		return

	if vowels_toggle.button_pressed:
		selected_kana.append_array(["あ", "い", "う", "え", "お"])
	if k_row_toggle.button_pressed:
		selected_kana.append_array(["か", "き", "く", "け", "こ"])
	if s_row_toggle.button_pressed:
		selected_kana.append_array(["さ", "し", "す", "せ", "そ"])

func _ensure_kana_selection() -> void:
	if not selected_kana.is_empty():
		return

	if custom_mix_toggle.button_pressed:
		for child in custom_grid.get_children():
			if child is CheckBox:
				child.button_pressed = true
				selected_kana.append(child.text)
				break
		return

	vowels_toggle.button_pressed = true
	_update_kana_selection()

func _on_background_color_changed(color: Color) -> void:
	background_rect.color = color

func _on_kana_color_changed(color: Color) -> void:
	kana_preview.add_theme_color_override("font_color", color)

func _on_highlight_color_changed(color: Color) -> void:
	_apply_highlight_color(color)

func _apply_highlight_color(color: Color) -> void:
	for button in get_tree().get_nodes_in_group("menu_buttons"):
		if button is Button:
			button.add_theme_color_override("font_hover_color", color)
			button.add_theme_color_override("font_pressed_color", color)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))
