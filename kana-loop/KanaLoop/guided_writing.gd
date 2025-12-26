extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
var selected_kana: Array[String] = []

func _ready() -> void:
	selected_kana = KanaState.get_selected_kana()
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	back_requested.emit()
