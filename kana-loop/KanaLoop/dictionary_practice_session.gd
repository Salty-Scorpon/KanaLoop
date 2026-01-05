extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/Panel/VBoxContainer/Header/BackButton
@onready var next_button: Button = $MarginContainer/Panel/VBoxContainer/Controls/NextButton
@onready var status_label: Label = $MarginContainer/Panel/VBoxContainer/StatusLabel
@onready var index_label: Label = $MarginContainer/Panel/VBoxContainer/IndexLabel
@onready var kanji_value: Label = $MarginContainer/Panel/VBoxContainer/WordDetails/KanjiValue
@onready var kana_value: Label = $MarginContainer/Panel/VBoxContainer/WordDetails/KanaValue
@onready var definition_value: Label = $MarginContainer/Panel/VBoxContainer/WordDetails/DefinitionValue
@onready var gloss_value: Label = $MarginContainer/Panel/VBoxContainer/WordDetails/GlossValue

var _entries: Array = []
var _current_index := 0

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	next_button.pressed.connect(_on_next_pressed)

func configure(entry_ids: Array = [], query: Dictionary = {}, limit: int = DictionaryPracticeBridge.DEFAULT_LIMIT) -> void:
	_entries = DictionaryPracticeBridge.select_entries(entry_ids, query, limit)
	_current_index = 0
	_update_display()

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_next_pressed() -> void:
	if _entries.is_empty():
		return
	_current_index = (_current_index + 1) % _entries.size()
	_update_display()

func _update_display() -> void:
	if _entries.is_empty():
		status_label.text = "No practice entries found."
		index_label.text = ""
		kanji_value.text = "—"
		kana_value.text = "—"
		definition_value.text = "—"
		gloss_value.text = "—"
		next_button.disabled = true
		return

	next_button.disabled = false
	var entry: Dictionary = _entries[_current_index]
	status_label.text = "Practice prompt"
	index_label.text = "Item %d of %d" % [_current_index + 1, _entries.size()]
	kanji_value.text = _value_or_placeholder(entry.get("kanji", ""))
	kana_value.text = _value_or_placeholder(entry.get("kana", ""))
	definition_value.text = _value_or_placeholder(entry.get("definition", ""))
	gloss_value.text = _format_gloss(entry.get("gloss", []))

func _value_or_placeholder(value: String) -> String:
	if value.strip_edges() == "":
		return "—"
	return value

func _format_gloss(glosses: Array) -> String:
	if glosses.is_empty():
		return "No gloss available."
	return "; ".join(glosses)
