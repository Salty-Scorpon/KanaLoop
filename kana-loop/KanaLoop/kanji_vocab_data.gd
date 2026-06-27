extends Node

const DATA_PATH := "res://assets/data/kanji_vocab_strokes.json"
const STUDY_GROUPS_PATH := "res://assets/data/kanji_vocab_study_groups.json"
const REQUIRED_TEXT_FIELDS := ["id", "kanji", "word", "reading", "meaning"]

var entries: Array[Dictionary] = []
var entries_by_id: Dictionary = {}
var study_group_metadata_by_entry_id: Dictionary = {}
var loaded := false
var last_error := ""

func _ready() -> void:
	load_entries()

func reload() -> Array[Dictionary]:
	loaded = false
	entries.clear()
	entries_by_id.clear()
	study_group_metadata_by_entry_id.clear()
	last_error = ""
	return load_entries(true)

func load_entries(force: bool = false) -> Array[Dictionary]:
	if loaded and not force:
		return get_entries()
	loaded = true
	entries.clear()
	entries_by_id.clear()
	study_group_metadata_by_entry_id = _load_study_group_metadata()
	last_error = ""

	if not FileAccess.file_exists(DATA_PATH):
		last_error = "Kanji vocabulary data not found at %s" % DATA_PATH
		return []

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		last_error = "Unable to open kanji vocabulary data at %s" % DATA_PATH
		push_warning(last_error)
		return []

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		last_error = "Kanji vocabulary data must be a JSON array."
		push_warning(last_error)
		return []

	var raw_entries: Array = parsed
	for index in range(raw_entries.size()):
		var normalized_entry := _normalize_entry(raw_entries[index], index)
		if normalized_entry.is_empty():
			continue
		var entry_id := String(normalized_entry.get("id", ""))
		if entries_by_id.has(entry_id):
			push_warning("Duplicate kanji vocabulary id skipped: %s" % entry_id)
			continue
		entries.append(normalized_entry)
		entries_by_id[entry_id] = normalized_entry
	return get_entries()

func has_entries() -> bool:
	return load_entries().size() > 0

func get_entries() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry in entries:
		copy.append(entry.duplicate(true))
	return copy

func get_entry_by_id(entry_id: String) -> Dictionary:
	load_entries()
	var entry: Dictionary = entries_by_id.get(entry_id, {})
	return entry.duplicate(true)

func get_last_error() -> String:
	return last_error

func _load_study_group_metadata() -> Dictionary:
	var metadata_by_entry_id := {}
	if not FileAccess.file_exists(STUDY_GROUPS_PATH):
		return metadata_by_entry_id
	var file := FileAccess.open(STUDY_GROUPS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to open kanji vocabulary study groups at %s" % STUDY_GROUPS_PATH)
		return metadata_by_entry_id
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Kanji vocabulary study groups must be a JSON object.")
		return metadata_by_entry_id
	var payload: Dictionary = parsed
	for group_value in payload.get("groups", []):
		if typeof(group_value) != TYPE_DICTIONARY:
			continue
		var group: Dictionary = group_value
		var group_index := int(group.get("index", 0))
		for record_value in group.get("records", []):
			if typeof(record_value) != TYPE_DICTIONARY:
				continue
			var record: Dictionary = record_value
			var metadata := {
				"group_index": group_index,
				"group_id": String(group.get("id", "")),
				"group_label": String(group.get("label", "Group %03d" % group_index)),
				"group_order": int(record.get("group_order", 0)),
				"sentence_ok_for_group": bool(record.get("sentence_ok_for_group", true)),
				"word_kanji": _normalize_string_array(record.get("word_kanji", [])),
				"sentence_kanji": _normalize_string_array(record.get("sentence_kanji", [])),
				"collateral_kanji": _normalize_string_array(record.get("collateral_kanji", [])),
				"unlearned_sentence_kanji": _normalize_string_array(record.get("unlearned_sentence_kanji", [])),
			}
			if record.has("optimized_vocab_index"):
				metadata["optimized_vocab_index"] = int(record.get("optimized_vocab_index", 0))
			for entry_id in record.get("entry_ids", []):
				var entry_id_text := String(entry_id)
				if entry_id_text != "":
					metadata_by_entry_id[entry_id_text] = metadata.duplicate(true)
	return metadata_by_entry_id

func get_available_decks() -> Array[String]:
	load_entries()
	var decks: Array[String] = []
	var seen := {}
	for entry in entries:
		var deck := String(entry.get("deck", ""))
		if deck == "" or seen.has(deck):
			continue
		seen[deck] = true
		decks.append(deck)
	decks.sort()
	return decks

func get_available_tags() -> Array[String]:
	load_entries()
	var tags: Array[String] = []
	var seen := {}
	for entry in entries:
		for tag in entry.get("tags", []):
			var tag_text := String(tag)
			if tag_text == "" or seen.has(tag_text):
				continue
			seen[tag_text] = true
			tags.append(tag_text)
	tags.sort()
	return tags

func get_available_tag_numbers(prefix: String) -> Array[int]:
	load_entries()
	var numbers: Array[int] = []
	var seen := {}
	for entry in entries:
		_add_tag_numbers(entry, prefix, numbers, seen)
	numbers.sort()
	return numbers

func get_available_study_group_numbers() -> Array[int]:
	load_entries()
	var numbers: Array[int] = []
	var seen := {}
	for entry in entries:
		var group_index := _entry_study_group_number(entry)
		if group_index > 0 and not seen.has(group_index):
			seen[group_index] = true
			numbers.append(group_index)
		_add_tag_numbers(entry, "study_group_", numbers, seen)
	numbers.sort()
	return numbers

func get_active_practice_entries() -> Array[Dictionary]:
	return get_filtered_entries(KanaState.get_kanji_practice_filters())

func get_filtered_entries(filters: Dictionary = {}) -> Array[Dictionary]:
	load_entries()
	var filtered: Array[Dictionary] = []
	for entry in entries:
		if not _entry_matches_filters(entry, filters):
			continue
		filtered.append(entry.duplicate(true))
	filtered.sort_custom(_compare_practice_entries)
	return filtered

func _entry_matches_filters(entry: Dictionary, filters: Dictionary) -> bool:
	if filters.is_empty():
		return true

	if _filter_array_has_values(filters, "ids") and not filters["ids"].has(String(entry.get("id", ""))):
		return false
	if _filter_array_has_values(filters, "kanji") and not filters["kanji"].has(String(entry.get("kanji", ""))):
		return false
	if _filter_array_has_values(filters, "decks") and not filters["decks"].has(String(entry.get("deck", ""))):
		return false
	if _filter_array_has_values(filters, "tags") and not _has_any_tag(entry, filters["tags"]):
		return false
	if _filter_array_has_values(filters, "weeks") and not _has_any_tag_number(entry, "week_", filters["weeks"]):
		return false
	if _filter_array_has_values(filters, "days") and not _has_any_tag_number(entry, "day_", filters["days"]):
		return false
	if _filter_array_has_values(filters, "study_groups") and not _has_study_group_number(entry, filters["study_groups"]):
		return false
	if bool(filters.get("require_strokes", false)) and bool(entry.get("missing_strokes", false)):
		return false
	if bool(filters.get("require_audio", false)) and _audio_paths(entry).is_empty():
		return false
	if bool(filters.get("require_sentences", false)) and not _has_sample_sentences(entry):
		return false
	return true

func _filter_array_has_values(filters: Dictionary, key: String) -> bool:
	if not filters.has(key):
		return false
	var value: Variant = filters[key]
	return typeof(value) == TYPE_ARRAY and not value.is_empty()

func _has_any_tag(entry: Dictionary, selected_tags: Array) -> bool:
	var tags: Array = entry.get("tags", [])
	for tag in selected_tags:
		if tags.has(String(tag)):
			return true
	return false

func _has_any_tag_number(entry: Dictionary, prefix: String, selected_values: Array) -> bool:
	var tags: Array = entry.get("tags", [])
	for tag in tags:
		var tag_text := String(tag)
		if not tag_text.begins_with(prefix):
			continue
		var value_string := tag_text.trim_prefix(prefix)
		if value_string.is_valid_int() and selected_values.has(int(value_string)):
			return true
	return false

func _has_study_group_number(entry: Dictionary, selected_values: Array) -> bool:
	var group_index := _entry_study_group_number(entry)
	if group_index > 0 and selected_values.has(group_index):
		return true
	return _has_any_tag_number(entry, "study_group_", selected_values)

func _entry_study_group_number(entry: Dictionary) -> int:
	var study: Dictionary = entry.get("study", {})
	if study.has("group_index"):
		return int(study.get("group_index", 0))
	return _first_tag_number(entry, "study_group_")

func _entry_group_order(entry: Dictionary) -> int:
	var study: Dictionary = entry.get("study", {})
	if study.has("group_order"):
		return int(study.get("group_order", 0))
	return 0

func _entry_optimized_index(entry: Dictionary) -> int:
	if entry.has("optimized_vocab_index"):
		return int(entry.get("optimized_vocab_index", 0))
	var study: Dictionary = entry.get("study", {})
	if study.has("optimized_vocab_index"):
		return int(study.get("optimized_vocab_index", 0))
	return 0

func _compare_practice_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_group := _entry_study_group_number(left)
	var right_group := _entry_study_group_number(right)
	if left_group != right_group:
		return left_group < right_group
	var left_order := _entry_group_order(left)
	var right_order := _entry_group_order(right)
	if left_order != right_order:
		return left_order < right_order
	var left_index := _entry_optimized_index(left)
	var right_index := _entry_optimized_index(right)
	if left_index != right_index:
		return left_index < right_index
	var left_note := int(left.get("note_id", 0))
	var right_note := int(right.get("note_id", 0))
	if left_note != right_note:
		return left_note < right_note
	return String(left.get("id", "")) < String(right.get("id", ""))

func _first_tag_number(entry: Dictionary, prefix: String) -> int:
	for tag in entry.get("tags", []):
		var tag_text := String(tag)
		if not tag_text.begins_with(prefix):
			continue
		var value_string := tag_text.trim_prefix(prefix)
		if value_string.is_valid_int():
			return int(value_string)
	return 0

func _add_tag_numbers(entry: Dictionary, prefix: String, numbers: Array[int], seen: Dictionary) -> void:
	for tag in entry.get("tags", []):
		var tag_text := String(tag)
		if not tag_text.begins_with(prefix):
			continue
		var value_string := tag_text.trim_prefix(prefix)
		if not value_string.is_valid_int():
			continue
		var value := int(value_string)
		if seen.has(value):
			continue
		seen[value] = true
		numbers.append(value)

func _audio_paths(entry: Dictionary) -> Array[String]:
	var paths: Array[String] = []
	var audio: Dictionary = entry.get("audio", {})
	for key in audio.keys():
		var path := String(audio[key])
		if path != "":
			paths.append(path)
	return paths

func _has_sample_sentences(entry: Dictionary) -> bool:
	var sentence: Dictionary = entry.get("sample_sentence", {})
	return String(sentence.get("ja", "")) != "" and String(sentence.get("en", "")) != ""

func _normalize_entry(raw_entry: Variant, index: int) -> Dictionary:
	if typeof(raw_entry) != TYPE_DICTIONARY:
		push_warning("Kanji vocabulary entry %d is not an object and was skipped." % index)
		return {}

	var entry: Dictionary = raw_entry.duplicate(true)
	for field in REQUIRED_TEXT_FIELDS:
		entry[field] = String(entry.get(field, "")).strip_edges()
		if entry[field] == "":
			push_warning("Kanji vocabulary entry %d missing required field: %s" % [index, field])
			return {}

	var sample_sentence := _normalize_dictionary(entry.get("sample_sentence", {}))
	sample_sentence["ja"] = String(sample_sentence.get("ja", ""))
	sample_sentence["en"] = String(sample_sentence.get("en", ""))
	var strokes := _normalize_array(entry.get("strokes", []))
	entry["sample_sentence"] = sample_sentence
	entry["audio"] = _normalize_audio(entry.get("audio", {}))
	entry["tags"] = _normalize_string_array(entry.get("tags", []))
	entry["deck"] = String(entry.get("deck", ""))
	entry["note_id"] = int(entry.get("note_id", 0))
	entry["model"] = String(entry.get("model", ""))
	entry["stroke_count"] = int(entry.get("stroke_count", 0))
	entry["strokes"] = strokes
	entry["missing_strokes"] = bool(entry.get("missing_strokes", strokes.is_empty()))
	entry["source"] = _normalize_dictionary(entry.get("source", {}))
	entry["study"] = _normalize_dictionary(entry.get("study", {}))
	var study_metadata: Dictionary = study_group_metadata_by_entry_id.get(String(entry.get("id", "")), {})
	if not study_metadata.is_empty():
		var merged_study: Dictionary = study_metadata.duplicate(true)
		for key in entry["study"].keys():
			merged_study[key] = entry["study"][key]
		entry["study"] = merged_study
	if entry.has("optimized_vocab_index"):
		entry["optimized_vocab_index"] = int(entry.get("optimized_vocab_index", 0))
	return entry

func _normalize_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return {}

func _normalize_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return []

func _normalize_string_array(value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return normalized
	for item in value:
		var text := String(item).strip_edges()
		if text == "":
			continue
		normalized.append(text)
	return normalized

func _normalize_audio(value: Variant) -> Dictionary:
	var normalized := {}
	if typeof(value) != TYPE_DICTIONARY:
		return normalized
	var audio: Dictionary = value
	for key in ["kanji", "word", "sentence_ja", "meaning_en"]:
		var path := String(audio.get(key, "")).strip_edges()
		if path != "":
			normalized[key] = path
	return normalized
