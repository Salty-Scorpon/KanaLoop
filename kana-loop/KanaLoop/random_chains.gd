extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
var selected_kana: Array[String] = []

func _ready() -> void:
	selected_kana = KanaState.get_selected_kana()
	_play_preview_kana()
	back_button.pressed.connect(_on_back_pressed)

func _play_preview_kana() -> void:
	if selected_kana.is_empty():
		return
	KanaAudio.play_kana_audio(selected_kana[0])

func _on_back_pressed() -> void:
	back_requested.emit()
