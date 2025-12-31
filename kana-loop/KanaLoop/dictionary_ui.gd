extends Control

signal back_requested

const INDEX_PATH := "res://jmdict_with_freq.json"
const MAX_RESULTS := 200

const FREQUENCY_OPTIONS := [
	{"label": "Any", "marker": ""},
	{"label": "Top 100", "marker": "top_100"},
	{"label": "Top 500", "marker": "top_500"},
	{"label": "Top 1000", "marker": "top_1000"},
	{"label": "Top 2000", "marker": "top_2000"},
	{"label": "Top 3000", "marker": "top_3000"},
	{"label": "Top 5000", "marker": "top_5000"},
]

const JLPT_OPTIONS := [
	{"label": "Any", "level": null},
	{"label": "N5", "level": 5},
	{"label": "N4", "level": 4},
	{"label": "N3", "level": 3},
	{"label": "N2", "level": 2},
	{"label": "N1", "level": 1},
]

@onready var search_input: LineEdit = $MarginContainer/Panel/VBoxContainer/SearchInput
@onready var frequency_filter: OptionButton = $MarginContainer/Panel/VBoxContainer/Filters/FrequencyFilter
@onready var jlpt_filter: OptionButton = $MarginContainer/Panel/VBoxContainer/Filters/JLPTFilter
@onready var results_list: ItemList = $MarginContainer/Panel/VBoxContainer/ResultsList
@onready var results_count: Label = $MarginContainer/Panel/VBoxContainer/ResultsCount
@onready var back_button: Button = $MarginContainer/Panel/VBoxContainer/Header/BackButton
@onready var status_label: Label = $MarginContainer/Panel/VBoxContainer/StatusLabel

var entries: Array = []

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	search_input.text_changed.connect(_on_search_text_changed)
	frequency_filter.item_selected.connect(_on_filter_changed)
	jlpt_filter.item_selected.connect(_on_filter_changed)

	_load_index()
	_populate_filters()
	_apply_filters()
	search_input.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_DOWN:
				_move_selection(1)
				get_viewport().set_input_as_handled()
			KEY_UP:
				_move_selection(-1)
				get_viewport().set_input_as_handled()

func _load_index() -> void:
	entries.clear()
	if not FileAccess.file_exists(INDEX_PATH):
		status_label.text = "Dictionary index not found."
		status_label.visible = true
		return

	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if file == null:
		status_label.text = "Unable to open dictionary index."
		status_label.visible = true
		return

	var parse_result = JSON.parse_string(file.get_as_text())
	if typeof(parse_result) != TYPE_ARRAY:
		status_label.text = "Dictionary index is not formatted as expected."
		status_label.visible = true
		return

	entries = parse_result
	status_label.visible = false

func _populate_filters() -> void:
	frequency_filter.clear()
	for option in FREQUENCY_OPTIONS:
		frequency_filter.add_item(option.label)
	frequency_filter.select(0)

	jlpt_filter.clear()
	for option in JLPT_OPTIONS:
		jlpt_filter.add_item(option.label)
	jlpt_filter.select(0)

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_search_text_changed(_new_text: String) -> void:
	_apply_filters()

func _on_filter_changed(_index: int) -> void:
	_apply_filters()

func _apply_filters() -> void:
	results_list.clear()

	if entries.is_empty():
		results_count.text = "No entries loaded."
		return

	var query := search_input.text.strip_edges().to_lower()
	var frequency_marker := FREQUENCY_OPTIONS[frequency_filter.selected].marker
	var jlpt_level = JLPT_OPTIONS[jlpt_filter.selected].level

	var matched := 0
	var shown := 0

	for entry in entries:
		if not _matches_filters(entry, query, frequency_marker, jlpt_level):
			continue
		matched += 1
		if shown < MAX_RESULTS:
			results_list.add_item(_format_entry(entry))
			shown += 1

	results_count.text = "Showing %d of %d results" % [shown, matched]
	if shown > 0:
		results_list.select(0)

func _matches_filters(entry: Dictionary, query: String, frequency_marker: String, jlpt_level) -> bool:
	if query != "":
		var searchable := _entry_search_blob(entry)
		if searchable.find(query) == -1:
			return false

	if frequency_marker != "":
		var markers: Array = entry.get("frequency_band_markers", [])
		if not markers.has(frequency_marker):
			return false

	if jlpt_level != null:
		if entry.get("jlpt") != jlpt_level:
			return false

	return true

func _entry_search_blob(entry: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(str(entry.get("kanji", "")))
	parts.append(str(entry.get("kana", "")))
	parts.append(str(entry.get("romaji", "")))
	parts.append(str(entry.get("definition", "")))
	var glosses: Array = entry.get("gloss", [])
	if glosses.size() > 0:
		parts.append(" ".join(glosses))
	return " ".join(parts).to_lower()

func _format_entry(entry: Dictionary) -> String:
	var kanji := str(entry.get("kanji", ""))
	var kana := str(entry.get("kana", ""))
	var definition := str(entry.get("definition", ""))
	if kanji == "":
		return "%s — %s" % [kana, definition]
	return "%s (%s) — %s" % [kanji, kana, definition]

func _move_selection(delta: int) -> void:
	if results_list.item_count == 0:
		return

	var current := results_list.get_selected_items()
	var index := 0
	if current.size() > 0:
		index = current[0]
	index = clamp(index + delta, 0, results_list.item_count - 1)
	results_list.select(index)
	results_list.ensure_current_is_visible()
	results_list.grab_focus()
