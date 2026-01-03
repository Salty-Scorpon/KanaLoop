extends Control

@onready var main_menu: Control = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu
@onready var options_menu: Control = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options
@onready var options_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/OptionsButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/BackButton
@onready var practice_container: Control = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/PracticeContainer

@onready var practice_visual_delay_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/PracticeVisualDelay
@onready var practice_random_chains_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/PracticeRandomChains
@onready var practice_audio_symbol_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/PracticeAudioSymbol
@onready var practice_sequence_recall_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/PracticeSequenceRecall
@onready var practice_symbol_reading_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/PracticeSymbolReading
@onready var practice_guided_writing_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/PracticeGuidedWriting
@onready var dictionary_button: Button = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/MainMenu/Menu/DictionaryButton

@onready var vowels_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/VowelsCheckBox
@onready var k_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/KRowCheckBox
@onready var s_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/SRowCheckBox
@onready var t_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/TRowCheckBox
@onready var n_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/NRowCheckBox
@onready var h_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/HRowCheckBox
@onready var m_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/MRowCheckBox
@onready var y_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/YRowCheckBox
@onready var r_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/RRowCheckBox
@onready var w_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/WRowCheckBox
@onready var n_char_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/NCheckBox
@onready var g_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/GRowCheckBox
@onready var z_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/ZRowCheckBox
@onready var d_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/DRowCheckBox
@onready var b_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/BRowCheckBox
@onready var p_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/PRowCheckBox
@onready var kya_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/KyaRowCheckBox
@onready var gya_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/GyaRowCheckBox
@onready var sha_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/ShaRowCheckBox
@onready var ja_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/JaRowCheckBox
@onready var cha_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/ChaRowCheckBox
@onready var nya_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/NyaRowCheckBox
@onready var hya_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/HyaRowCheckBox
@onready var bya_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/ByaRowCheckBox
@onready var pya_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/PyaRowCheckBox
@onready var mya_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/MyaRowCheckBox
@onready var rya_row_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/RyaRowCheckBox
@onready var custom_mix_toggle: CheckBox = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/RowToggles/CustomMixCheckBox
@onready var custom_grid: GridContainer = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/KanaSelection/CustomMixGrid
@onready var row_toggles: Array[CheckBox] = [
	vowels_toggle,
	k_row_toggle,
	s_row_toggle,
	t_row_toggle,
	n_row_toggle,
	h_row_toggle,
	m_row_toggle,
	y_row_toggle,
	r_row_toggle,
	w_row_toggle,
	n_char_toggle,
	g_row_toggle,
	z_row_toggle,
	d_row_toggle,
	b_row_toggle,
	p_row_toggle,
	kya_row_toggle,
	gya_row_toggle,
	sha_row_toggle,
	ja_row_toggle,
	cha_row_toggle,
	nya_row_toggle,
	hya_row_toggle,
	bya_row_toggle,
	pya_row_toggle,
	mya_row_toggle,
	rya_row_toggle,
]

@onready var background_rect: ColorRect = $Background
@onready var background_picker: ColorPickerButton = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/VisualOptions/BackgroundRow/BackgroundPicker
@onready var kana_picker: ColorPickerButton = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/VisualOptions/KanaRow/KanaPicker
@onready var highlight_picker: ColorPickerButton = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/VisualOptions/HighlightRow/HighlightPicker
@onready var kana_preview: Label = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/VisualOptions/KanaPreview

@onready var volume_slider: HSlider = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/AudioOptions/VolumeRow/VolumeSlider
@onready var voice_selector: OptionButton = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/AudioOptions/VoiceRow/VoiceSelector
@onready var mic_device_selector: OptionButton = $MarginContainer/VBoxContainer/PanelContainer/PageContainer/Options/ScrollContainer/OptionsLayout/AudioOptions/InputDeviceRow/MicDeviceSelector

var selected_kana: Array[String] = []

const VISUAL_DELAY_SCENE := preload("res://KanaLoop/visual_delay.tscn")
const RANDOM_CHAINS_SCENE := preload("res://KanaLoop/random_chains.tscn")
const AUDIO_SYMBOL_SCENE := preload("res://KanaLoop/audio_symbol.tscn")
const SEQUENCE_RECALL_SCENE := preload("res://KanaLoop/sequence_recall.tscn")
const SYMBOL_READING_SCENE := preload("res://KanaReadingPractice.tscn")
const GUIDED_WRITING_SCENE := preload("res://KanaLoop/guided_writing.tscn")
const DICTIONARY_SCENE := preload("res://KanaLoop/dictionary_ui.tscn")

func _ready() -> void:
	options_button.pressed.connect(_show_options)
	back_button.pressed.connect(_show_main)
	practice_visual_delay_button.pressed.connect(_on_practice_visual_delay)
	practice_random_chains_button.pressed.connect(_on_practice_random_chains)
	practice_audio_symbol_button.pressed.connect(_on_practice_audio_symbol)
	practice_sequence_recall_button.pressed.connect(_on_practice_sequence_recall)
	practice_symbol_reading_button.pressed.connect(_on_practice_symbol_reading)
	practice_guided_writing_button.pressed.connect(_on_practice_guided_writing)
	dictionary_button.pressed.connect(_on_dictionary_open)

	for toggle in row_toggles:
		toggle.toggled.connect(_on_row_toggle)
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
	for index in range(voice_selector.item_count):
		if voice_selector.get_item_text(index) == selected_voice:
			selected_index = index
			break
	voice_selector.select(selected_index)
	_on_voice_selected(selected_index)

	mic_device_selector.item_selected.connect(_on_mic_device_selected)
	_refresh_mic_devices()

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
	_refresh_mic_devices()

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
	for toggle in row_toggles:
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
	if t_row_toggle.button_pressed:
		selected_kana.append_array(["た", "ち", "つ", "て", "と"])
	if n_row_toggle.button_pressed:
		selected_kana.append_array(["な", "に", "ぬ", "ね", "の"])
	if h_row_toggle.button_pressed:
		selected_kana.append_array(["は", "ひ", "ふ", "へ", "ほ"])
	if m_row_toggle.button_pressed:
		selected_kana.append_array(["ま", "み", "む", "め", "も"])
	if y_row_toggle.button_pressed:
		selected_kana.append_array(["や", "ゆ", "よ"])
	if r_row_toggle.button_pressed:
		selected_kana.append_array(["ら", "り", "る", "れ", "ろ"])
	if w_row_toggle.button_pressed:
		selected_kana.append_array(["わ", "を"])
	if n_char_toggle.button_pressed:
		selected_kana.append("ん")
	if g_row_toggle.button_pressed:
		selected_kana.append_array(["が", "ぎ", "ぐ", "げ", "ご"])
	if z_row_toggle.button_pressed:
		selected_kana.append_array(["ざ", "じ", "ず", "ぜ", "ぞ"])
	if d_row_toggle.button_pressed:
		selected_kana.append_array(["だ", "ぢ", "づ", "で", "ど"])
	if b_row_toggle.button_pressed:
		selected_kana.append_array(["ば", "び", "ぶ", "べ", "ぼ"])
	if p_row_toggle.button_pressed:
		selected_kana.append_array(["ぱ", "ぴ", "ぷ", "ぺ", "ぽ"])
	if kya_row_toggle.button_pressed:
		selected_kana.append_array(["きゃ", "きゅ", "きょ"])
	if gya_row_toggle.button_pressed:
		selected_kana.append_array(["ぎゃ", "ぎゅ", "ぎょ"])
	if sha_row_toggle.button_pressed:
		selected_kana.append_array(["しゃ", "しゅ", "しょ"])
	if ja_row_toggle.button_pressed:
		selected_kana.append_array(["じゃ", "じゅ", "じょ"])
	if cha_row_toggle.button_pressed:
		selected_kana.append_array(["ちゃ", "ちゅ", "ちょ"])
	if nya_row_toggle.button_pressed:
		selected_kana.append_array(["にゃ", "にゅ", "にょ"])
	if hya_row_toggle.button_pressed:
		selected_kana.append_array(["ひゃ", "ひゅ", "ひょ"])
	if bya_row_toggle.button_pressed:
		selected_kana.append_array(["びゃ", "びゅ", "びょ"])
	if pya_row_toggle.button_pressed:
		selected_kana.append_array(["ぴゃ", "ぴゅ", "ぴょ"])
	if mya_row_toggle.button_pressed:
		selected_kana.append_array(["みゃ", "みゅ", "みょ"])
	if rya_row_toggle.button_pressed:
		selected_kana.append_array(["りゃ", "りゅ", "りょ"])
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

func _refresh_mic_devices() -> void:
	mic_device_selector.clear()
	mic_device_selector.add_item("System Default")

	var devices := AudioServer.get_input_device_list()
	for device in devices:
		mic_device_selector.add_item(device)

	var selected_device := KanaState.get_selected_input_device()
	var selected_index := 0
	if not selected_device.is_empty():
		for index in range(1, mic_device_selector.item_count):
			if mic_device_selector.get_item_text(index) == selected_device:
				selected_index = index
				break
	mic_device_selector.select(selected_index)
	_apply_mic_device_selection(selected_index)

func _on_mic_device_selected(index: int) -> void:
	_apply_mic_device_selection(index)

func _apply_mic_device_selection(index: int) -> void:
	if index == 0:
		AudioServer.input_device = ""
		KanaState.set_selected_input_device("")
		return

	var device := mic_device_selector.get_item_text(index)
	AudioServer.input_device = device
	KanaState.set_selected_input_device(device)

func _on_practice_visual_delay() -> void:
	_open_practice_scene(VISUAL_DELAY_SCENE)

func _on_practice_random_chains() -> void:
	_open_practice_scene(RANDOM_CHAINS_SCENE)

func _on_practice_audio_symbol() -> void:
	_open_practice_scene(AUDIO_SYMBOL_SCENE)

func _on_practice_sequence_recall() -> void:
	_open_practice_scene(SEQUENCE_RECALL_SCENE)

func _on_practice_symbol_reading() -> void:
	_open_practice_scene(SYMBOL_READING_SCENE)

func _on_practice_guided_writing() -> void:
	_open_practice_scene(GUIDED_WRITING_SCENE)

func _on_dictionary_open() -> void:
	_open_practice_scene(DICTIONARY_SCENE)

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
