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
		else:
			_play_current_kana()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D:
		debug_overlay_enabled = not debug_overlay_enabled
		queue_redraw()

func _update_target_kana() -> void:
	if target_kana_label == null:
		return
	var kanji := String(current_entry.get("kanji", "漢"))
	target_kana_label.text = kanji
	target_kana_label.visible = stroke_runtimes.is_empty()
	target_kana_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_kana_label.add_theme_font_size_override("font_size", TARGET_KANJI_FONT_SIZE)

func _load_guide_definition() -> void:
	if drawing_canvas != null and drawing_canvas.size == Vector2.ZERO:
		return
	_clear_strokes()
	stroke_runtimes = _build_stroke_runtimes(current_entry)
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
		progress_label.text = "Stroke 1/%d" % stroke_runtimes.size()
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

func _play_current_sentence_audio() -> void:
	if current_entry.is_empty():
		return
	VocabAudio.play_entry_sentence_ja(current_entry)

func _on_drawing_canvas_resized() -> void:
	if drawing_canvas == null:
		return
	if drawing_canvas.size == Vector2.ZERO:
		return
	if current_entry.is_empty():
		return
	_load_guide_definition()

func _handle_kana_completed() -> void:
	if completion_label != null:
		completion_label.visible = true
	progress_label.text = "Completed"
	_play_current_kana()
	call_deferred("_advance_to_next_kana")

func _advance_to_next_kana() -> void:
	if remaining_entry_pool.is_empty():
		_refill_remaining_pool()
	current_entry = {}
	current_kana = ""
	if not remaining_entry_pool.is_empty():
		current_entry = remaining_entry_pool.pop_back()
		current_kana = String(current_entry.get("kanji", ""))
	_update_prompt_labels()
	_update_target_kana()
	_load_guide_definition()
	if not current_entry.is_empty():
		VocabAudio.play_entry_kanji(current_entry)

func _refill_remaining_pool() -> void:
	selected_entries = KanjiVocabData.get_active_practice_entries()
	if selected_entries.is_empty():
		selected_entries = KanjiVocabData.get_entries()
	remaining_entry_pool = []
	for entry in selected_entries:
		remaining_entry_pool.append(entry.duplicate(true))
	_shuffle_remaining_entry_pool()

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
