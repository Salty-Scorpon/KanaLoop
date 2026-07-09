class_name DataModelUtils
extends RefCounted

static func generate_id(prefix: String = "id") -> String:
	var timestamp := Time.get_unix_time_from_system()
	var random_part := randi()
	return "%s_%d_%08x" % [prefix, int(timestamp), random_part]

static func string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

static func string_value(data: Dictionary, key: String, default_value: String = "") -> String:
	return str(data.get(key, default_value))

static func int_value(data: Dictionary, key: String, default_value: int = 0) -> int:
	return int(data.get(key, default_value))

static func float_value(data: Dictionary, key: String, default_value: float = 0.0) -> float:
	return float(data.get(key, default_value))

static func dict_value(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	if value is Dictionary:
		return value.duplicate(true)
	return {}

static func has_stable_id(value: String) -> bool:
	return not value.strip_edges().is_empty()
