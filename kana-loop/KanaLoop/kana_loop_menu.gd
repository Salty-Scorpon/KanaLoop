extends Control

@onready var main_menu: Control = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu
@onready var options_menu: Control = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options
@onready var options_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/OptionsButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/BackButton
@onready var practice_container: Control = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/PracticeContainer

@onready var practice_visual_delay_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/PracticeVisualDelay
@onready var practice_random_chains_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/PracticeRandomChains
@onready var practice_audio_symbol_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/PracticeAudioSymbol
@onready var practice_guided_writing_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/PracticeGuidedWriting

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

const VISUAL_DELAY_SCENE := preload("res://KanaLoop/visual_delay.tscn")
const RANDOM_CHAINS_SCENE := preload("res://KanaLoop/random_chains.tscn")
const AUDIO_SYMBOL_SCENE := preload("res://KanaLoop/audio_symbol.tscn")
const GUIDED_WRITING_SCENE := preload("res://KanaLoop/guided_writing.tscn")

func _ready() -> void:
	options_button.pressed.connect(_show_options)
	back_button.pressed.connect(_show_main)
	practice_visual_delay_button.pressed.connect(_on_practice_visual_delay)
	practice_random_chains_button.pressed.connect(_on_practice_random_chains)
	practice_audio_symbol_button.pressed.connect(_on_practice_audio_symbol)
	practice_guided_writing_button.pressed.connect(_on_practice_guided_writing)

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
	for voice in KanaAudio.get_voice_names():
		voice_selector.add_item(voice)
	voice_selector.item_selected.connect(_on_voice_selected)
	var selected_voice := KanaState.get_selected_voice()
	var selected_index := 0
	for index in voice_selector.item_count:
		if voice_selector.get_item_text(index) == selected_voice:
			selected_index = index
			break
	voice_selector.select(selected_index)
	_on_voice_selected(selected_index)

	_apply_custom_mix_state(custom_mix_toggle.button_pressed)
	_update_kana_selection()
	_apply_highlight_color(highlight_picker.color)
	_on_background_color_changed(background_picker.color)
	_on_kana_color_changed(kana_picker.color)

func _show_options() -> void:
	_clear_practice_scene()
	main_menu.visible = false
	options_menu.visible = true
	practice_container.visible = false

func _show_main() -> void:
	_clear_practice_scene()
	main_menu.visible = true
	options_menu.visible = false
	practice_container.visible = false

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
		KanaState.set_selected_kana(selected_kana)
		return

	if vowels_toggle.button_pressed:
		selected_kana.append_array(["あ", "い", "う", "え", "お"])
	if k_row_toggle.button_pressed:
		selected_kana.append_array(["か", "き", "く", "け", "こ"])
	if s_row_toggle.button_pressed:
		selected_kana.append_array(["さ", "し", "す", "せ", "そ"])
	KanaState.set_selected_kana(selected_kana)

func _ensure_kana_selection() -> void:
	if not selected_kana.is_empty():
		return

	if custom_mix_toggle.button_pressed:
		for child in custom_grid.get_children():
			if child is CheckBox:
				child.button_pressed = true
				selected_kana.append(child.text)
				KanaState.set_selected_kana(selected_kana)
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
	KanaState.set_highlight_color(color)
	for button in get_tree().get_nodes_in_group("menu_buttons"):
		if button is Button:
			button.add_theme_color_override("font_hover_color", color)
			button.add_theme_color_override("font_pressed_color", color)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _on_voice_selected(index: int) -> void:
	var voice := voice_selector.get_item_text(index)
	KanaState.set_selected_voice(voice)

func _on_practice_visual_delay() -> void:
	_open_practice_scene(VISUAL_DELAY_SCENE)

func _on_practice_random_chains() -> void:
	_open_practice_scene(RANDOM_CHAINS_SCENE)

func _on_practice_audio_symbol() -> void:
	_open_practice_scene(AUDIO_SYMBOL_SCENE)

func _on_practice_guided_writing() -> void:
	_open_practice_scene(GUIDED_WRITING_SCENE)

func _open_practice_scene(scene: PackedScene) -> void:
	_clear_practice_scene()
	main_menu.visible = false
	options_menu.visible = false
	practice_container.visible = true

	var practice_instance := scene.instantiate()
	if practice_instance.has_signal("back_requested"):
		practice_instance.back_requested.connect(_on_practice_back_requested)
	practice_container.add_child(practice_instance)

func _clear_practice_scene() -> void:
	for child in practice_container.get_children():
		child.queue_free()

func _on_practice_back_requested() -> void:
	_show_main()
