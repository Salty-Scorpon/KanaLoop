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
var rng := RandomNumberGenerator.new()

const OUTLINE_DATA_PATH := "res://assets/data/kana_outline.json"
const GUIDE_SAMPLE_COUNT := 192
const MIN_DRAWN_LENGTH_RATIO := 0.35
const DIRECTION_JITTER := 0.05
const FINAL_T_THRESHOLD := 0.85

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
	_advance_to_next_kana()
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
	if drawing_canvas != null:
		drawing_canvas.gui_input.connect(_on_drawing_canvas_input)
	if stroke_outline_toggle != null:
		stroke_outline_toggle.button_pressed = stroke_outline_enabled
		stroke_outline_toggle.toggled.connect(_on_stroke_outline_toggled)
	if blackout_toggle != null:
		blackout_toggle.button_pressed = blackout_enabled
		blackout_toggle.toggled.connect(_on_blackout_toggled)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_play_current_kana()

func _update_target_kana() -> void:
	if target_kana_label == null:
		return
	if current_kana == "":
		target_kana_label.text = "あ"
		return
	target_kana_label.text = current_kana

func _load_guide_definition() -> void:
	var kana_key := current_kana
	if kana_key == "":
		kana_key = "あ"
	var kana_def: Dictionary = kana_outline_data.get(kana_key, {})
	if kana_def.is_empty() and not kana_outline_data.is_empty():
		kana_def = kana_outline_data.values()[0]
	_clear_strokes()
	stroke_runtimes = _build_stroke_runtimes(kana_def)
	current_stroke_index = 0
	if completion_label != null:
		completion_label.visible = false
	if stroke_runtimes.is_empty():
		progress_label.text = "No guide available"
	else:
		progress_label.text = "Stroke 1/%d" % stroke_runtimes.size()
	_build_guides()
	_update_guides_visibility()

func _load_kana_outline_data() -> void:
	var file := FileAccess.open(OUTLINE_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open kana outline data at %s" % OUTLINE_DATA_PATH)
		return
	var json_text := file.get_as_text()
	var parsed := JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Kana outline JSON is not an array.")
		return
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var kana_value := entry.get("kana", "")
		if kana_value != "":
			kana_outline_data[kana_value] = entry

func _build_stroke_runtimes(kana_def: Dictionary) -> Array[Dictionary]:
	var runtimes: Array[Dictionary] = []
	if kana_def.is_empty():
		return runtimes
	var strokes: Array = kana_def.get("strokes", [])
	var glyph_size := _get_glyph_size()
	var glyph_origin := _get_glyph_origin()
	for stroke in strokes:
		if typeof(stroke) != TYPE_DICTIONARY:
			continue
		var rules: Dictionary = stroke.get("rules", {})
		var start_hint: Dictionary = stroke.get("start_hint", {})
		var end_hint: Dictionary = stroke.get("end_hint", {})
		var start_point := _to_canvas_point(start_hint, glyph_origin, glyph_size)
		var end_point := _to_canvas_point(end_hint, glyph_origin, glyph_size)
		var path_segments: Array = stroke.get("path_hint", [])
		var path_samples := _build_path_samples(path_segments, glyph_origin, glyph_size, GUIDE_SAMPLE_COUNT)
		var cumulative_lengths := _build_cumulative_lengths(path_samples)
		var total_length := cumulative_lengths[cumulative_lengths.size() - 1] if cumulative_lengths.size() > 0 else 0.0
		runtimes.append({
			"start_point": start_point,
			"end_point": end_point,
			"start_gate_radius": float(rules.get("start_must_be_near", 0.08)) * glyph_size,
			"end_gate_radius": float(rules.get("end_must_be_near", 0.08)) * glyph_size,
			"corridor_radius": float(rules.get("corridor_radius", 0.05)) * glyph_size,
			"direction_enforced": bool(rules.get("direction_enforced", true)),
			"path_samples": path_samples,
			"cumulative_lengths": cumulative_lengths,
			"total_length": total_length,
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

func _start_stroke(point: Vector2) -> void:
	if current_stroke_index >= stroke_runtimes.size():
		return
	if strokes_layer == null:
		return
	stroke_start_gate_met = false
	var runtime: Dictionary = stroke_runtimes[current_stroke_index]
	var start_point: Vector2 = runtime.get("start_point", Vector2.ZERO)
	var start_gate_radius: float = runtime.get("start_gate_radius", 0.0)
	if point.distance_to(start_point) > start_gate_radius:
		progress_label.text = "Start closer to the guide"
		return
	active_line = Line2D.new()
	active_line.width = 6.0
	active_line.default_color = Color(0.2, 0.4, 0.9, 0.9)
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
	var runtime: Dictionary = stroke_runtimes[current_stroke_index]
	var corridor_radius: float = runtime.get("corridor_radius", 0.0)
	var distance := _distance_to_polyline(point, runtime.get("path_samples", PackedVector2Array()))
	if distance > corridor_radius:
		stroke_has_red = true
	active_line.default_color = Color(0.9, 0.2, 0.2, 0.9) if stroke_has_red else Color(0.2, 0.4, 0.9, 0.9)
	if runtime.get("direction_enforced", true):
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
			progress_label.text = "Stroke %d/%d" % [current_stroke_index + 1, stroke_runtimes.size()]
		_update_guides_visibility()
	else:
		if finished_line != null:
			finished_line.queue_free()
		progress_label.text = "Try stroke %d/%d" % [current_stroke_index + 1, stroke_runtimes.size()]

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
	if total_length > 0.0 and drawn_length < total_length * MIN_DRAWN_LENGTH_RATIO:
		return false
	if runtime.get("direction_enforced", true):
		if stroke_direction_failed:
			return false
		if stroke_last_t < FINAL_T_THRESHOLD:
			return false
	return true

func _distance_to_polyline(point: Vector2, polyline: PackedVector2Array) -> float:
	var best_distance := INF
	for index in range(polyline.size() - 1):
		var start := polyline[index]
		var end := polyline[index + 1]
		best_distance = min(best_distance, _distance_to_segment(point, start, end))
	return best_distance

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared == 0.0:
		return point.distance_to(start)
	var t := (point - start).dot(segment) / length_squared
	t = clamp(t, 0.0, 1.0)
	var projection := start + segment * t
	return point.distance_to(projection)

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
	var segment_sample_count := max(2, int(ceil(float(samples_per_stroke) / float(segments.size()))))
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
		var normalized_point := _evaluate_segment(segment_type, points, t)
		var canvas_point := origin + normalized_point * glyph_size
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
		return _point_from_dict(points[0])
	return Vector2.ZERO

func _lerp_point(a: Dictionary, b: Dictionary, t: float) -> Vector2:
	var p0 := _point_from_dict(a)
	var p1 := _point_from_dict(b)
	return p0.lerp(p1, t)

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
	var glyph_size := min(canvas_size.x, canvas_size.y)
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

func _project_t_on_path(point: Vector2, runtime: Dictionary) -> float:
	var samples: PackedVector2Array = runtime.get("path_samples", PackedVector2Array())
	var lengths: PackedFloat32Array = runtime.get("cumulative_lengths", PackedFloat32Array())
	if samples.size() < 2 or lengths.size() != samples.size():
		return 0.0
	var best_distance := INF
	var best_length := 0.0
	for index in range(samples.size() - 1):
		var start := samples[index]
		var end := samples[index + 1]
		var segment := end - start
		var length_squared := segment.length_squared()
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

func _on_back_pressed() -> void:
	back_requested.emit()

func _handle_kana_completed() -> void:
	if completion_label != null:
		completion_label.visible = true
	progress_label.text = "Completed"
	_play_current_kana()
	call_deferred("_advance_to_next_kana")

func _advance_to_next_kana() -> void:
	if remaining_kana_pool.is_empty():
		_refill_remaining_pool()
	current_kana = ""
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
