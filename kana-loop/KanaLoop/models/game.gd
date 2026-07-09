class_name Game
extends RefCounted

const STATUS_SCHEDULED := "scheduled"
const STATUS_IN_PROGRESS := "in_progress"
const STATUS_FINAL := "final"

var id: String
var competition_id: String
var ruleset_id: String
var home_team_id: String
var away_team_id: String
var scheduled_at: int = 0
var status: String = STATUS_SCHEDULED
var event_ids: Array[String] = []
var metadata: Dictionary = {}

func _init(p_id: String = "", p_competition_id: String = "") -> void:
	id = p_id if not p_id.is_empty() else DataModelUtils.generate_id("game")
	competition_id = p_competition_id

func is_valid() -> bool:
	return DataModelUtils.has_stable_id(id) and DataModelUtils.has_stable_id(competition_id) and DataModelUtils.has_stable_id(ruleset_id) and DataModelUtils.has_stable_id(home_team_id) and DataModelUtils.has_stable_id(away_team_id) and home_team_id != away_team_id and [STATUS_SCHEDULED, STATUS_IN_PROGRESS, STATUS_FINAL].has(status)

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not DataModelUtils.has_stable_id(id): errors.append("Game requires a stable id.")
	if not DataModelUtils.has_stable_id(competition_id): errors.append("Game requires competition_id.")
	if not DataModelUtils.has_stable_id(ruleset_id): errors.append("Game requires ruleset_id.")
	if not DataModelUtils.has_stable_id(home_team_id): errors.append("Game requires home_team_id.")
	if not DataModelUtils.has_stable_id(away_team_id): errors.append("Game requires away_team_id.")
	if home_team_id == away_team_id: errors.append("Game home_team_id and away_team_id must differ.")
	if not [STATUS_SCHEDULED, STATUS_IN_PROGRESS, STATUS_FINAL].has(status): errors.append("Game status is not supported.")
	return errors

func to_dict() -> Dictionary:
	return {"id": id, "competition_id": competition_id, "ruleset_id": ruleset_id, "home_team_id": home_team_id, "away_team_id": away_team_id, "scheduled_at": scheduled_at, "status": status, "event_ids": event_ids.duplicate(), "metadata": metadata.duplicate(true)}

static func from_dict(data: Dictionary) -> Game:
	var model := Game.new(DataModelUtils.string_value(data, "id"), DataModelUtils.string_value(data, "competition_id"))
	model.ruleset_id = DataModelUtils.string_value(data, "ruleset_id")
	model.home_team_id = DataModelUtils.string_value(data, "home_team_id")
	model.away_team_id = DataModelUtils.string_value(data, "away_team_id")
	model.scheduled_at = DataModelUtils.int_value(data, "scheduled_at")
	model.status = DataModelUtils.string_value(data, "status", STATUS_SCHEDULED)
	model.event_ids = DataModelUtils.string_array(data.get("event_ids", []))
	model.metadata = DataModelUtils.dict_value(data, "metadata")
	return model
