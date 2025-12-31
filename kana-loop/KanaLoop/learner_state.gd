class_name LearnerState

const STATE_PATH := "user://learner_state.json"

static func load_state() -> Dictionary:
	var state: Dictionary = {
		"study": [],
		"known": [],
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
