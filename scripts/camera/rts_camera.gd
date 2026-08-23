class_name RTSCamera
extends Camera2D

## Lightweight 90s-style RTS camera.
## The camera is intentionally independent from the player. It can later
## become the commander's view while selected mercenaries act in the world.

@export var pan_speed := 760.0
@export var edge_size := 24.0
@export var zoom_step := 0.1
@export var min_zoom := 0.65
@export var max_zoom := 1.6
@export var world_limits := Rect2(-900.0, -520.0, 1800.0, 1040.0)

var _dragging := false

func _ready() -> void:
	add_to_group("rts_cameras")

	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	limit_left = int(world_limits.position.x)
	limit_top = int(world_limits.position.y)
	limit_right = int(world_limits.end.x)
	limit_bottom = int(world_limits.end.y)

func _process(delta: float) -> void:
	var direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if direction != Vector2.ZERO:
		position += direction * pan_speed * delta / zoom.x

	if not _dragging:
		var viewport_size := get_viewport_rect().size
		var mouse_position := get_viewport().get_mouse_position()
		var edge_direction := Vector2.ZERO
		if mouse_position.x <= edge_size:
			edge_direction.x -= 1.0
		elif mouse_position.x >= viewport_size.x - edge_size:
			edge_direction.x += 1.0
		if mouse_position.y <= edge_size:
			edge_direction.y -= 1.0
		elif mouse_position.y >= viewport_size.y - edge_size:
			edge_direction.y += 1.0
		position += edge_direction.normalized() * pan_speed * delta / zoom.x

	position = _clamp_position(position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x + zoom_step)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x - zoom_step)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom.x
		position = _clamp_position(position)

func _set_zoom(value: float) -> void:
	var clamped_zoom := clampf(value, min_zoom, max_zoom)
	zoom = Vector2.ONE * clamped_zoom

func _clamp_position(value: Vector2) -> Vector2:
	var half_view := get_viewport_rect().size * 0.5 / zoom.x
	return Vector2(
		clampf(value.x, world_limits.position.x + half_view.x, world_limits.end.x - half_view.x),
		clampf(value.y, world_limits.position.y + half_view.y, world_limits.end.y - half_view.y)
	)
