extends Control

signal back_requested

@onready var back_button: Button = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/BackButton",
	"MarginContainer/VBoxContainer/BackButton",
]) as Button
@onready var drawing_canvas: Control = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/DrawingArea/DrawingCanvas",
	"MarginContainer/VBoxContainer/DrawingArea/DrawingCanvas",
]) as Control
@onready var strokes_layer: Node2D = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/DrawingArea/DrawingCanvas/Strokes",
	"MarginContainer/VBoxContainer/DrawingArea/DrawingCanvas/Strokes",
]) as Node2D
@onready var ghost_lines_container: Node2D = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/DrawingArea/DrawingCanvas/GhostLines",
	"MarginContainer/VBoxContainer/DrawingArea/DrawingCanvas/GhostLines",
]) as Node2D
@onready var outline_lines_container: Node2D = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/DrawingArea/DrawingCanvas/OutlineLines",
	"MarginContainer/VBoxContainer/DrawingArea/DrawingCanvas/OutlineLines",
]) as Node2D
@onready var target_kana_label: Label = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/DrawingArea/DrawingCanvas/TargetContainer/TargetKana",
	"MarginContainer/VBoxContainer/DrawingArea/DrawingCanvas/TargetContainer/TargetKana",
]) as Label
@onready var stroke_outline_toggle: CheckBox = _find_node_with_fallback([
	"TogglePanel/ToggleMargin/ToggleVBox/StrokeOutlineToggle",
]) as CheckBox
@onready var blackout_toggle: CheckBox = _find_node_with_fallback([
	"TogglePanel/ToggleMargin/ToggleVBox/BlackoutToggle",
]) as CheckBox
@onready var choose_assignment_button: Button = _find_node_with_fallback([
	"SelectionPanel/SelectionMargin/ChooseButton",
]) as Button
@onready var progress_label: Label = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/ProgressLabel",
	"MarginContainer/VBoxContainer/ProgressLabel",
]) as Label
@onready var completion_label: Label = _find_node_with_fallback([
	"MarginContainer/ScrollContainer/VBoxContainer/CompletionLabel",
	"MarginContainer/VBoxContainer/CompletionLabel",
]) as Label

var selected_kana: Array[String] = []
var remaining_kana_pool: Array[String] = []
var manual_kana_queue: Array[String] = []
var current_kana := ""
var active_line: Line2D
var current_stroke_points: PackedVector2Array = PackedVector2Array()
var current_stroke_index := 0
var stroke_runtimes: Array[Dictionary] = []
var ghost_lines: Array[Line2D] = []
var outline_lines: Array[Line2D] = []
var kana_outline_data: Dictionary = {}
var stroke_has_red := false
var stroke_start_gate_met := false
var stroke_last_t := 0.0
var stroke_direction_failed := false
var stroke_outline_enabled := true
var blackout_enabled := false
var debug_overlay_enabled := false
var debug_last_t_label := 0.0
var debug_last_t_position := Vector2.ZERO
var debug_last_t_visible := false
var rng := RandomNumberGenerator.new()
var current_stroke_runtime: Dictionary = {}

const OUTLINE_DATA_PATH := "res://assets/data/kana_outline.json"
const OUTLINE_OVERRIDES_PATH := "res://assets/data/kana_outline_overrides.json"
const OUTLINE_OVERRIDES_DIR := "res://assets/data/overrides"
const GUIDE_SAMPLE_COUNT := 192
const MIN_DRAWN_LENGTH_RATIO := 0.35
const DIRECTION_JITTER := 1.0
const FINAL_T_THRESHOLD := 0.85
const DEFAULT_HINT_RADIUS := 0.08
const DEBUG_PATH_COLOR := Color(0.9, 0.2, 0.9, 0.9)
const DEBUG_START_COLOR := Color(0.2, 0.9, 0.4, 0.9)
const DEBUG_END_COLOR := Color(0.9, 0.4, 0.2, 0.9)
const DEBUG_LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const DEBUG_CIRCLE_WIDTH := 2.0
const DEBUG_PATH_WIDTH := 3.0
const TARGET_KANA_FONT_SIZE := 220
const TARGET_KANA_MULTI_FONT_SIZE := 180

func _ready() -> void:
	selected_kana = KanaState.get_selected_kana()
	if selected_kana.is_empty():
		selected_kana = KanaState.DEFAULT_KANA.duplicate()
	rng.randomize()
	if target_kana_label == null or progress_label == null or completion_label == null:
		push_error("Guided writing UI nodes are missing. Check the GuidedWriting scene structure.")
		return
	if target_kana_label != null:
		target_kana_label.visible = false
	_load_kana_outline_data()
	_refill_remaining_pool()
	call_deferred("_advance_to_next_kana")
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
	if drawing_canvas != null:
		drawing_canvas.gui_input.connect(_on_drawing_canvas_input)
		drawing_canvas.resized.connect(_on_drawing_canvas_resized)
	if stroke_outline_toggle != null:
		stroke_outline_toggle.button_pressed = stroke_outline_enabled
		stroke_outline_toggle.toggled.connect(_on_stroke_outline_toggled)
	if blackout_toggle != null:
		blackout_toggle.button_pressed = blackout_enabled
		blackout_toggle.toggled.connect(_on_blackout_toggled)
	if choose_assignment_button != null:
		choose_assignment_button.pressed.connect(_on_choose_assignment_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_play_current_kana()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D:
		debug_overlay_enabled = not debug_overlay_enabled
		queue_redraw()

func _update_target_kana() -> void:
	if target_kana_label == null:
		return
	if current_kana == "":
		target_kana_label.text = "あ"
		_apply_target_kana_font_size("あ")
		return
	target_kana_label.text = current_kana
	_apply_target_kana_font_size(current_kana)

func _load_guide_definition() -> void:
	if drawing_canvas != null and drawing_canvas.size == Vector2.ZERO:
		return
	var kana_key := current_kana
	if kana_key == "":
		kana_key = "あ"
	var kana_def: Dictionary = kana_outline_data.get(kana_key, {})
	if kana_def.is_empty() and not kana_outline_data.is_empty():
		kana_def = kana_outline_data.values()[0]
	_clear_strokes()
	stroke_runtimes = _build_stroke_runtimes(kana_def)
	current_stroke_index = 0
	debug_last_t_visible = false
	if completion_label != null:
		completion_label.visible = false
	if stroke_runtimes.is_empty():
		progress_label.text = "No guide available"
	else:
		progress_label.text = _stroke_progress_text(0)
	_build_guides()
	_update_guides_visibility()
	queue_redraw()

func _load_kana_outline_data() -> void:
	var file := FileAccess.open(OUTLINE_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open kana outline data at %s" % OUTLINE_DATA_PATH)
		return
	var json_text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Kana outline JSON is not an array.")
		return
	var entries: Array = parsed
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var kana_value: String = String(entry.get("kana", ""))
		if kana_value != "":
			kana_outline_data[kana_value] = entry
	_load_kana_outline_overrides()

func _load_kana_outline_overrides() -> void:
	if FileAccess.file_exists(OUTLINE_OVERRIDES_PATH):
		_apply_override_payload(_read_json_payload(OUTLINE_OVERRIDES_PATH), OUTLINE_OVERRIDES_PATH)
	if DirAccess.dir_exists_absolute(OUTLINE_OVERRIDES_DIR):
		_load_override_directory(OUTLINE_OVERRIDES_DIR)

func _read_json_payload(path: String) -> Variant:
	var override_file := FileAccess.open(path, FileAccess.READ)
	if override_file == null:
		push_warning("Unable to open kana outline override data at %s" % path)
		return null
	var override_text := override_file.get_as_text()
	var parsed: Variant = JSON.parse_string(override_text)
	if parsed == null:
		push_warning("Kana outline override JSON could not be parsed at %s" % path)
	return parsed

func _apply_override_payload(payload: Variant, source_label: String) -> void:
	if payload == null:
		return
	if typeof(payload) == TYPE_ARRAY:
		var entries: Array = payload
		for entry: Variant in entries:
			_apply_kana_override(entry, source_label)
		return
	if typeof(payload) == TYPE_DICTIONARY:
		if payload.has("kana"):
			_apply_kana_override(payload, source_label)
			return
		for kana_key in payload.keys():
			var entry_value: Variant = payload[kana_key]
			if typeof(entry_value) != TYPE_DICTIONARY:
				continue
			var entry_dict: Dictionary = entry_value
			var merged_entry: Dictionary = entry_dict.duplicate()
			merged_entry["kana"] = String(kana_key)
			_apply_kana_override(merged_entry, source_label)
		return
	push_warning("Kana outline override data in %s must be an array or dictionary." % source_label)

func _apply_kana_override(entry: Variant, source_label: String) -> void:
	if typeof(entry) != TYPE_DICTIONARY:
		return
	var kana_value: String = String(entry.get("kana", ""))
	if kana_value == "":
		push_warning("Kana outline override entry missing kana in %s" % source_label)
		return
	kana_outline_data[kana_value] = entry

func _load_override_directory(directory_path: String) -> void:
	var dir := DirAccess.open(directory_path)
	if dir == null:
		push_warning("Unable to open override directory at %s" % directory_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "json":
			var file_path := "%s/%s" % [directory_path, file_name]
			var payload: Variant = _read_json_payload(file_path)
			_apply_override_payload(payload, file_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _build_stroke_runtimes(kana_def: Dictionary) -> Array[Dictionary]:
	return _build_stroke_runtimes_with_layout(kana_def, _get_glyph_origin(), _get_glyph_size())

func _build_stroke_runtimes_with_layout(kana_def: Dictionary, glyph_origin: Vector2, glyph_size: float) -> Array[Dictionary]:
	var runtimes: Array[Dictionary] = []
	if kana_def.is_empty():
		return runtimes
	var strokes: Array = kana_def.get("strokes", [])
	for stroke in strokes:
		if typeof(stroke) != TYPE_DICTIONARY:
			continue
		var rules: Dictionary = stroke.get("rules", {})
		var start_hint: Dictionary = stroke.get("start_hint", {})
		var end_hint: Dictionary = stroke.get("end_hint", {})
		var start_point := _to_canvas_point(start_hint, glyph_origin, glyph_size)
		var end_point := _to_canvas_point(end_hint, glyph_origin, glyph_size)
		var start_radius := float(start_hint.get("radius", rules.get("start_must_be_near", DEFAULT_HINT_RADIUS)))
		var end_radius := float(end_hint.get("radius", rules.get("end_must_be_near", DEFAULT_HINT_RADIUS)))
		var path_segments: Array = stroke.get("path_hint", [])
		var path_samples := _build_path_samples(path_segments, glyph_origin, glyph_size, GUIDE_SAMPLE_COUNT)
		var cumulative_lengths := _build_cumulative_lengths(path_samples)
		var total_length := cumulative_lengths[cumulative_lengths.size() - 1] if cumulative_lengths.size() > 0 else 0.0
		var segment_vectors := _build_segment_vectors(path_samples)
		var segment_length_squareds := _build_segment_length_squareds(segment_vectors)
		var path_bounds := _build_path_bounds(path_samples)
		var corridor_radius := float(rules.get("corridor_radius", 0.05)) * glyph_size * _get_corridor_radius_scale()
		runtimes.append({
			"start_point": start_point,
			"end_point": end_point,
			"start_gate_radius": start_radius * glyph_size * _get_gate_radius_scale(),
			"end_gate_radius": end_radius * glyph_size * _get_gate_radius_scale(),
			"corridor_radius": corridor_radius,
			"direction_enforced": bool(rules.get("direction_enforced", true)),
			"path_samples": path_samples,
			"cumulative_lengths": cumulative_lengths,
			"total_length": total_length,
			"segment_vectors": segment_vectors,
			"segment_length_squareds": segment_length_squareds,
			"path_bounds": path_bounds,
			"expanded_bounds": path_bounds.grow(corridor_radius),
		})
	return runtimes

func _play_current_kana() -> void:
	if current_kana == "":
		return
	KanaAudio.play_kana_audio(current_kana)

func _on_drawing_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_stroke(event.position)
		else:
			_end_stroke()
		return
	if event is InputEventMouseMotion:
		if active_line != null and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_add_point(event.position)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_stroke(event.position)
		else:
			_end_stroke()
		return
	if event is InputEventScreenDrag:
		if active_line != null:
			_add_point(event.position)

func _on_drawing_canvas_resized() -> void:
	if drawing_canvas == null:
		return
	if drawing_canvas.size == Vector2.ZERO:
		return
	if current_kana == "":
		return
	_load_guide_definition()

func _start_stroke(point: Vector2) -> void:
	if not _is_practice_input_enabled():
		return
	if current_stroke_index >= stroke_runtimes.size():
		return
	if strokes_layer == null:
		return
	stroke_start_gate_met = false
	var runtime: Dictionary = stroke_runtimes[current_stroke_index]
	current_stroke_runtime = runtime
	var start_point: Vector2 = runtime.get("start_point", Vector2.ZERO)
	var start_gate_radius: float = runtime.get("start_gate_radius", 0.0)
	if point.distance_to(start_point) > start_gate_radius:
		progress_label.text = "Start closer to the guide"
		return
	active_line = Line2D.new()
	active_line.width = 6.0
	active_line.default_color = _get_player_stroke_color()
	active_line.joint_mode = Line2D.LINE_JOINT_ROUND
	active_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	active_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	active_line.add_point(point)
	strokes_layer.add_child(active_line)
	current_stroke_points = PackedVector2Array([point])
	stroke_has_red = false
	stroke_start_gate_met = true
	stroke_last_t = 0.0
	stroke_direction_failed = false
	if runtime.get("direction_enforced", true):
		stroke_last_t = _project_t_on_path(point, runtime)

func _add_point(point: Vector2) -> void:
	if active_line == null:
		return
	active_line.add_point(point)
	current_stroke_points.append(point)
	if current_stroke_index >= stroke_runtimes.size():
		return
	var runtime := current_stroke_runtime
	if runtime.is_empty():
		runtime = stroke_runtimes[current_stroke_index]
		current_stroke_runtime = runtime
	if not stroke_has_red:
		var expanded_bounds: Rect2 = runtime.get("expanded_bounds", Rect2())
		if expanded_bounds.size != Vector2.ZERO and not expanded_bounds.has_point(point):
			stroke_has_red = true
		else:
			var corridor_radius: float = runtime.get("corridor_radius", 0.0)
			var distance := _distance_to_polyline_cached(
				point,
				runtime.get("path_samples", PackedVector2Array()),
				runtime.get("segment_vectors", PackedVector2Array()),
				runtime.get("segment_length_squareds", PackedFloat32Array())
			)
			if distance > corridor_radius:
				stroke_has_red = true
	active_line.default_color = Color(0.9, 0.2, 0.2, 0.9) if stroke_has_red else _get_player_stroke_color()
	if not stroke_has_red and runtime.get("direction_enforced", true):
		var t := _project_t_on_path(point, runtime)
		if t + DIRECTION_JITTER < stroke_last_t:
			stroke_direction_failed = true
		stroke_last_t = max(stroke_last_t, t)

func _end_stroke() -> void:
	if active_line == null:
		return
	var finished_line := active_line
	var finished_points := current_stroke_points
	active_line = null
	current_stroke_points = PackedVector2Array()
	current_stroke_runtime = {}
	if debug_overlay_enabled and finished_points.size() > 0:
		debug_last_t_label = stroke_last_t
		debug_last_t_position = finished_points[finished_points.size() - 1]
		debug_last_t_visible = true
		queue_redraw()
	_evaluate_stroke(finished_line, finished_points)

func _evaluate_stroke(finished_line: Line2D, stroke_points: PackedVector2Array) -> void:
	if current_stroke_index >= stroke_runtimes.size():
		return
	var runtime: Dictionary = stroke_runtimes[current_stroke_index]
	var is_valid := _stroke_is_valid(stroke_points, runtime)
	if is_valid:
		current_stroke_index += 1
		if current_stroke_index >= stroke_runtimes.size():
			_handle_kana_completed()
		else:
			progress_label.text = _stroke_progress_text(current_stroke_index)
		_update_guides_visibility()
	else:
		if finished_line != null:
			finished_line.queue_free()
		progress_label.text = "Try %s" % _stroke_progress_text(current_stroke_index).to_lower()

func _stroke_progress_text(stroke_index: int) -> String:
	return "Stroke %d/%d" % [stroke_index + 1, stroke_runtimes.size()]

func _stroke_is_valid(stroke_points: PackedVector2Array, runtime: Dictionary) -> bool:
	if stroke_points.size() < 2:
		return false
	if not stroke_start_gate_met:
		return false
	if stroke_has_red:
		return false
	var end_point: Vector2 = runtime.get("end_point", Vector2.ZERO)
	var end_gate_radius: float = runtime.get("end_gate_radius", 0.0)
	if stroke_points[-1].distance_to(end_point) > end_gate_radius:
		return false
	var drawn_length := _polyline_length(stroke_points)
	var total_length: float = runtime.get("total_length", 0.0)
	if total_length > 0.0 and drawn_length < total_length * _get_min_drawn_length_ratio():
		return false
	if runtime.get("direction_enforced", true):
		if stroke_direction_failed:
			return false
		if stroke_last_t < _get_final_t_threshold():
			return false
	return true

func _get_min_drawn_length_ratio() -> float:
	return MIN_DRAWN_LENGTH_RATIO

func _get_final_t_threshold() -> float:
	return FINAL_T_THRESHOLD

func _get_corridor_radius_scale() -> float:
	return 1.0

func _get_gate_radius_scale() -> float:
	return 1.0

func _is_practice_input_enabled() -> bool:
	return true

func _get_player_stroke_color() -> Color:
	return Color(0.2, 0.4, 0.9, 0.9)

func _distance_to_polyline_cached(
	point: Vector2,
	polyline: PackedVector2Array,
	segment_vectors: PackedVector2Array,
	segment_length_squareds: PackedFloat32Array
) -> float:
	var best_distance := INF
	var segment_count := polyline.size() - 1
	if segment_vectors.size() < segment_count or segment_length_squareds.size() < segment_count:
		for index in range(segment_count):
			var start := polyline[index]
			var end := polyline[index + 1]
			var segment := end - start
			var length_squared := segment.length_squared()
			if length_squared == 0.0:
				best_distance = min(best_distance, point.distance_to(start))
				continue
			var t := (point - start).dot(segment) / length_squared
			t = clamp(t, 0.0, 1.0)
			var projection := start + segment * t
			best_distance = min(best_distance, point.distance_to(projection))
		return best_distance
	for index in range(segment_count):
		var start := polyline[index]
		var segment := segment_vectors[index]
		var length_squared := segment_length_squareds[index]
		if length_squared == 0.0:
			best_distance = min(best_distance, point.distance_to(start))
			continue
		var t := (point - start).dot(segment) / length_squared
		t = clamp(t, 0.0, 1.0)
		var projection := start + segment * t
		best_distance = min(best_distance, point.distance_to(projection))
	return best_distance

func _build_guides() -> void:
	if ghost_lines_container == null or outline_lines_container == null:
		return
	for child in ghost_lines_container.get_children():
		child.queue_free()
	for child in outline_lines_container.get_children():
		child.queue_free()
	ghost_lines.clear()
	outline_lines.clear()
	for runtime in stroke_runtimes:
		var ghost_line := Line2D.new()
		ghost_line.width = 10.0
		ghost_line.default_color = Color(0.1, 0.1, 0.1, 0.18)
		ghost_line.round_precision = 8
		ghost_line.points = runtime.get("path_samples", PackedVector2Array())
		ghost_lines_container.add_child(ghost_line)
		ghost_lines.append(ghost_line)

		var outline_line := Line2D.new()
		outline_line.width = 8.0
		outline_line.default_color = Color(0.2, 0.6, 1.0, 0.6)
		outline_line.round_precision = 8
		outline_line.points = runtime.get("path_samples", PackedVector2Array())
		outline_lines_container.add_child(outline_line)
		outline_lines.append(outline_line)

func _update_guides_visibility() -> void:
	var has_current_stroke := current_stroke_index >= 0 and current_stroke_index < outline_lines.size()
	for index in range(ghost_lines.size()):
		var line := ghost_lines[index]
		line.visible = not blackout_enabled
	for index in range(outline_lines.size()):
		var line := outline_lines[index]
		line.visible = stroke_outline_enabled and has_current_stroke and index == current_stroke_index
	queue_redraw()

func _draw() -> void:
	if not debug_overlay_enabled:
		return
	if drawing_canvas == null:
		return
	if current_stroke_index < 0 or current_stroke_index >= stroke_runtimes.size():
		return
	var runtime: Dictionary = stroke_runtimes[current_stroke_index]
	if runtime.is_empty():
		return
	var start_point: Vector2 = runtime.get("start_point", Vector2.ZERO)
	var end_point: Vector2 = runtime.get("end_point", Vector2.ZERO)
	var start_gate_radius: float = runtime.get("start_gate_radius", 0.0)
	var end_gate_radius: float = runtime.get("end_gate_radius", 0.0)
	var path_samples: PackedVector2Array = runtime.get("path_samples", PackedVector2Array())
	var inverse_global: Transform2D = get_global_transform().affine_inverse()
	var canvas_global: Transform2D = drawing_canvas.get_global_transform()
	var local_start: Vector2 = inverse_global * (canvas_global * start_point)
	var local_end: Vector2 = inverse_global * (canvas_global * end_point)
	draw_arc(local_start, start_gate_radius, 0.0, TAU, 64, DEBUG_START_COLOR, DEBUG_CIRCLE_WIDTH)
	draw_arc(local_end, end_gate_radius, 0.0, TAU, 64, DEBUG_END_COLOR, DEBUG_CIRCLE_WIDTH)
	if path_samples.size() > 1:
		var transformed_samples := PackedVector2Array()
		transformed_samples.resize(path_samples.size())
		for index in range(path_samples.size()):
			transformed_samples[index] = inverse_global * (canvas_global * path_samples[index])
		draw_polyline(transformed_samples, DEBUG_PATH_COLOR, DEBUG_PATH_WIDTH, true)
	if debug_last_t_visible:
		var font := get_theme_default_font()
		var font_size := get_theme_default_font_size()
		var label_position: Vector2 = inverse_global * (canvas_global * debug_last_t_position) + Vector2(8, -8)
		draw_string(font, label_position, "t=%.2f" % debug_last_t_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DEBUG_LABEL_COLOR)

func _on_stroke_outline_toggled(enabled: bool) -> void:
	stroke_outline_enabled = enabled
	_update_guides_visibility()

func _on_blackout_toggled(enabled: bool) -> void:
	blackout_enabled = enabled
	_update_guides_visibility()

func _build_path_samples(segments: Array, origin: Vector2, glyph_size: float, samples_per_stroke: int) -> PackedVector2Array:
	var samples := PackedVector2Array()
	if segments.is_empty():
		return samples
	var segment_sample_count: int = int(max(2.0, ceil(float(samples_per_stroke) / float(segments.size()))))
	for segment in segments:
		if typeof(segment) != TYPE_DICTIONARY:
			continue
		var segment_samples := _sample_segment(segment, origin, glyph_size, segment_sample_count)
		if segment_samples.is_empty():
			continue
		if samples.size() > 0:
			segment_samples.remove_at(0)
		for point in segment_samples:
			samples.append(point)
	return samples

func _sample_segment(segment: Dictionary, origin: Vector2, glyph_size: float, sample_count: int) -> PackedVector2Array:
	var samples := PackedVector2Array()
	var segment_type: String = segment.get("type", "")
	var points: Array = segment.get("points", [])
	if points.is_empty():
		return samples
	for index in range(sample_count):
		var t := 0.0
		if sample_count > 1:
			t = float(index) / float(sample_count - 1)
		var normalized_point: Vector2 = _evaluate_segment(segment_type, points, t)
		var canvas_point: Vector2 = origin + normalized_point * glyph_size
		samples.append(canvas_point)
	return samples

func _evaluate_segment(segment_type: String, points: Array, t: float) -> Vector2:
	if segment_type == "Line" and points.size() >= 2:
		return _lerp_point(points[0], points[1], t)
	if segment_type == "Quad" and points.size() >= 3:
		var p0 := _lerp_point(points[0], points[1], t)
		var p1 := _lerp_point(points[1], points[2], t)
		return _lerp_point(p0, p1, t)
	if segment_type == "Cubic" and points.size() >= 4:
		var p0 := _lerp_point(points[0], points[1], t)
		var p1 := _lerp_point(points[1], points[2], t)
		var p2 := _lerp_point(points[2], points[3], t)
		var q0 := _lerp_point(p0, p1, t)
		var q1 := _lerp_point(p1, p2, t)
		return _lerp_point(q0, q1, t)
	if points.size() >= 1:
		return _point_from_variant(points[0])
	return Vector2.ZERO

func _lerp_point(a: Variant, b: Variant, t: float) -> Vector2:
	var p0: Vector2 = _point_from_variant(a)
	var p1: Vector2 = _point_from_variant(b)
	return p0.lerp(p1, t)

func _point_from_variant(point: Variant) -> Vector2:
	if point is Vector2:
		return point
	if typeof(point) == TYPE_DICTIONARY:
		return _point_from_dict(point)
	return Vector2.ZERO

func _point_from_dict(point: Dictionary) -> Vector2:
	return Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0)))

func _to_canvas_point(point_data: Dictionary, origin: Vector2, glyph_size: float) -> Vector2:
	return origin + _point_from_dict(point_data) * glyph_size

func _get_glyph_size() -> float:
	if drawing_canvas == null:
		return 0.0
	var canvas_size := drawing_canvas.size
	return min(canvas_size.x, canvas_size.y)

func _get_glyph_origin() -> Vector2:
	if drawing_canvas == null:
		return Vector2.ZERO
	var canvas_size := drawing_canvas.size
	var glyph_size: float = min(canvas_size.x, canvas_size.y)
	return (canvas_size - Vector2(glyph_size, glyph_size)) * 0.5

func _build_cumulative_lengths(points: PackedVector2Array) -> PackedFloat32Array:
	var lengths := PackedFloat32Array()
	if points.is_empty():
		return lengths
	lengths.resize(points.size())
	lengths[0] = 0.0
	for index in range(1, points.size()):
		lengths[index] = lengths[index - 1] + points[index].distance_to(points[index - 1])
	return lengths

func _build_segment_vectors(points: PackedVector2Array) -> PackedVector2Array:
	var vectors := PackedVector2Array()
	if points.size() < 2:
		return vectors
	vectors.resize(points.size() - 1)
	for index in range(points.size() - 1):
		vectors[index] = points[index + 1] - points[index]
	return vectors

func _build_segment_length_squareds(vectors: PackedVector2Array) -> PackedFloat32Array:
	var lengths := PackedFloat32Array()
	if vectors.is_empty():
		return lengths
	lengths.resize(vectors.size())
	for index in range(vectors.size()):
		lengths[index] = vectors[index].length_squared()
	return lengths

func _build_path_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)

func _project_t_on_path(point: Vector2, runtime: Dictionary) -> float:
	var samples: PackedVector2Array = runtime.get("path_samples", PackedVector2Array())
	var lengths: PackedFloat32Array = runtime.get("cumulative_lengths", PackedFloat32Array())
	var segment_vectors: PackedVector2Array = runtime.get("segment_vectors", PackedVector2Array())
	var segment_length_squareds: PackedFloat32Array = runtime.get("segment_length_squareds", PackedFloat32Array())
	if samples.size() < 2 or lengths.size() != samples.size():
		return 0.0
	var best_distance := INF
	var best_length := 0.0
	var segment_count := samples.size() - 1
	for index in range(segment_count):
		var start := samples[index]
		var segment := segment_vectors[index] if segment_vectors.size() > index else samples[index + 1] - samples[index]
		var length_squared := segment_length_squareds[index] if segment_length_squareds.size() > index else segment.length_squared()
		if length_squared == 0.0:
			continue
		var t := (point - start).dot(segment) / length_squared
		t = clamp(t, 0.0, 1.0)
		var projection := start + segment * t
		var distance := point.distance_to(projection)
		if distance < best_distance:
			best_distance = distance
			var segment_length := lengths[index + 1] - lengths[index]
			best_length = lengths[index] + segment_length * t
	var total_length := lengths[lengths.size() - 1]
	if total_length == 0.0:
		return 0.0
	return best_length / total_length

func _polyline_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for index in range(points.size() - 1):
		length += points[index].distance_to(points[index + 1])
	return length

func _find_node_with_fallback(paths: Array[String]) -> Node:
	for node_path in paths:
		var node := get_node_or_null(node_path)
		if node != null:
			return node
	return null

func _apply_target_kana_font_size(kana: String) -> void:
	if target_kana_label == null:
		return
	var font_size := TARGET_KANA_FONT_SIZE if kana.length() <= 1 else TARGET_KANA_MULTI_FONT_SIZE
	target_kana_label.add_theme_font_size_override("font_size", font_size)

func _on_choose_assignment_pressed() -> void:
	_show_assignment_picker(_get_assignment_picker_items(), _get_assignment_picker_title())

func _get_assignment_picker_title() -> String:
	return "Choose Kana"

func _get_assignment_picker_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for kana in selected_kana:
		items.append({
			"label": kana,
			"search": kana,
			"value": kana,
		})
	return items

func _apply_assignment_selection(selection: Array) -> void:
	if selection.is_empty():
		return
	manual_kana_queue.clear()
	current_kana = String(selection[0])
	for index in range(1, selection.size()):
		manual_kana_queue.append(String(selection[index]))
	_clear_strokes()
	current_stroke_runtime = {}
	current_stroke_index = 0
	_update_target_kana()
	_load_guide_definition()

func _show_assignment_picker(items: Array[Dictionary], title: String) -> void:
	var existing_overlay := get_node_or_null("AssignmentPickerOverlay")
	if existing_overlay != null:
		existing_overlay.queue_free()
	var overlay := PanelContainer.new()
	overlay.name = "AssignmentPickerOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_theme_stylebox_override("panel", _picker_panel_style(Color(0.0, 0.0, 0.0, 0.45)))
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(760, 520)
	dialog.add_theme_stylebox_override("panel", _picker_panel_style(Color(0.12, 0.12, 0.12, 0.98)))
	center.add_child(dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	dialog.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	rows.add_child(title_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	rows.add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left)

	var search_box := LineEdit.new()
	search_box.placeholder_text = "Search"
	left.add_child(search_box)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)

	var results := VBoxContainer.new()
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(results)

	var queue_panel := PanelContainer.new()
	queue_panel.custom_minimum_size = Vector2(180, 0)
	body.add_child(queue_panel)
	var queue_box := VBoxContainer.new()
	queue_box.add_theme_constant_override("separation", 6)
	queue_panel.add_child(queue_box)
	var queue_title := Label.new()
	queue_title.text = "Queue"
	queue_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_box.add_child(queue_title)
	var queue_list := VBoxContainer.new()
	queue_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_box.add_child(queue_list)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	rows.add_child(actions)
	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	actions.add_child(cancel_button)
	var apply_button := Button.new()
	apply_button.text = "Use Selection"
	actions.add_child(apply_button)

	var selected_values: Array = []
	var selected_labels: Array[String] = []
	var refresh_queue := func() -> void:
		for child in queue_list.get_children():
			child.queue_free()
		if selected_labels.is_empty():
			var empty_label := Label.new()
			empty_label.text = "No selections yet"
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			queue_list.add_child(empty_label)
			return
		for index in range(selected_labels.size()):
			var label := Label.new()
			label.text = "%d. %s" % [index + 1, selected_labels[index]]
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			queue_list.add_child(label)
	var refresh_results := func(filter_text: String) -> void:
		for child in results.get_children():
			child.queue_free()
		var normalized_filter := filter_text.strip_edges().to_lower()
		var added := 0
		for item in items:
			var label_text := String(item.get("label", ""))
			var search_text := String(item.get("search", label_text)).to_lower()
			if normalized_filter != "" and not search_text.contains(normalized_filter):
				continue
			var item_button := Button.new()
			item_button.text = label_text
			item_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_button.pressed.connect(func() -> void:
				selected_values.append(item.get("value"))
				selected_labels.append(label_text)
				refresh_queue.call()
			)
			results.add_child(item_button)
			added += 1
		if added == 0:
			var empty_results := Label.new()
			empty_results.text = "No matching assignments"
			empty_results.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			results.add_child(empty_results)

	search_box.text_changed.connect(func(new_text: String) -> void:
		refresh_results.call(new_text)
	)
	cancel_button.pressed.connect(func() -> void:
		overlay.queue_free()
	)
	apply_button.pressed.connect(func() -> void:
		_apply_assignment_selection(selected_values)
		overlay.queue_free()
	)
	refresh_queue.call()
	refresh_results.call("")
	search_box.grab_focus()

func _picker_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _on_back_pressed() -> void:
	back_requested.emit()

func _handle_kana_completed() -> void:
	if completion_label != null:
		completion_label.visible = true
	progress_label.text = "Completed"
	_play_current_kana()
	call_deferred("_advance_to_next_kana")

func _advance_to_next_kana() -> void:
	current_kana = ""
	if not manual_kana_queue.is_empty():
		current_kana = manual_kana_queue.pop_front()
	else:
		if remaining_kana_pool.is_empty():
			_refill_remaining_pool()
		if not remaining_kana_pool.is_empty():
			current_kana = remaining_kana_pool.pop_back()
	_update_target_kana()
	_load_guide_definition()

func _refill_remaining_pool() -> void:
	selected_kana = KanaState.get_selected_kana()
	if selected_kana.is_empty():
		selected_kana = KanaState.DEFAULT_KANA.duplicate()
	remaining_kana_pool = selected_kana.duplicate()
	_shuffle_remaining_pool()

func _shuffle_remaining_pool() -> void:
	for index in range(remaining_kana_pool.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp := remaining_kana_pool[index]
		remaining_kana_pool[index] = remaining_kana_pool[swap_index]
		remaining_kana_pool[swap_index] = temp

func _clear_strokes() -> void:
	if strokes_layer == null:
		return
	for child in strokes_layer.get_children():
		child.queue_free()
	active_line = null
	current_stroke_points = PackedVector2Array()
