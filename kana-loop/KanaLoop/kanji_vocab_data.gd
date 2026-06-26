extends Node

const DATA_PATH := "res://assets/data/kanji_vocab_strokes.json"
const REQUIRED_TEXT_FIELDS := ["id", "kanji", "word", "reading", "meaning"]

var entries: Array[Dictionary] = []
var entries_by_id: Dictionary = {}
var loaded := false
var last_error := ""

func _ready() -> void:
	load_entries()

func reload() -> Array[Dictionary]:
	loaded = false
	entries.clear()
	entries_by_id.clear()
	last_error = ""
	return load_entries(true)

func load_entries(force: bool = false) -> Array[Dictionary]:
	if loaded and not force:
		return get_entries()
	loaded = true
	entries.clear()
	entries_by_id.clear()
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
	for value in selected_values:
		if tags.has("%s%d" % [prefix, int(value)]):
			return true
	return false

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
