class_name TelemetryLogger
extends Node

const DEFAULT_LOG_PATH := "user://telemetry.jsonl"

static func log_event(event: Dictionary, log_path: String = DEFAULT_LOG_PATH) -> void:
	var record := event.duplicate(true)
	if not record.has("timestamp"):
		record["timestamp"] = int(Time.get_unix_time_from_system() * 1000)

	var file := _open_log_file(log_path)
	if file == null:
		push_warning("Failed to open telemetry log at %s" % log_path)
		return

	file.store_line(JSON.stringify(record))
	file.flush()

static func _open_log_file(log_path: String) -> FileAccess:
	if FileAccess.file_exists(log_path):
		var existing := FileAccess.open(log_path, FileAccess.READ_WRITE)
		if existing != null:
			existing.seek_end()
		return existing

	return FileAccess.open(log_path, FileAccess.WRITE)
