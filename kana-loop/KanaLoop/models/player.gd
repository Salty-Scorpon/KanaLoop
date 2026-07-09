class_name Player
extends RefCounted

var id: String
var team_id: String
var display_name: String
var jersey_number: String
var metadata: Dictionary = {}

func _init(p_id: String = "", p_team_id: String = "", p_display_name: String = "") -> void:
	id = p_id if not p_id.is_empty() else DataModelUtils.generate_id("player")
	team_id = p_team_id
	display_name = p_display_name

func is_valid() -> bool:
	return DataModelUtils.has_stable_id(id) and DataModelUtils.has_stable_id(team_id) and not display_name.strip_edges().is_empty()

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not DataModelUtils.has_stable_id(id): errors.append("Player requires a stable id.")
	if not DataModelUtils.has_stable_id(team_id): errors.append("Player requires team_id.")
	if display_name.strip_edges().is_empty(): errors.append("Player requires display_name.")
	return errors

func to_dict() -> Dictionary:
	return {"id": id, "team_id": team_id, "display_name": display_name, "jersey_number": jersey_number, "metadata": metadata.duplicate(true)}

static func from_dict(data: Dictionary) -> Player:
	var model := Player.new(DataModelUtils.string_value(data, "id"), DataModelUtils.string_value(data, "team_id"), DataModelUtils.string_value(data, "display_name"))
	model.jersey_number = DataModelUtils.string_value(data, "jersey_number")
	model.metadata = DataModelUtils.dict_value(data, "metadata")
	return model
