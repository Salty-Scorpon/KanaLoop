extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	back_requested.emit()
