class_name RuntimePaths
extends Node

static func _runtime_base_dir() -> String:
	var base_dir := ""
	if OS.has_feature("editor"):
		base_dir = ProjectSettings.globalize_path("res://")
		print("Runtime base dir (editor): %s" % base_dir)
		return base_dir

	var executable_path := OS.get_executable_path()
	base_dir = executable_path.get_base_dir()
	print("Runtime base dir (export): %s (exec: %s)" % [base_dir, executable_path])
	return base_dir


static func _vosk_service_binary_name() -> String:
	var os_name := OS.get_name()
	var binary_name := "vosk_service"
	if os_name == "Windows":
		binary_name = "vosk_service.exe"
	print("Resolved OS name for Vosk service: %s -> %s" % [os_name, binary_name])
	return binary_name


static func resolve_vosk_service_path() -> String:
	var base_dir := _runtime_base_dir()
	var binary_name := _vosk_service_binary_name()
	var resolved_path := base_dir.path_join(binary_name)
	print("Resolved Vosk service path: %s" % resolved_path)
	if not FileAccess.file_exists(resolved_path):
		push_warning("Vosk service binary missing at: %s" % resolved_path)
	return resolved_path
