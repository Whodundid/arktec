class_name MovementComponent
extends EntityComponent

## Simple movement module. One Godot world unit is treated as one pixel, while
## speed is exposed in meters per second for gameplay tuning.

@export_range(0.0, 20.0, 0.1) var speed_meters_per_second := 3.0
@export var pixels_per_meter := 64.0

var move_direction := Vector2.ZERO
var target_position: Variant = null
var destination_position: Variant = null
var destination_marker_remaining := 0.0
var _path: Array[Vector2] = []
var _path_index := 0
var _formation_speed_pixels_per_second := -1.0

@export var stopping_distance := 4.0
@export var path_clearance := 12.0

func _physics_process(_delta: float) -> void:
	if entity == null:
		return
	destination_marker_remaining = maxf(destination_marker_remaining - _delta, 0.0)

	if not _path.is_empty():
		_follow_path()
	elif target_position != null:
		var distance_to_target := entity.global_position.distance_to(target_position)
		if distance_to_target <= stopping_distance:
			stop()
		else:
			move_direction = entity.global_position.direction_to(target_position)

	var direction := move_direction.normalized()
	if direction != Vector2.ZERO:
		entity.turn_towards(direction, _delta)
	var movement_speed := speed_meters_per_second * pixels_per_meter
	if _formation_speed_pixels_per_second >= 0.0:
		movement_speed = minf(movement_speed, _formation_speed_pixels_per_second)
	entity.velocity = direction * movement_speed
	if direction != Vector2.ZERO:
		entity.push_teammates(direction, entity.velocity.length() * _delta)
	entity.move_and_slide()
	if direction != Vector2.ZERO:
		for collision_index in range(entity.get_slide_collision_count()):
			var collider := entity.get_slide_collision(collision_index).get_collider()
			if collider is Entity and entity.is_teammate(collider as Entity):
				# The first push is predictive; this second pass reacts to the
				# actual contact so head-on units get a chance to slide around one
				# another on the same movement order.
				entity.push_teammates(direction, entity.collision_leeway)
				break

func set_move_direction(direction: Vector2) -> void:
	_clear_path()
	_clear_formation_speed()
	target_position = null
	destination_position = null
	destination_marker_remaining = 0.0
	move_direction = direction

func move_to(destination: Vector2) -> void:
	_clear_formation_speed()
	destination_position = destination
	var terrain_map := _find_terrain_map()
	if terrain_map != null:
		var path := terrain_map.find_path(entity.global_position, destination, path_clearance)
		if path.is_empty():
			stop()
			return
		_path = path
		_path_index = 0
		destination_position = path.back()
		destination_marker_remaining = 0.5
		target_position = null
		move_direction = Vector2.ZERO
		return

	_clear_path()
	target_position = destination
	destination_marker_remaining = 0.5

func clear_target() -> void:
	_clear_path()
	target_position = null
	destination_position = null
	destination_marker_remaining = 0.0

func stop() -> void:
	_clear_path()
	_clear_formation_speed()
	target_position = null
	destination_position = null
	destination_marker_remaining = 0.0
	move_direction = Vector2.ZERO

func is_moving() -> bool:
	return not _path.is_empty() or target_position != null or move_direction.length_squared() > 0.0

func get_destination_position() -> Variant:
	return destination_position

func get_destination_marker_alpha() -> float:
	return clampf(destination_marker_remaining / 0.5, 0.0, 1.0)

func get_move_speed_pixels_per_second() -> float:
	return speed_meters_per_second * pixels_per_meter

func set_formation_speed_pixels_per_second(value: float) -> void:
	_formation_speed_pixels_per_second = maxf(value, 0.0)

func _clear_formation_speed() -> void:
	_formation_speed_pixels_per_second = -1.0

func _follow_path() -> void:
	if _path_index >= _path.size():
		stop()
		return

	var waypoint := _path[_path_index]
	if entity.global_position.distance_to(waypoint) <= stopping_distance:
		_path_index += 1
		if _path_index >= _path.size():
			stop()
			return
		waypoint = _path[_path_index]

	move_direction = entity.global_position.direction_to(waypoint)

func _clear_path() -> void:
	_path.clear()
	_path_index = 0

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	if maps.is_empty():
		return null
	return maps[0] as TerrainMap
