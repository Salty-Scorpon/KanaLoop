class_name ManualStatEntry
extends RefCounted

var id: String
var game_id: String
var team_id: String
var player_id: String
var stat_key: String
var value: float = 0.0
var entered_by: String
var created_at: int = 0
var metadata: Dictionary = {}

func _init(p_id: String = "", p_game_id: String = "", p_stat_key: String = "") -> void:
	id = p_id if not p_id.is_empty() else DataModelUtils.generate_id("stat")
	game_id = p_game_id
	stat_key = p_stat_key
	created_at = int(Time.get_unix_time_from_system())

func is_valid() -> bool:
	return DataModelUtils.has_stable_id(id) and DataModelUtils.has_stable_id(game_id) and (DataModelUtils.has_stable_id(team_id) or DataModelUtils.has_stable_id(player_id)) and not stat_key.strip_edges().is_empty()

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not DataModelUtils.has_stable_id(id): errors.append("ManualStatEntry requires a stable id.")
	if not DataModelUtils.has_stable_id(game_id): errors.append("ManualStatEntry requires game_id.")
	if not DataModelUtils.has_stable_id(team_id) and not DataModelUtils.has_stable_id(player_id): errors.append("ManualStatEntry requires team_id or player_id.")
	if stat_key.strip_edges().is_empty(): errors.append("ManualStatEntry requires stat_key.")
	return errors

func to_dict() -> Dictionary:
	return {"id": id, "game_id": game_id, "team_id": team_id, "player_id": player_id, "stat_key": stat_key, "value": value, "entered_by": entered_by, "created_at": created_at, "metadata": metadata.duplicate(true)}

static func from_dict(data: Dictionary) -> ManualStatEntry:
	var model := ManualStatEntry.new(DataModelUtils.string_value(data, "id"), DataModelUtils.string_value(data, "game_id"), DataModelUtils.string_value(data, "stat_key"))
	model.team_id = DataModelUtils.string_value(data, "team_id")
	model.player_id = DataModelUtils.string_value(data, "player_id")
	model.value = DataModelUtils.float_value(data, "value")
	model.entered_by = DataModelUtils.string_value(data, "entered_by")
	model.created_at = DataModelUtils.int_value(data, "created_at", int(Time.get_unix_time_from_system()))
	model.metadata = DataModelUtils.dict_value(data, "metadata")
	return model
