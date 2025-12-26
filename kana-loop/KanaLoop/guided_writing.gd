extends Control

signal back_requested

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var drawing_canvas: Control = $MarginContainer/VBoxContainer/DrawingArea/DrawingCanvas
@onready var strokes_layer: Node2D = $MarginContainer/VBoxContainer/DrawingArea/DrawingCanvas/Strokes
@onready var target_kana_label: Label = $MarginContainer/VBoxContainer/DrawingArea/DrawingCanvas/TargetContainer/TargetKana

var selected_kana: Array[String] = []
var active_line: Line2D

func _ready() -> void:
	selected_kana = KanaState.get_selected_kana()
	_update_target_kana()
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

func _start_stroke(position: Vector2) -> void:
	active_line = Line2D.new()
	active_line.width = 6.0
	active_line.default_color = Color(0.2, 0.4, 0.9, 0.9)
	active_line.joint_mode = Line2D.LINE_JOINT_ROUND
	active_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	active_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	active_line.add_point(position)
	strokes_layer.add_child(active_line)

func _add_point(position: Vector2) -> void:
	if active_line == null:
		return
	active_line.add_point(position)

func _end_stroke() -> void:
	active_line = null

func _on_back_pressed() -> void:
	back_requested.emit()
