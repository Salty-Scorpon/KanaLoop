extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var kana_label: Label = $MarginContainer/VBoxContainer/KanaLabel
@onready var fullscreen_kana: Label = $PresentationLayer/FullscreenKana
@onready var fade_overlay: ColorRect = $PresentationLayer/FadeOverlay
var selected_kana: Array[String] = []
var shuffled_kana: Array[String] = []
var kana_index := 0
var running := false

const AUDIO_PAUSE_SECONDS := 0.0
const KANA_DISPLAY_SECONDS := 2.0
const FADE_OUT_SECONDS := 0.0
const INTER_STIMULUS_DELAY_SECONDS := 0.0
const KANA_LABEL_FONT_SIZE := 120
const KANA_LABEL_MULTI_FONT_SIZE := 96
const FULLSCREEN_KANA_FONT_SIZE := 180
const FULLSCREEN_KANA_MULTI_FONT_SIZE := 150

func _ready() -> void:
	selected_kana = KanaState.get_selected_kana()
	shuffled_kana = selected_kana.duplicate()
	shuffled_kana.shuffle()
	running = true
	kana_label.visible = false
	fullscreen_kana.text = ""
	_set_fade_alpha(1.0)
	_play_sequence()
	back_button.pressed.connect(_on_back_pressed)

func _play_sequence() -> void:
	if shuffled_kana.is_empty():
		return
	_run_sequence()

func _run_sequence() -> void:
	while running:
		var kana := _next_kana()
		_show_blank()
		KanaAudio.play_kana_audio(kana)
		await get_tree().create_timer(AUDIO_PAUSE_SECONDS).timeout
		await _show_kana(kana)
		await _fade_to_blank()
		await get_tree().create_timer(INTER_STIMULUS_DELAY_SECONDS).timeout

func _next_kana() -> String:
	if shuffled_kana.is_empty():
		return ""
	if kana_index >= shuffled_kana.size():
		shuffled_kana.shuffle()
		kana_index = 0
	var kana := shuffled_kana[kana_index]
	kana_index += 1
	return kana

func _on_back_pressed() -> void:
	running = false
	back_requested.emit()

func _show_blank() -> void:
	fullscreen_kana.text = ""
	_set_fade_alpha(1.0)

func _show_kana(kana: String) -> void:
	_apply_kana_font_sizes(kana)
	fullscreen_kana.text = kana
	_set_fade_alpha(0.0)
	await get_tree().create_timer(KANA_DISPLAY_SECONDS).timeout

func _fade_to_blank() -> void:
	if FADE_OUT_SECONDS <= 0.0:
		_set_fade_alpha(1.0)
		return
	var tween := create_tween()
	tween.tween_method(_set_fade_alpha, fade_overlay.color.a, 1.0, FADE_OUT_SECONDS)
	await tween.finished

func _set_fade_alpha(alpha: float) -> void:
	var color := fade_overlay.color
	color.a = clampf(alpha, 0.0, 1.0)
	fade_overlay.color = color

func _apply_kana_font_sizes(kana: String) -> void:
	if kana_label != null:
		kana_label.add_theme_font_size_override(
			"font_size",
			_font_size_for_kana(kana, KANA_LABEL_FONT_SIZE, KANA_LABEL_MULTI_FONT_SIZE)
		)
	if fullscreen_kana != null:
		fullscreen_kana.add_theme_font_size_override(
			"font_size",
			_font_size_for_kana(kana, FULLSCREEN_KANA_FONT_SIZE, FULLSCREEN_KANA_MULTI_FONT_SIZE)
		)

func _font_size_for_kana(kana: String, base_size: int, multi_size: int) -> int:
	return multi_size if kana.length() > 1 else base_size
