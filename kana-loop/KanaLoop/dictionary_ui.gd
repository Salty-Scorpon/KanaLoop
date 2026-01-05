extends Control

signal back_requested

const INDEX_PATH := "res://assets/data/dictionary_3000_common_words.json"
const MAX_RESULTS := 200

@onready var search_input: LineEdit = $MarginContainer/Panel/VBoxContainer/SearchInput
@onready var results_list: ItemList = $MarginContainer/Panel/VBoxContainer/ResultsList
@onready var results_count: Label = $MarginContainer/Panel/VBoxContainer/ResultsCount
@onready var back_button: Button = $MarginContainer/Panel/VBoxContainer/Header/BackButton
@onready var status_label: Label = $MarginContainer/Panel/VBoxContainer/StatusLabel
@onready var detail_panel: WordDetailPanel = $MarginContainer/Panel/VBoxContainer/WordDetailPanel

var entries: Array = []
var visible_entries: Array = []

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	search_input.text_changed.connect(_on_search_text_changed)
	results_list.item_selected.connect(_on_result_selected)

	_load_index()
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

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_search_text_changed(_new_text: String) -> void:
	_apply_filters()

func _apply_filters() -> void:
	results_list.clear()
	visible_entries.clear()

	if entries.is_empty():
		results_count.text = "No entries loaded."
		detail_panel.clear()
		return

	var query := search_input.text.strip_edges().to_lower()
	var selected_weeks := KanaState.get_selected_dictionary_weeks()
	var selected_days := KanaState.get_selected_dictionary_days()

	var matched_entries: Array = []
	for entry in entries:
		if not _matches_filters(entry, query, selected_weeks, selected_days):
			continue
		matched_entries.append(entry)

	var matched := matched_entries.size()
	var shown: int = min(MAX_RESULTS, matched_entries.size())
	for entry_index in range(shown):
		var entry: Dictionary = matched_entries[entry_index]
		results_list.add_item(_format_entry(entry))
		visible_entries.append(entry)

	results_count.text = "Showing %d of %d results" % [shown, matched]
	if shown > 0:
		results_list.select(0)
		detail_panel.set_entry(visible_entries[0])
	else:
		detail_panel.clear()

func _matches_filters(entry: Dictionary, query: String, selected_weeks: Array[int], selected_days: Array[int]) -> bool:
	if query != "":
		var searchable := _entry_search_blob(entry)
		if searchable.find(query) == -1:
			return false

	if selected_weeks.size() > 0 and not _has_tag(entry, "week_", selected_weeks):
		return false

	if selected_days.size() > 0 and not _has_tag(entry, "day_", selected_days):
		return false

	return true

func _has_tag(entry: Dictionary, prefix: String, selected_values: Array[int]) -> bool:
	var tags: Array = entry.get("tags", [])
	for value in selected_values:
		if tags.has("%s%d" % [prefix, value]):
			return true
	return false

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

func _on_result_selected(index: int) -> void:
	if index < 0 or index >= visible_entries.size():
		return
	detail_panel.set_entry(visible_entries[index])
