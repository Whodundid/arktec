class_name RTSCamera
extends Camera2D

## Lightweight 90s-style RTS camera.
## The camera is intentionally independent from the player. It can later
## become the commander's view while selected mercenaries act in the world.

@export var pan_speed := 760.0
@export var edge_size := 24.0
@export var zoom_step := 0.1
@export var min_zoom := 0.35
@export var max_zoom := 1.6
@export var world_limits := Rect2(-900.0, -520.0, 1800.0, 1040.0)
@export_range(0.0, 300.0, 1.0) var bottom_ui_safe_area := 195.0
@export_range(0.0, 1.0, 0.1) var edge_overpan_fraction := 1.0

var _dragging := false

func _ready() -> void:
	add_to_group("rts_cameras")

	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	_update_camera_limits()

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
	_update_camera_limits()

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
	_update_camera_limits()

func _update_camera_limits() -> void:
	var half_view := get_viewport_rect().size * 0.5 / zoom.x
	var bottom_world_limit := world_limits.end.y - bottom_ui_safe_area / zoom.x
	var horizontal_overpan := half_view.x * edge_overpan_fraction
	var vertical_overpan := half_view.y * edge_overpan_fraction
	# Camera2D's built-in limits constrain the viewport independently of our
	# position clamp, so expand them by the same overpan allowance as the custom
	# bounds above.
	limit_left = floori(world_limits.position.x - horizontal_overpan)
	limit_top = floori(world_limits.position.y - vertical_overpan)
	limit_right = ceili(world_limits.end.x + horizontal_overpan)
	limit_bottom = ceili(bottom_world_limit + vertical_overpan + bottom_ui_safe_area / zoom.x * edge_overpan_fraction)

func _clamp_position(value: Vector2) -> Vector2:
	var half_view := get_viewport_rect().size * 0.5 / zoom.x
	# Keep the bottom edge of the world above the persistent HUD strip. The
	# safe area is authored in screen pixels, so convert it back into world
	# units at the current zoom level before applying the camera limit.
	var bottom_world_limit := world_limits.end.y - bottom_ui_safe_area / zoom.x
	# Allow the camera center to reach the map edge. Since the viewport extends
	# half a view around its center, this gives the player up to half a viewport
	# of visible space beyond each map edge.
	var horizontal_overpan := half_view.x * edge_overpan_fraction
	var vertical_overpan := half_view.y * edge_overpan_fraction
	var horizontal_min := world_limits.position.x + half_view.x - horizontal_overpan
	var horizontal_max := world_limits.end.x - half_view.x + horizontal_overpan
	var vertical_min := world_limits.position.y + half_view.y - vertical_overpan
	var vertical_max := bottom_world_limit - half_view.y + vertical_overpan + bottom_ui_safe_area / zoom.x * edge_overpan_fraction
	var clamped_x := world_limits.get_center().x if horizontal_min > horizontal_max else clampf(value.x, horizontal_min, horizontal_max)
	var available_vertical_center := (world_limits.position.y + bottom_world_limit) * 0.5
	var clamped_y := available_vertical_center if vertical_min > vertical_max else clampf(value.y, vertical_min, vertical_max)
	return Vector2(
		clamped_x,
		clamped_y
	)
