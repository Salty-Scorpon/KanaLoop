class_name Ruleset
extends RefCounted

var id: String
var display_name: String
var period_count: int = 4
var period_length_seconds: int = 600
var overtime_allowed: bool = true
var scoring_rules: Dictionary = {}
var metadata: Dictionary = {}

func _init(p_id: String = "", p_display_name: String = "") -> void:
	id = p_id if not p_id.is_empty() else DataModelUtils.generate_id("ruleset")
	display_name = p_display_name

func is_valid() -> bool:
	return DataModelUtils.has_stable_id(id) and not display_name.strip_edges().is_empty() and period_count > 0 and period_length_seconds > 0

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not DataModelUtils.has_stable_id(id): errors.append("Ruleset requires a stable id.")
	if display_name.strip_edges().is_empty(): errors.append("Ruleset requires display_name.")
	if period_count <= 0: errors.append("Ruleset period_count must be positive.")
	if period_length_seconds <= 0: errors.append("Ruleset period_length_seconds must be positive.")
	return errors

func to_dict() -> Dictionary:
	return {"id": id, "display_name": display_name, "period_count": period_count, "period_length_seconds": period_length_seconds, "overtime_allowed": overtime_allowed, "scoring_rules": scoring_rules.duplicate(true), "metadata": metadata.duplicate(true)}

static func from_dict(data: Dictionary) -> Ruleset:
	var model := Ruleset.new(DataModelUtils.string_value(data, "id"), DataModelUtils.string_value(data, "display_name"))
	model.period_count = DataModelUtils.int_value(data, "period_count", 4)
	model.period_length_seconds = DataModelUtils.int_value(data, "period_length_seconds", 600)
	model.overtime_allowed = bool(data.get("overtime_allowed", true))
	model.scoring_rules = DataModelUtils.dict_value(data, "scoring_rules")
	model.metadata = DataModelUtils.dict_value(data, "metadata")
	return model
