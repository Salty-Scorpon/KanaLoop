extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var kana_label: Label = $MarginContainer/VBoxContainer/KanaLabel
var selected_kana: Array[String] = []
var shuffled_kana: Array[String] = []
var kana_index := 0
var running := false

const VISUAL_DELAY_SECONDS := 1.0
const INTER_STIMULUS_DELAY_SECONDS := 0.4

func _ready() -> void:
	selected_kana = KanaState.get_selected_kana()
	shuffled_kana = selected_kana.duplicate()
	shuffled_kana.shuffle()
	running = true
	_play_sequence()
	back_button.pressed.connect(_on_back_pressed)

func _play_sequence() -> void:
	if shuffled_kana.is_empty():
		return
	_run_sequence()

func _run_sequence() -> void:
	while running:
		var kana := _next_kana()
		kana_label.text = kana
		await get_tree().create_timer(VISUAL_DELAY_SECONDS).timeout
		KanaAudio.play_kana_audio(kana)
		kana_label.text = ""
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
