extends Node

var selected_kana: Array[String] = []
var selected_voice: String = ""
var selected_input_device: String = ""
var highlight_color: Color = Color(0.85, 0.2, 0.2, 1)
var selected_dictionary_weeks: Array[int] = []
var selected_dictionary_days: Array[int] = []
var selected_kanji_study_groups: Array[int] = []
var selected_pimsleur_study_groups: Array[int] = []
var selected_kanji_decks: Array[String] = []
var selected_kanji_tags: Array[String] = []
var selected_kanji_ids: Array[String] = []
var selected_kanji_characters: Array[String] = []
var kanji_require_strokes := false
var kanji_require_audio := false
var kanji_require_sentences := false

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

func get_selected_dictionary_weeks() -> Array[int]:
	return selected_dictionary_weeks.duplicate()

func set_selected_dictionary_weeks(weeks: Array[int]) -> void:
	selected_dictionary_weeks = weeks.duplicate()

func get_selected_dictionary_days() -> Array[int]:
	return selected_dictionary_days.duplicate()

func set_selected_dictionary_days(days: Array[int]) -> void:
	selected_dictionary_days = days.duplicate()

func get_selected_kanji_study_groups() -> Array[int]:
	return selected_kanji_study_groups.duplicate()

func set_selected_kanji_study_groups(groups: Array[int]) -> void:
	selected_kanji_study_groups = groups.duplicate()

func get_selected_pimsleur_study_groups() -> Array[int]:
	return selected_pimsleur_study_groups.duplicate()

func set_selected_pimsleur_study_groups(groups: Array[int]) -> void:
	selected_pimsleur_study_groups = groups.duplicate()

func get_selected_kanji_decks() -> Array[String]:
	return selected_kanji_decks.duplicate()

func set_selected_kanji_decks(decks: Array[String]) -> void:
	selected_kanji_decks = decks.duplicate()

func get_selected_kanji_tags() -> Array[String]:
	return selected_kanji_tags.duplicate()

func set_selected_kanji_tags(tags: Array[String]) -> void:
	selected_kanji_tags = tags.duplicate()

func get_selected_kanji_ids() -> Array[String]:
	return selected_kanji_ids.duplicate()

func set_selected_kanji_ids(ids: Array[String]) -> void:
	selected_kanji_ids = ids.duplicate()

func get_selected_kanji_characters() -> Array[String]:
	return selected_kanji_characters.duplicate()

func set_selected_kanji_characters(characters: Array[String]) -> void:
	selected_kanji_characters = characters.duplicate()

func get_kanji_require_strokes() -> bool:
	return kanji_require_strokes

func set_kanji_require_strokes(required: bool) -> void:
	kanji_require_strokes = required

func get_kanji_require_audio() -> bool:
	return kanji_require_audio

func set_kanji_require_audio(required: bool) -> void:
	kanji_require_audio = required

func get_kanji_require_sentences() -> bool:
	return kanji_require_sentences

func set_kanji_require_sentences(required: bool) -> void:
	kanji_require_sentences = required

func get_kanji_practice_filters() -> Dictionary:
	return {
		"weeks": selected_dictionary_weeks.duplicate(),
		"days": selected_dictionary_days.duplicate(),
		"study_groups": selected_kanji_study_groups.duplicate(),
		"pimsleur_study_groups": selected_pimsleur_study_groups.duplicate(),
		"decks": selected_kanji_decks.duplicate(),
		"tags": selected_kanji_tags.duplicate(),
		"ids": selected_kanji_ids.duplicate(),
		"kanji": selected_kanji_characters.duplicate(),
		"require_strokes": kanji_require_strokes,
		"require_audio": kanji_require_audio,
		"require_sentences": kanji_require_sentences,
	}
