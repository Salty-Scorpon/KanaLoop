class_name Competition
extends RefCounted

var id: String
var display_name: String
var ruleset_id: String
var team_ids: Array[String] = []
var player_ids: Array[String] = []
var game_ids: Array[String] = []
var metadata: Dictionary = {}

func _init(p_id: String = "", p_display_name: String = "") -> void:
	id = p_id if not p_id.is_empty() else DataModelUtils.generate_id("competition")
	display_name = p_display_name

func add_team_id(team_id: String) -> void:
	if DataModelUtils.has_stable_id(team_id) and not team_ids.has(team_id):
		team_ids.append(team_id)

func add_player_id(player_id: String) -> void:
	if DataModelUtils.has_stable_id(player_id) and not player_ids.has(player_id):
		player_ids.append(player_id)

func add_game_id(game_id: String) -> void:
	if DataModelUtils.has_stable_id(game_id) and not game_ids.has(game_id):
		game_ids.append(game_id)

func is_valid() -> bool:
	return DataModelUtils.has_stable_id(id) and not display_name.strip_edges().is_empty() and DataModelUtils.has_stable_id(ruleset_id)

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not DataModelUtils.has_stable_id(id): errors.append("Competition requires a stable id.")
	if display_name.strip_edges().is_empty(): errors.append("Competition requires display_name.")
	if not DataModelUtils.has_stable_id(ruleset_id): errors.append("Competition requires ruleset_id.")
	return errors

func to_dict() -> Dictionary:
	return {"id": id, "display_name": display_name, "ruleset_id": ruleset_id, "team_ids": team_ids.duplicate(), "player_ids": player_ids.duplicate(), "game_ids": game_ids.duplicate(), "metadata": metadata.duplicate(true)}

static func from_dict(data: Dictionary) -> Competition:
	var model := Competition.new(DataModelUtils.string_value(data, "id"), DataModelUtils.string_value(data, "display_name"))
	model.ruleset_id = DataModelUtils.string_value(data, "ruleset_id")
	model.team_ids = DataModelUtils.string_array(data.get("team_ids", []))
	model.player_ids = DataModelUtils.string_array(data.get("player_ids", []))
	model.game_ids = DataModelUtils.string_array(data.get("game_ids", []))
	model.metadata = DataModelUtils.dict_value(data, "metadata")
	return model
