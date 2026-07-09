class_name GameEvent
extends RefCounted

var id: String
var game_id: String
var team_id: String
var player_id: String
var event_type: String
var value: float = 0.0
var occurred_at: int = 0
var metadata: Dictionary = {}

func _init(p_id: String = "", p_game_id: String = "", p_event_type: String = "") -> void:
	id = p_id if not p_id.is_empty() else DataModelUtils.generate_id("event")
	game_id = p_game_id
	event_type = p_event_type

func is_valid() -> bool:
	return DataModelUtils.has_stable_id(id) and DataModelUtils.has_stable_id(game_id) and not event_type.strip_edges().is_empty()

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not DataModelUtils.has_stable_id(id): errors.append("GameEvent requires a stable id.")
	if not DataModelUtils.has_stable_id(game_id): errors.append("GameEvent requires game_id.")
	if event_type.strip_edges().is_empty(): errors.append("GameEvent requires event_type.")
	return errors

func to_dict() -> Dictionary:
	return {"id": id, "game_id": game_id, "team_id": team_id, "player_id": player_id, "event_type": event_type, "value": value, "occurred_at": occurred_at, "metadata": metadata.duplicate(true)}

static func from_dict(data: Dictionary) -> GameEvent:
	var model := GameEvent.new(DataModelUtils.string_value(data, "id"), DataModelUtils.string_value(data, "game_id"), DataModelUtils.string_value(data, "event_type"))
	model.team_id = DataModelUtils.string_value(data, "team_id")
	model.player_id = DataModelUtils.string_value(data, "player_id")
	model.value = DataModelUtils.float_value(data, "value")
	model.occurred_at = DataModelUtils.int_value(data, "occurred_at")
	model.metadata = DataModelUtils.dict_value(data, "metadata")
	return model
