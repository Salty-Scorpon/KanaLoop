extends PanelContainer

class_name WordDetailPanel

signal practice_requested(entry: Dictionary)

@onready var kanji_value: Label = $MarginContainer/VBoxContainer/KanjiValue
@onready var kana_value: Label = $MarginContainer/VBoxContainer/KanaValue
@onready var gloss_value: Label = $MarginContainer/VBoxContainer/GlossValue
@onready var examples_value: Label = $MarginContainer/VBoxContainer/ExamplesValue
@onready var frequency_value: Label = $MarginContainer/VBoxContainer/FrequencyValue
@onready var tags_value: Label = $MarginContainer/VBoxContainer/TagsValue
@onready var add_to_study_button: Button = $MarginContainer/VBoxContainer/Actions/AddToStudyButton
@onready var mark_known_button: Button = $MarginContainer/VBoxContainer/Actions/MarkKnownButton
@onready var practice_button: Button = $MarginContainer/VBoxContainer/Actions/PracticeButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/Header/CloseButton

var _entry: Dictionary = {}

func _ready() -> void:
	add_to_study_button.pressed.connect(_on_add_to_study)
	mark_known_button.pressed.connect(_on_mark_known)
	practice_button.pressed.connect(_on_practice)
	close_button.pressed.connect(_on_close_pressed)

func set_entry(entry: Dictionary) -> void:
	_entry = entry
	visible = true

	kanji_value.text = _value_or_placeholder(entry.get("kanji", ""))
	kana_value.text = _value_or_placeholder(entry.get("kana", ""))

	var glosses: Array = entry.get("gloss", [])
	if glosses.is_empty():
		gloss_value.text = "No gloss available."
	else:
		gloss_value.text = "; ".join(glosses)

	var examples: Array = entry.get("examples", [])
	if examples.is_empty():
		examples_value.text = "No examples available."
	else:
		examples_value.text = "\n".join(examples)

	frequency_value.text = _format_frequency(entry)

	var tags: Array = entry.get("tags", [])
	if tags.is_empty():
		tags_value.text = "No tags."
	else:
		tags_value.text = ", ".join(tags)

func clear() -> void:
	_entry = {}
	visible = false

func _on_add_to_study() -> void:
	if _entry.is_empty():
		return
	LearnerState.add_to_study(_entry)

func _on_mark_known() -> void:
	if _entry.is_empty():
		return
	LearnerState.mark_known(_entry)

func _on_practice() -> void:
	if _entry.is_empty():
		return
	practice_requested.emit(_entry)

func _on_close_pressed() -> void:
	clear()

func _value_or_placeholder(value: String) -> String:
	if value.strip_edges() == "":
		return "—"
	return value

func _format_frequency(entry: Dictionary) -> String:
	var parts: Array[String] = []
	var frequency = entry.get("frequency", null)
	if frequency != null:
		parts.append("Frequency: %s" % str(frequency))
	var rank = entry.get("frequency_rank", null)
	if rank != null:
		parts.append("Rank: %s" % str(rank))
	var bands: Array = entry.get("frequency_band_markers", [])
	if not bands.is_empty():
		parts.append("Bands: %s" % ", ".join(bands))
	if parts.is_empty():
		return "No frequency data."
	return " | ".join(parts)
