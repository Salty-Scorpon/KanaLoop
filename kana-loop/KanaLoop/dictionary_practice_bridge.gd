class_name DictionaryPracticeBridge

const INDEX_PATH := "res://jmdict_with_freq.json"
const DEFAULT_LIMIT := 20

static var _cached_entries: Array = []

static func select_entries(entry_ids: Array = [], query: Dictionary = {}, limit: int = DEFAULT_LIMIT) -> Array:
	var entries := _load_entries()
	if entries.is_empty():
		return []

	var required_entries: Array = []
	var filtered_entries := _filter_by_query(entries, query)

	if not entry_ids.is_empty():
		var entry_id_set := _to_set(entry_ids)
		for entry in entries:
			var entry_id := str(entry.get("id", ""))
			if entry_id != "" and entry_id_set.has(entry_id):
				required_entries.append(entry)

	var state := LearnerState.load_state()
	var known_set := _to_set(state.get("known", []))
	var study_set := _to_set(state.get("study", []))

	var candidates: Array = []
	if filtered_entries.is_empty():
		filtered_entries = entries

	for entry in filtered_entries:
		var entry_id := str(entry.get("id", ""))
		if entry_id != "" and known_set.has(entry_id):
			continue
		candidates.append(entry)

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _compare_entries(a, b, study_set)
	)

	var combined := required_entries.duplicate()
	for entry in candidates:
		if combined.size() >= limit:
			break
		combined.append(entry)

	if combined.size() > limit:
		combined = combined.slice(0, limit)

	return combined

static func _load_entries() -> Array:
	if not _cached_entries.is_empty():
		return _cached_entries
	if not FileAccess.file_exists(INDEX_PATH):
		return []
	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		_cached_entries = parsed
	return _cached_entries

static func _filter_by_query(entries: Array, query: Dictionary) -> Array:
	var query_text := str(query.get("text", "")).strip_edges().to_lower()
	var frequency_marker := str(query.get("frequency_marker", ""))
	var jlpt_level = query.get("jlpt_level", null)

	var results: Array = []
	for entry in entries:
		if query_text != "":
			var searchable := _entry_search_blob(entry)
			if searchable.find(query_text) == -1:
				continue
		if frequency_marker != "":
			var markers: Array = entry.get("frequency_band_markers", [])
			if not markers.has(frequency_marker):
				continue
		if jlpt_level != null:
			if entry.get("jlpt") != jlpt_level:
				continue
		results.append(entry)

	return results

static func _entry_search_blob(entry: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(str(entry.get("kanji", "")))
	parts.append(str(entry.get("kana", "")))
	parts.append(str(entry.get("romaji", "")))
	parts.append(str(entry.get("definition", "")))
	var glosses: Array = entry.get("gloss", [])
	if glosses.size() > 0:
		parts.append(" ".join(glosses))
	return " ".join(parts).to_lower()

static func _to_set(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		result[str(value)] = true
	return result

static func _compare_entries(a: Dictionary, b: Dictionary, study_set: Dictionary) -> bool:
	var a_id := str(a.get("id", ""))
	var b_id := str(b.get("id", ""))
	var a_study := study_set.has(a_id)
	var b_study := study_set.has(b_id)
	if a_study != b_study:
		return a_study

	var a_rank := _rank_value(a)
	var b_rank := _rank_value(b)
	if a_rank != b_rank:
		return a_rank < b_rank

	var a_kana := str(a.get("kana", ""))
	var b_kana := str(b.get("kana", ""))
	if a_kana != b_kana:
		return a_kana < b_kana
	return str(a.get("kanji", "")) < str(b.get("kanji", ""))

static func _rank_value(entry: Dictionary) -> int:
	var rank = entry.get("frequency_rank", null)
	if rank == null:
		return 2147483647
	return int(rank)
