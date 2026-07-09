class_name Team
extends RefCounted

var id: String
var competition_id: String
var display_name: String
var short_name: String
var player_ids: Array[String] = []
var metadata: Dictionary = {}

func _init(p_id: String = "", p_competition_id: String = "", p_display_name: String = "") -> void:
	id = p_id if not p_id.is_empty() else DataModelUtils.generate_id("team")
	competition_id = p_competition_id
	display_name = p_display_name

func add_player_id(player_id: String) -> void:
	if DataModelUtils.has_stable_id(player_id) and not player_ids.has(player_id):
		player_ids.append(player_id)

func is_valid() -> bool:
	return DataModelUtils.has_stable_id(id) and DataModelUtils.has_stable_id(competition_id) and not display_name.strip_edges().is_empty()

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not DataModelUtils.has_stable_id(id): errors.append("Team requires a stable id.")
	if not DataModelUtils.has_stable_id(competition_id): errors.append("Team requires competition_id.")
	if display_name.strip_edges().is_empty(): errors.append("Team requires display_name.")
	return errors

func to_dict() -> Dictionary:
	return {"id": id, "competition_id": competition_id, "display_name": display_name, "short_name": short_name, "player_ids": player_ids.duplicate(), "metadata": metadata.duplicate(true)}

static func from_dict(data: Dictionary) -> Team:
	var model := Team.new(DataModelUtils.string_value(data, "id"), DataModelUtils.string_value(data, "competition_id"), DataModelUtils.string_value(data, "display_name"))
	model.short_name = DataModelUtils.string_value(data, "short_name")
	model.player_ids = DataModelUtils.string_array(data.get("player_ids", []))
	model.metadata = DataModelUtils.dict_value(data, "metadata")
	return model
