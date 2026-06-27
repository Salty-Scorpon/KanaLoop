extends "res://KanaLoop/guided_writing.gd"

@onready var meaning_label: Label = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/PromptPanel/PromptVBox/MeaningLabel",
]) as Label
@onready var english_sentence_label: Label = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/PromptPanel/PromptVBox/EnglishSentenceLabel",
]) as Label
@onready var japanese_sentence_label: Label = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/PromptPanel/PromptVBox/JapaneseSentenceLabel",
]) as Label
@onready var word_label: Label = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/PromptPanel/PromptVBox/WordLabel",
]) as Label
@onready var status_label: Label = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/StatusLabel",
]) as Label

var selected_entries: Array[Dictionary] = []
var remaining_entry_pool: Array[Dictionary] = []
var current_entry: Dictionary = {}
var word_entry_lookup: Dictionary = {}
var chronological_practice := false
var word_completed := false

const TARGET_KANJI_FONT_SIZE := 190
const KANJI_MIN_DRAWN_LENGTH_RATIO := 0.20
const KANJI_FINAL_T_THRESHOLD := 0.72
const KANJI_CORRIDOR_RADIUS_SCALE := 1.6
const KANJI_GATE_RADIUS_SCALE := 1.35

func _ready() -> void:
	rng.randomize()
	if target_kana_label == null or progress_label == null or completion_label == null:
		push_error("Kanji guided writing UI nodes are missing. Check the KanjiGuidedWriting scene structure.")
		return
	if target_kana_label != null:
		target_kana_label.visible = false
		target_kana_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_prompt_audio_inputs()
	_load_kana_outline_data()
	_refill_remaining_pool()
	call_deferred("_advance_to_next_kana")
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
	if drawing_canvas != null:
		drawing_canvas.gui_input.connect(_on_drawing_canvas_input)
		drawing_canvas.resized.connect(_on_drawing_canvas_resized)
	if stroke_outline_toggle != null:
		stroke_outline_toggle.button_pressed = stroke_outline_enabled
		stroke_outline_toggle.toggled.connect(_on_stroke_outline_toggled)
	if blackout_toggle != null:
		blackout_toggle.button_pressed = blackout_enabled
		blackout_toggle.toggled.connect(_on_blackout_toggled)

func _connect_prompt_audio_inputs() -> void:
	if meaning_label != null:
		meaning_label.mouse_filter = Control.MOUSE_FILTER_STOP
		meaning_label.gui_input.connect(_on_meaning_label_input)
	if japanese_sentence_label != null:
		japanese_sentence_label.mouse_filter = Control.MOUSE_FILTER_STOP
		japanese_sentence_label.gui_input.connect(_on_japanese_sentence_label_input)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if event.shift_pressed:
			_play_current_meaning_audio()
		elif event.ctrl_pressed:
			_play_current_reading_audio()
		else:
			_play_current_meaning_then_reading_audio()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D:
		debug_overlay_enabled = not debug_overlay_enabled
		queue_redraw()

func _update_target_kana() -> void:
	if target_kana_label == null:
		return
	var word := String(current_entry.get("word", current_entry.get("kanji", "漢")))
	if word == "":
		word = "漢"
	target_kana_label.text = word
	target_kana_label.visible = stroke_runtimes.is_empty()
	target_kana_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_kana_label.add_theme_font_size_override("font_size", _get_word_font_size(word))

func _load_guide_definition() -> void:
	if drawing_canvas != null and drawing_canvas.size == Vector2.ZERO:
		return
	word_completed = false
	_clear_strokes()
	stroke_runtimes = _build_word_stroke_runtimes()
	if target_kana_label != null:
		target_kana_label.visible = stroke_runtimes.is_empty()
		target_kana_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_stroke_index = 0
	debug_last_t_visible = false
	if completion_label != null:
		completion_label.visible = false
	if stroke_runtimes.is_empty():
		progress_label.text = "No guide available"
	else:
		progress_label.text = _stroke_progress_text(0)
	_build_guides()
	_update_guides_visibility()
	queue_redraw()

func _get_min_drawn_length_ratio() -> float:
	return KANJI_MIN_DRAWN_LENGTH_RATIO

func _get_final_t_threshold() -> float:
	return KANJI_FINAL_T_THRESHOLD

func _get_corridor_radius_scale() -> float:
	return KANJI_CORRIDOR_RADIUS_SCALE

func _get_gate_radius_scale() -> float:
	return KANJI_GATE_RADIUS_SCALE

func _play_current_kana() -> void:
	if current_entry.is_empty():
		return
	VocabAudio.play_entry_kanji(current_entry)

func _play_current_meaning_audio() -> void:
	if current_entry.is_empty():
		return
	VocabAudio.play_entry_meaning_en(current_entry)

func _play_current_reading_audio() -> void:
	if current_entry.is_empty():
		return
	VocabAudio.play_entry_word(current_entry)

func _play_current_meaning_then_reading_audio() -> void:
	if current_entry.is_empty():
		return
	_play_meaning_then_reading_for_entry(current_entry)

func _play_current_sentence_audio() -> void:
	if current_entry.is_empty():
		return
	VocabAudio.play_entry_sentence_ja(current_entry)


func _play_meaning_then_reading_for_entry(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	await _play_entry_audio_and_wait(entry, Callable(VocabAudio, "play_entry_meaning_en"))
	await _play_entry_audio_and_wait(entry, Callable(VocabAudio, "play_entry_word"))

func _play_entry_audio_and_wait(entry: Dictionary, play_callable: Callable) -> void:
	if not play_callable.call(entry):
		return
	if VocabAudio.is_playing():
		await VocabAudio.audio_player.finished

func _on_drawing_canvas_resized() -> void:
	if drawing_canvas == null:
		return
	if drawing_canvas.size == Vector2.ZERO:
		return
	if current_entry.is_empty():
		return
	if word_completed:
		return
	_load_guide_definition()

func _handle_kana_completed() -> void:
	word_completed = true
	if completion_label != null:
		completion_label.visible = true
	progress_label.text = "Word completed"
	var completed_entry := current_entry.duplicate(true)
	await _play_meaning_then_reading_for_entry(completed_entry)
	call_deferred("_advance_to_next_kana")

func _advance_to_next_kana() -> void:
	word_completed = false
	if remaining_entry_pool.is_empty():
		_refill_remaining_pool()
	current_entry = {}
	current_kana = ""
	if not remaining_entry_pool.is_empty():
		current_entry = remaining_entry_pool.pop_front() if chronological_practice else remaining_entry_pool.pop_back()
		current_kana = String(current_entry.get("word", current_entry.get("kanji", "")))
	_update_prompt_labels()
	_update_target_kana()
	_load_guide_definition()
	if not current_entry.is_empty():
		_play_current_meaning_then_reading_audio()

func _refill_remaining_pool() -> void:
	var filters := KanaState.get_kanji_practice_filters()
	chronological_practice = _filter_has_values(filters, "study_groups")
	selected_entries = KanjiVocabData.get_filtered_entries(filters)
	if selected_entries.is_empty():
		selected_entries = KanjiVocabData.get_entries()
		chronological_practice = false
	word_entry_lookup = {}
	remaining_entry_pool = []
	var seen_words := {}
	for entry in selected_entries:
		var word := String(entry.get("word", ""))
		var kanji := String(entry.get("kanji", ""))
		if word == "":
			word = kanji
		if word == "":
			continue
		if not word_entry_lookup.has(word):
			word_entry_lookup[word] = {}
		if kanji != "":
			word_entry_lookup[word][kanji] = entry.duplicate(true)
		if not seen_words.has(word):
			var word_entry := entry.duplicate(true)
			word_entry["word"] = word
			remaining_entry_pool.append(word_entry)
			seen_words[word] = true
	if not chronological_practice:
		_shuffle_remaining_entry_pool()

func _filter_has_values(filters: Dictionary, key: String) -> bool:
	if not filters.has(key):
		return false
	var value: Variant = filters[key]
	return typeof(value) == TYPE_ARRAY and not value.is_empty()

func _shuffle_remaining_entry_pool() -> void:
	for index in range(remaining_entry_pool.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp := remaining_entry_pool[index]
		remaining_entry_pool[index] = remaining_entry_pool[swap_index]
		remaining_entry_pool[swap_index] = temp

func _update_prompt_labels() -> void:
	var has_entry := not current_entry.is_empty()
	if status_label != null:
		status_label.visible = not has_entry
		status_label.text = KanjiVocabData.get_last_error() if not has_entry else ""
	if meaning_label != null:
		meaning_label.text = String(current_entry.get("meaning", "No kanji vocabulary entries loaded."))
	if word_label != null:
		var word := String(current_entry.get("word", ""))
		var reading := String(current_entry.get("reading", ""))
		word_label.text = "%s（%s）" % [word, reading] if word != "" and reading != "" else ""
	var sample_sentence: Dictionary = current_entry.get("sample_sentence", {})
	if english_sentence_label != null:
		english_sentence_label.text = String(sample_sentence.get("en", ""))
	if japanese_sentence_label != null:
		japanese_sentence_label.text = String(sample_sentence.get("ja", ""))

func _on_kanji_label_input(event: InputEvent) -> void:
	if _is_primary_click(event):
		_play_current_kana()

func _on_meaning_label_input(event: InputEvent) -> void:
	if _is_primary_click(event):
		_play_current_meaning_audio()

func _on_japanese_sentence_label_input(event: InputEvent) -> void:
	if _is_primary_click(event):
		_play_current_sentence_audio()

func _is_primary_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed

func _build_word_stroke_runtimes() -> Array[Dictionary]:
	var runtimes: Array[Dictionary] = []
	if current_entry.is_empty() or drawing_canvas == null:
		return runtimes
	var word := String(current_entry.get("word", current_entry.get("kanji", "")))
	if word == "":
		return runtimes
	var chars := _split_word_chars(word)
	if chars.is_empty():
		return runtimes
	var canvas_size := drawing_canvas.size
	var glyph_size: float = min(canvas_size.y, canvas_size.x / float(chars.size()))
	glyph_size *= 0.92
	var total_width := glyph_size * chars.size()
	var start_x := (canvas_size.x - total_width) * 0.5
	var start_y := (canvas_size.y - glyph_size) * 0.5
	var word_lookup: Dictionary = word_entry_lookup.get(word, {})
	for index in range(chars.size()):
		var character: String = chars[index]
		var definition := _definition_for_word_character(character, word_lookup)
		if definition.is_empty():
			continue
		var origin := Vector2(start_x + glyph_size * index, start_y)
		var char_runtimes := _build_stroke_runtimes_with_layout(definition, origin, glyph_size)
		for runtime in char_runtimes:
			runtime["character"] = character
			runtime["word_index"] = index
			runtimes.append(runtime)
	return runtimes

func _definition_for_word_character(character: String, word_lookup: Dictionary) -> Dictionary:
	if kana_outline_data.has(character):
		return kana_outline_data[character]
	var entry: Dictionary = word_lookup.get(character, {})
	if not entry.is_empty():
		return entry
	if String(current_entry.get("kanji", "")) == character:
		return current_entry
	return {}

func _split_word_chars(word: String) -> Array[String]:
	var chars: Array[String] = []
	for index in range(word.length()):
		chars.append(word.substr(index, 1))
	return chars

func _get_word_font_size(word: String) -> int:
	if word.length() <= 1:
		return TARGET_KANJI_FONT_SIZE
	return max(72, int(TARGET_KANJI_FONT_SIZE / sqrt(float(word.length()))))

func _stroke_progress_text(stroke_index: int) -> String:
	if stroke_runtimes.is_empty():
		return "No guide available"
	var safe_index: int = clamp(stroke_index, 0, stroke_runtimes.size() - 1)
	var runtime: Dictionary = stroke_runtimes[safe_index]
	var character := String(runtime.get("character", ""))
	return "Stroke %d/%d%s" % [safe_index + 1, stroke_runtimes.size(), " · %s" % character if character != "" else ""]
