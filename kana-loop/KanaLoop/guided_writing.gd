extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/ScrollContainer/VBoxContainer/BackButton
@onready var drawing_canvas: Control = $MarginContainer/ScrollContainer/VBoxContainer/DrawingArea/DrawingCanvas
@onready var strokes_layer: Node2D = $MarginContainer/ScrollContainer/VBoxContainer/DrawingArea/DrawingCanvas/Strokes
@onready var target_kana_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/DrawingArea/DrawingCanvas/TargetContainer/TargetKana
@onready var guide_lines_container: Node2D = $MarginContainer/ScrollContainer/VBoxContainer/DrawingArea/DrawingCanvas/GuideLines
@onready var progress_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/ProgressLabel
@onready var completion_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/CompletionLabel

var selected_kana: Array[String] = []
var active_line: Line2D
var current_stroke_points: PackedVector2Array = PackedVector2Array()
var current_stroke_index := 0
var guide_definition: Array[PackedVector2Array] = []
var guide_lines: Array[Line2D] = []

const GUIDE_TOLERANCE := 24.0
const GUIDE_DEFINITIONS := {
	"あ": [
		[Vector2(120, 140), Vector2(240, 140), Vector2(300, 200)],
		[Vector2(300, 200), Vector2(240, 280), Vector2(140, 280)],
	],
	"default": [
		[Vector2(120, 140), Vector2(240, 140), Vector2(300, 200)],
		[Vector2(300, 200), Vector2(240, 280), Vector2(140, 280)],
	],
}

func _ready() -> void:
	selected_kana = KanaState.get_selected_kana()
	_update_target_kana()
	_load_guide_definition()
	back_button.pressed.connect(_on_back_pressed)
	drawing_canvas.gui_input.connect(_on_drawing_canvas_input)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_play_current_kana()

func _update_target_kana() -> void:
	if selected_kana.is_empty():
		target_kana_label.text = "あ"
		return
	target_kana_label.text = selected_kana[0]

func _load_guide_definition() -> void:
	var kana_key := "default"
	if not selected_kana.is_empty():
		kana_key = selected_kana[0]
	guide_definition = _build_guide_definition(GUIDE_DEFINITIONS.get(kana_key, GUIDE_DEFINITIONS["default"]))
	current_stroke_index = 0
	completion_label.visible = false
	if guide_definition.is_empty():
		progress_label.text = "No guide available"
	else:
		progress_label.text = "Stroke 1/%d" % guide_definition.size()
	_build_guides()
	_update_guides_visibility()

func _build_guide_definition(raw_definition: Array) -> Array[PackedVector2Array]:
	var built: Array[PackedVector2Array] = []
	for stroke in raw_definition:
		var points := PackedVector2Array()
		for point in stroke:
			points.append(point)
		built.append(points)
	return built

func _play_current_kana() -> void:
	if selected_kana.is_empty():
		return
	KanaAudio.play_kana_audio(selected_kana[0])

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
	if current_stroke_index >= guide_definition.size():
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

func _add_point(point: Vector2) -> void:
	if active_line == null:
		return
	active_line.add_point(point)
	current_stroke_points.append(point)

func _end_stroke() -> void:
	if active_line == null:
		return
	var finished_points := current_stroke_points
	active_line = null
	current_stroke_points = PackedVector2Array()
	_evaluate_stroke(finished_points)

func _evaluate_stroke(stroke_points: PackedVector2Array) -> void:
	if current_stroke_index >= guide_definition.size():
		return
	var guide_points := guide_definition[current_stroke_index]
	if _stroke_matches_guide(stroke_points, guide_points):
		current_stroke_index += 1
		if current_stroke_index >= guide_definition.size():
			completion_label.visible = true
			progress_label.text = "Completed"
		else:
			progress_label.text = "Stroke %d/%d" % [current_stroke_index + 1, guide_definition.size()]
		_update_guides_visibility()
	else:
		progress_label.text = "Try stroke %d/%d" % [current_stroke_index + 1, guide_definition.size()]

func _stroke_matches_guide(stroke_points: PackedVector2Array, guide_points: PackedVector2Array) -> bool:
	if stroke_points.size() < 2 or guide_points.size() < 2:
		return false
	var max_distance := 0.0
	var total_distance := 0.0
	for point in stroke_points:
		var distance := _distance_to_polyline(point, guide_points)
		max_distance = max(max_distance, distance)
		total_distance += distance
	var average_distance := total_distance / float(stroke_points.size())
	return max_distance <= GUIDE_TOLERANCE and average_distance <= GUIDE_TOLERANCE * 0.7

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
	for child in guide_lines_container.get_children():
		child.queue_free()
	guide_lines.clear()
	for guide_points in guide_definition:
		var line := Line2D.new()
		line.width = 6.0
		line.default_color = Color(0.2, 0.2, 0.2, 0.25)
		line.round_precision = 8
		line.points = guide_points
		guide_lines_container.add_child(line)
		guide_lines.append(line)

func _update_guides_visibility() -> void:
	for index in range(guide_lines.size()):
		var line := guide_lines[index]
		line.visible = index == current_stroke_index

func _on_back_pressed() -> void:
	back_requested.emit()
