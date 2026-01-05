class_name LearnerState

const STATE_PATH := "user://learner_state.json"

static func load_state() -> Dictionary:
	var state: Dictionary = {
		"study": [],
		"known": [],
		"context_lattice": {},
	}

	if not FileAccess.file_exists(STATE_PATH):
		return state

	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return state

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		state = parsed

	_normalize_state(state)
	return state

static func save_state(state: Dictionary) -> void:
	_normalize_state(state)

	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(state, "\t"))

static func load_context_lattice() -> Dictionary:
	var state := load_state()
	var lattice: Dictionary = state.get("context_lattice", {})
	return lattice.duplicate(true)

static func save_context_lattice(context_lattice: Dictionary) -> void:
	var state := load_state()
	state["context_lattice"] = context_lattice
	save_state(state)

static func get_word_state(word_id: String) -> Dictionary:
	var key := str(word_id)
	if key == "":
		return {}

	var state := load_state()
	var lattice: Dictionary = state.get("context_lattice", {})
	var word_state: Dictionary = _normalize_word_state(lattice.get(key, {}))
	lattice[key] = word_state
	state["context_lattice"] = lattice
	save_state(state)
	return word_state.duplicate(true)

static func update_word_state(word_id: String, update_dict: Dictionary) -> void:
	var key := str(word_id)
	if key == "":
		return

	var state := load_state()
	var lattice: Dictionary = state.get("context_lattice", {})
	var word_state: Dictionary = _normalize_word_state(lattice.get(key, {}))
	word_state.merge(update_dict, true)
	lattice[key] = _normalize_word_state(word_state)
	state["context_lattice"] = lattice
	save_state(state)

static func reset_context_exposures(word_id: String) -> void:
	update_word_state(word_id, {
		"context_exposures": 0,
	})

static func add_to_study(entry: Dictionary) -> void:
	var state := load_state()
	var entry_id := str(entry.get("id", ""))
	if entry_id == "":
		return

	var study: Array = state.get("study", [])
	if not study.has(entry_id):
		study.append(entry_id)
	state["study"] = study

	save_state(state)

static func mark_known(entry: Dictionary) -> void:
	var state := load_state()
	var entry_id := str(entry.get("id", ""))
	if entry_id == "":
		return

	var known: Array = state.get("known", [])
	if not known.has(entry_id):
		known.append(entry_id)
	state["known"] = known

	var study: Array = state.get("study", [])
	if study.has(entry_id):
		study.erase(entry_id)
		state["study"] = study

	save_state(state)

static func _normalize_state(state: Dictionary) -> void:
	if not state.has("study") or typeof(state["study"]) != TYPE_ARRAY:
		state["study"] = []
	if not state.has("known") or typeof(state["known"]) != TYPE_ARRAY:
		state["known"] = []
	if not state.has("context_lattice") or typeof(state["context_lattice"]) != TYPE_DICTIONARY:
		state["context_lattice"] = {}

	var lattice: Dictionary = state.get("context_lattice", {})
	for word_id in lattice.keys():
		lattice[word_id] = _normalize_word_state(lattice.get(word_id, {}))
	state["context_lattice"] = lattice

static func _default_word_state() -> Dictionary:
	return {
		"stage": 0,
		"exposure_count": 0,
		"context_exposures": 0,
		"correct_count": 0,
		"incorrect_count": 0,
		"promotion_score": 0.0,
		"used_sentences": [],
		"consecutive_incorrect": 0,
		"easier_mode": false,
		"last_seen": 0,
		"fast_correct_recalls": 0,
		"last_correct_ms": 0,
		"best_correct_ms": 0,
	}

static func _normalize_word_state(word_state: Dictionary) -> Dictionary:
	var normalized := _default_word_state()
	if typeof(word_state) == TYPE_DICTIONARY:
		for key in word_state.keys():
			normalized[key] = word_state[key]
	return normalized
