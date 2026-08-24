class_name SelectionBox3D
extends Control

## Screen-space RTS marquee that selects projected 3D signpost positions.

@export var drag_threshold := 8.0
@export var fill_color := Color(0.015, 0.025, 0.03, 0.42)
@export var border_color := Color("d8e9e5")

var controller: Node
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_current := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start = event.position
			_drag_current = event.position
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif _dragging:
			_drag_current = event.position
			if _drag_start.distance_to(_drag_current) >= drag_threshold:
				if controller != null:
					controller.call("_select_units_in_screen_rect", _screen_rect(_drag_start, _drag_current))
			elif controller != null:
				controller.call("_handle_left_click", event.position)
			_dragging = false
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_drag_current = event.position
		queue_redraw()

func _draw() -> void:
	if not _dragging or _drag_start.distance_to(_drag_current) < drag_threshold:
		return
	var selection_rect := _screen_rect(_drag_start, _drag_current)
	draw_rect(selection_rect, fill_color, true)
	draw_rect(selection_rect, border_color, false, 2.0)

func _screen_rect(first: Vector2, second: Vector2) -> Rect2:
	return Rect2(first, second - first).abs()
