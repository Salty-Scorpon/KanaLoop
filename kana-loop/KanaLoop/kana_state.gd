extends Node

var selected_kana: Array[String] = []

const DEFAULT_KANA: Array[String] = ["あ", "い", "う", "え", "お"]

func get_selected_kana() -> Array[String]:
	return selected_kana.duplicate()

func set_selected_kana(kana: Array[String]) -> void:
	if kana.is_empty():
		if selected_kana.is_empty():
			selected_kana = DEFAULT_KANA.duplicate()
		return
	selected_kana = kana.duplicate()
