extends Node

var selected_kana: Array[String] = []
var selected_voice: String = ""
var selected_input_device: String = ""
var highlight_color: Color = Color(0.85, 0.2, 0.2, 1)

const DEFAULT_KANA: Array[String] = ["あ", "い", "う", "え", "お"]

func get_selected_kana() -> Array[String]:
	return selected_kana.duplicate()

func set_selected_kana(kana: Array[String]) -> void:
	if kana.is_empty():
		if selected_kana.is_empty():
			selected_kana = DEFAULT_KANA.duplicate()
		return
	selected_kana = kana.duplicate()

func get_selected_voice() -> String:
	if selected_voice.is_empty():
		selected_voice = KanaAudio.DEFAULT_VOICE
	return selected_voice

func set_selected_voice(voice: String) -> void:
	if voice.is_empty():
		selected_voice = KanaAudio.DEFAULT_VOICE
		return
	selected_voice = voice

func get_selected_input_device() -> String:
	return selected_input_device

func set_selected_input_device(device: String) -> void:
	selected_input_device = device

func get_highlight_color() -> Color:
	return highlight_color

func set_highlight_color(color: Color) -> void:
	highlight_color = color
