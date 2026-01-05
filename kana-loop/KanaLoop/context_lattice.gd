extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var word_label: Label = $MarginContainer/VBoxContainer/WordLabel
@onready var sentence_jp_label: Label = $MarginContainer/VBoxContainer/SentencePanel/SentenceVBox/SentenceJP
@onready var sentence_kana_label: Label = $MarginContainer/VBoxContainer/SentencePanel/SentenceVBox/SentenceKana
@onready var sentence_en_label: Label = $MarginContainer/VBoxContainer/SentencePanel/SentenceVBox/SentenceEN
@onready var response_input: LineEdit = $MarginContainer/VBoxContainer/ResponseRow/ResponseInput
@onready var submit_button: Button = $MarginContainer/VBoxContainer/ResponseRow/SubmitButton
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel
@onready var replay_button: Button = $MarginContainer/VBoxContainer/ControlsRow/ReplayAudioButton
@onready var kana_toggle: CheckBox = $MarginContainer/VBoxContainer/ControlsRow/KanaToggle
@onready var dyslexia_toggle: CheckBox = $MarginContainer/VBoxContainer/ControlsRow/DyslexiaToggle
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

const DYSLEXIA_FONT_SCALE := 1.15
const DYSLEXIA_LINE_SPACING := 6
const DICTIONARY_PATH := "res://assets/data/dictionary_3000_common_words.json"
const SENTENCE_CORPUS_PATH := "res://assets/data/sentence_corpus.json"

const STAGE_UNSEEN := 0
const STAGE_RECOGNIZED := 1
const STAGE_RECALLABLE := 2
const STAGE_AUTOMATIC := 3

const STAGE_LABELS := {
	STAGE_UNSEEN: "unseen",
	STAGE_RECOGNIZED: "recognized",
	STAGE_RECALLABLE: "recallable",
	STAGE_AUTOMATIC: "automatic",
}

const STAGE_EXPOSURE_TARGETS := {
	STAGE_UNSEEN: 2,
	STAGE_RECOGNIZED: 3,
	STAGE_RECALLABLE: 4,
}

const PROMOTION_REQUIREMENTS := {
	STAGE_UNSEEN: {"correct": 2, "exposures": 2, "unique": 2},
	STAGE_RECOGNIZED: {"correct": 3, "exposures": 4, "unique": 3},
	STAGE_RECALLABLE: {"correct": 4, "exposures": 6, "unique": 4},
}

const EASY_MODE_FAILURE_THRESHOLD := 2
const SINGLE_SENTENCE_PROMOTION_WEIGHT := 0.5

var base_font_sizes: Dictionary = {}
var base_line_spacings: Dictionary = {}

var dictionary_entries: Dictionary = {}
var sentence_corpus: Dictionary = {}
var frequency_ranks: Dictionary = {}

var current_word_id: String = ""
var current_sentence: Dictionary = {}
var last_word_id: String = ""
var last_sentence_id: String = ""
var current_audio_available: bool = false
var prompt_started_msec: int = 0
var prompt_pending: bool = false

func _ready() -> void:
	randomize()
	_load_dictionary()
	_load_sentence_corpus()
	_cache_text_styles()
	_apply_kana_visibility(kana_toggle.button_pressed if kana_toggle != null else true)
	_select_next_sentence()

	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
	if replay_button != null:
		replay_button.pressed.connect(_on_replay_audio)
	if submit_button != null:
		submit_button.pressed.connect(_on_submit_pressed)
	if response_input != null:
		response_input.text_submitted.connect(_on_response_submitted)
	if kana_toggle != null:
		kana_toggle.toggled.connect(_on_kana_toggle)
	if dyslexia_toggle != null:
		dyslexia_toggle.toggled.connect(_on_dyslexia_toggled)

	_configure_focus_order()
	if response_input != null:
		response_input.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_submit_response()
			return
		if event.keycode == KEY_R and event.ctrl_pressed:
			_on_replay_audio()
			return
		if event.keycode == KEY_K and event.ctrl_pressed:
			_toggle_kana()
			return

func _configure_focus_order() -> void:
	var focusables: Array[Control] = []
	if response_input != null:
		focusables.append(response_input)
	if submit_button != null:
		focusables.append(submit_button)
	if replay_button != null:
		focusables.append(replay_button)
	if kana_toggle != null:
		focusables.append(kana_toggle)
	if dyslexia_toggle != null:
		focusables.append(dyslexia_toggle)
	if back_button != null:
		focusables.append(back_button)

	if focusables.is_empty():
		return

	for index in range(focusables.size()):
		var control := focusables[index]
		control.focus_mode = Control.FOCUS_ALL
		var next_index := (index + 1) % focusables.size()
		var prev_index := (index - 1 + focusables.size()) % focusables.size()
		control.focus_next = control.get_path_to(focusables[next_index])
		control.focus_previous = control.get_path_to(focusables[prev_index])

func _cache_text_styles() -> void:
	for node in _get_text_nodes():
		base_font_sizes[node] = node.get_theme_font_size("font_size")
		if node is Label:
			base_line_spacings[node] = node.get_theme_constant("line_spacing")

func _get_text_nodes() -> Array[Control]:
	var nodes: Array[Control] = []
	if word_label != null:
		nodes.append(word_label)
	if sentence_jp_label != null:
		nodes.append(sentence_jp_label)
	if sentence_kana_label != null:
		nodes.append(sentence_kana_label)
	if sentence_en_label != null:
		nodes.append(sentence_en_label)
	if feedback_label != null:
		nodes.append(feedback_label)
	if response_input != null:
		nodes.append(response_input)
	return nodes

func _load_dictionary() -> void:
	dictionary_entries = {}
	frequency_ranks = {}

	var file := FileAccess.open(DICTIONARY_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return

	for index in range(parsed.size()):
		var entry: Dictionary = parsed[index]
		var word_id := str(entry.get("id", ""))
		if word_id == "":
			continue
			dictionary_entries[word_id] = entry
			var rank = entry.get("frequency_rank", null)
			if rank == null:
				rank = index + 10000
			frequency_ranks[word_id] = rank

func _load_sentence_corpus() -> void:
	sentence_corpus = {}

	var file := FileAccess.open(SENTENCE_CORPUS_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return

	for sentence in parsed:
		if typeof(sentence) != TYPE_DICTIONARY:
			continue
		var word_id := str(sentence.get("word_id", ""))
		if word_id == "":
			continue
		if not sentence_corpus.has(word_id):
			sentence_corpus[word_id] = []
		sentence_corpus[word_id].append(sentence)

func _on_back_pressed() -> void:
	_log_incomplete_if_pending()
	back_requested.emit()

func _on_replay_audio() -> void:
	if not current_audio_available:
		if feedback_label != null:
			feedback_label.text = "Audio unavailable; showing text-only prompt."
		return
	if audio_player != null:
		audio_player.stop()
		audio_player.play()
		if feedback_label != null:
			feedback_label.text = "Replaying audio prompt..."

func _on_submit_pressed() -> void:
	_submit_response()

func _on_response_submitted(_text: String) -> void:
	_submit_response()

func _submit_response() -> void:
	if response_input == null or feedback_label == null:
		return
	var response := response_input.text.strip_edges()
	if response.is_empty():
		feedback_label.text = "Please enter a response before submitting."
		return

	var entry := dictionary_entries.get(current_word_id, {})
	var expected_romaji := _normalize_response(str(entry.get("romaji", "")))
	var expected_kana := _normalize_response(str(entry.get("kana", "")))
	var normalized_response := _normalize_response(response)

	var is_correct := normalized_response != "" and (normalized_response == expected_romaji or normalized_response == expected_kana)
	_log_interaction("correct" if is_correct else "incorrect")
	_record_attempt(is_correct)

	if is_correct:
		feedback_label.text = "Correct! Advancing to the next context."
		_select_next_sentence()
	else:
		feedback_label.text = "Not quite. Try matching the context again."
		var word_state := LearnerState.get_word_state(current_word_id)
		if word_state.get("easier_mode", false):
			_apply_easier_mode(true)
			_select_sentence_for_word(current_word_id)
		else:
			_select_next_sentence()

	response_input.text = ""

func _record_attempt(is_correct: bool) -> void:
	if current_word_id == "":
		return
	var word_state := LearnerState.get_word_state(current_word_id)
	var prior_stage := int(word_state.get("stage", STAGE_UNSEEN))
	word_state["exposure_count"] = int(word_state.get("exposure_count", 0)) + 1
	word_state["context_exposures"] = int(word_state.get("context_exposures", 0)) + 1
	word_state["last_seen"] = Time.get_unix_time_from_system()

	var total_sentences := _get_sentence_count(current_word_id)
	var weight := SINGLE_SENTENCE_PROMOTION_WEIGHT if total_sentences <= 1 else 1.0
	var promotion_score := float(word_state.get("promotion_score", 0.0))

	if is_correct:
		word_state["correct_count"] = int(word_state.get("correct_count", 0)) + 1
		word_state["consecutive_incorrect"] = 0
		word_state["easier_mode"] = false
		promotion_score += weight
	else:
		word_state["incorrect_count"] = int(word_state.get("incorrect_count", 0)) + 1
		var failures := int(word_state.get("consecutive_incorrect", 0)) + 1
		word_state["consecutive_incorrect"] = failures
		if failures >= EASY_MODE_FAILURE_THRESHOLD:
			word_state["easier_mode"] = true

	word_state["promotion_score"] = promotion_score

	var updated_stage := _evaluate_promotion(word_state, total_sentences)
	if updated_stage > prior_stage:
		_log_promotion_event(prior_stage, updated_stage)
		word_state["stage"] = updated_stage
		word_state["promotion_score"] = 0.0
		word_state["context_exposures"] = 0
		word_state["used_sentences"] = []
	else:
		word_state["stage"] = updated_stage

	LearnerState.update_word_state(current_word_id, word_state)

func _evaluate_promotion(word_state: Dictionary, total_sentences: int) -> int:
	var stage := int(word_state.get("stage", STAGE_UNSEEN))
	if stage >= STAGE_AUTOMATIC:
		return stage

	var requirements: Dictionary = PROMOTION_REQUIREMENTS.get(stage, {})
	if requirements.is_empty():
		return stage

	var correct_needed := int(requirements.get("correct", 0))
	var exposures_needed := int(requirements.get("exposures", 0))
	var unique_needed := int(requirements.get("unique", 0))
	var unique_seen := int(word_state.get("used_sentences", []).size())
	if total_sentences > 0:
		unique_needed = min(unique_needed, total_sentences)

	var promotion_score := float(word_state.get("promotion_score", 0.0))
	var exposures := int(word_state.get("exposure_count", 0))

	if promotion_score >= correct_needed and exposures >= exposures_needed and unique_seen >= unique_needed:
		return stage + 1

	return stage

func _select_next_sentence() -> void:
	var candidates := _build_candidates()
	if candidates.is_empty():
		return

	var chosen := candidates[0]
	current_word_id = chosen["word_id"]
	_select_sentence_for_word(current_word_id)

func _build_candidates() -> Array:
	var candidates: Array = []
	var stage_filtered: Array = []

	for word_id in sentence_corpus.keys():
		var word_state := LearnerState.get_word_state(word_id)
		var stage := int(word_state.get("stage", STAGE_UNSEEN))
		if stage > STAGE_AUTOMATIC:
			continue
		var target := int(STAGE_EXPOSURE_TARGETS.get(stage, 0))
		var exposures := int(word_state.get("context_exposures", 0))
		var needs_exposure := exposures < target
		var repeat_penalty := 0
		if word_id == last_word_id:
			repeat_penalty = 1
		var rank := int(frequency_ranks.get(word_id, 999999))
		var candidate = {
			"word_id": word_id,
			"needs_exposure": needs_exposure,
			"exposures": exposures,
			"repeat_penalty": repeat_penalty,
			"rank": rank,
			"tie": randf(),
		}
		candidates.append(candidate)
		if needs_exposure:
			stage_filtered.append(candidate)

	var chosen_pool := stage_filtered if not stage_filtered.is_empty() else candidates
	chosen_pool.sort_custom(func(a, b):
		if a[\"needs_exposure\"] != b[\"needs_exposure\"]:
			return a[\"needs_exposure\"]
		if a[\"exposures\"] != b[\"exposures\"]:
			return a[\"exposures\"] < b[\"exposures\"]
		if a[\"repeat_penalty\"] != b[\"repeat_penalty\"]:
			return a[\"repeat_penalty\"] < b[\"repeat_penalty\"]
		if a[\"rank\"] != b[\"rank\"]:
			return a[\"rank\"] < b[\"rank\"]
		return a[\"tie\"] < b[\"tie\"]
	)

	return chosen_pool

func _select_sentence_for_word(word_id: String) -> void:
	var sentences: Array = sentence_corpus.get(word_id, [])
	if sentences.is_empty():
		return

	var word_state := LearnerState.get_word_state(word_id)
	var used_sentences: Array = word_state.get("used_sentences", [])
	if used_sentences.size() >= sentences.size():
		used_sentences = []

	var available: Array = []
	for sentence in sentences:
		var sentence_id := str(sentence.get("id", ""))
		if used_sentences.has(sentence_id):
			continue
		if sentence_id == last_sentence_id and sentences.size() > 1:
			continue
		available.append(sentence)

	if available.is_empty():
		available = sentences

	var chosen_index := randi() % available.size()
	var sentence: Dictionary = available[chosen_index]
	current_sentence = sentence
	last_word_id = word_id
	last_sentence_id = str(sentence.get("id", ""))

	used_sentences.append(last_sentence_id)
	word_state["used_sentences"] = used_sentences
	LearnerState.update_word_state(word_id, word_state)

	_apply_sentence(word_id, sentence)

func _apply_sentence(word_id: String, sentence: Dictionary) -> void:
	var entry := dictionary_entries.get(word_id, {})
	if word_label != null:
		var display_word := str(entry.get("kanji", ""))
		if display_word == "":
			display_word = str(entry.get("kana", ""))
		word_label.text = display_word

	if sentence_jp_label != null:
		sentence_jp_label.text = str(sentence.get("jp", ""))
	if sentence_kana_label != null:
		sentence_kana_label.text = str(sentence.get("kana", ""))
	if sentence_en_label != null:
		sentence_en_label.text = str(sentence.get("en", ""))

	var word_state := LearnerState.get_word_state(word_id)
	var easier_mode := bool(word_state.get("easier_mode", false))
	_apply_easier_mode(easier_mode)
	if not easier_mode and kana_toggle != null:
		_apply_kana_visibility(kana_toggle.button_pressed)

	var stage := int(word_state.get("stage", STAGE_UNSEEN))
	if feedback_label != null:
		var stage_label := STAGE_LABELS.get(stage, "unknown")
		var message := "Stage: %s. Type the response and submit." % stage_label
		if easier_mode:
			message = "Stage: %s. Taking it slow—kana is shown to help." % stage_label
		feedback_label.text = message

	_prepare_audio(sentence)
	_mark_prompt_started()

func _prepare_audio(sentence: Dictionary) -> void:
	current_audio_available = false
	if audio_player != null:
		audio_player.stop()
		audio_player.stream = null

	var audio_path := str(sentence.get("audio", ""))
	if audio_path == "":
		return
	if not ResourceLoader.exists(audio_path):
		return
	var stream := load(audio_path)
	if stream == null:
		return
	if audio_player != null:
		audio_player.stream = stream
		current_audio_available = true
		audio_player.play()

func _apply_easier_mode(enabled: bool) -> void:
	if enabled:
		if kana_toggle != null:
			kana_toggle.button_pressed = true
		_apply_kana_visibility(true)

func _get_sentence_count(word_id: String) -> int:
	return int(sentence_corpus.get(word_id, []).size())

func _normalize_response(text: String) -> String:
	var normalized := text.strip_edges().to_lower()
	normalized = normalized.replace(" ", "")
	normalized = normalized.replace("。", "")
	normalized = normalized.replace("、", "")
	normalized = normalized.replace(".", "")
	normalized = normalized.replace(",", "")
	return normalized

func _on_kana_toggle(pressed: bool) -> void:
	_apply_kana_visibility(pressed)

func _toggle_kana() -> void:
	if kana_toggle == null:
		return
	kana_toggle.button_pressed = not kana_toggle.button_pressed
	_apply_kana_visibility(kana_toggle.button_pressed)

func _apply_kana_visibility(show_kana: bool) -> void:
	if sentence_kana_label != null:
		sentence_kana_label.visible = show_kana

func _on_dyslexia_toggled(pressed: bool) -> void:
	_apply_dyslexia_mode(pressed)

func _apply_dyslexia_mode(enabled: bool) -> void:
	for node in _get_text_nodes():
		var base_size: int = base_font_sizes.get(node, node.get_theme_font_size("font_size"))
		var size := base_size
		if enabled:
			size = int(round(base_size * DYSLEXIA_FONT_SCALE))
		node.add_theme_font_size_override("font_size", size)
		if node is Label:
			var base_spacing: int = base_line_spacings.get(node, node.get_theme_constant("line_spacing"))
			var spacing := base_spacing
			if enabled:
				spacing = DYSLEXIA_LINE_SPACING
			node.add_theme_constant_override("line_spacing", spacing)

func _exit_tree() -> void:
	_log_incomplete_if_pending()

func _mark_prompt_started() -> void:
	prompt_started_msec = Time.get_ticks_msec()
	prompt_pending = true

func _log_interaction(result: String) -> void:
	if current_word_id == "" or current_sentence.is_empty():
		return
	var sentence_id := str(current_sentence.get("id", ""))
	var scene_name := _get_scene_name()
	var response_time_ms := _get_response_time_ms()
	TelemetryLogger.log_event({
		"event_type": "context_lattice_interaction",
		"word_id": current_word_id,
		"sentence_id": sentence_id,
		"scene": scene_name,
		"result": result,
		"response_time_ms": response_time_ms,
	})
	prompt_pending = false

func _log_incomplete_if_pending() -> void:
	if not prompt_pending:
		return
	if current_word_id == "" or current_sentence.is_empty():
		return
	var sentence_id := str(current_sentence.get("id", ""))
	var scene_name := _get_scene_name()
	var response_time_ms := _get_response_time_ms()
	TelemetryLogger.log_event({
		"event_type": "context_lattice_interaction",
		"word_id": current_word_id,
		"sentence_id": sentence_id,
		"scene": scene_name,
		"result": "incomplete",
		"response_time_ms": response_time_ms,
	})
	prompt_pending = false

func _log_promotion_event(prior_stage: int, updated_stage: int) -> void:
	var sentence_id := str(current_sentence.get("id", ""))
	var scene_name := _get_scene_name()
	TelemetryLogger.log_event({
		"event_type": "context_lattice_promotion",
		"word_id": current_word_id,
		"sentence_id": sentence_id,
		"scene": scene_name,
		"from_stage": prior_stage,
		"to_stage": updated_stage,
	})

func _get_response_time_ms() -> int:
	if prompt_started_msec <= 0:
		return 0
	return max(0, Time.get_ticks_msec() - prompt_started_msec)

func _get_scene_name() -> String:
	if get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene.name
	return name
