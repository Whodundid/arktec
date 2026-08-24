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
var _arrival_buffer := 0.0
var _last_travel_direction := Vector2.ZERO
var _finishing_rotation_direction := Vector2.ZERO
var _stuck_ticks := 0
var _goal_stuck_ticks := 0
var _last_goal_distance := -1.0
var _best_goal_distance := -1.0
var _last_progress_target: Variant = null
var _goal_stall_seconds := 0.0
var _stuck_repath_attempted := false
var _stalemate_escape_attempted := false
var _stalemate_resume_destination: Variant = null
var _issuing_stalemate_escape := false
var _escape_collision_teammates: Array[Entity] = []
var _blocked_destination: Variant = null
var _blocked_destination_remaining := 0.0

@export var stopping_distance := 4.0
@export var path_clearance := 12.0
@export_range(1, 120, 1) var stuck_tick_limit := 15
@export_range(0.0, 4.0, 0.01) var minimum_progress_per_tick := 0.05
@export_range(0.5, 8.0, 0.1) var goal_stall_timeout_seconds := 1.5
@export_range(0.25, 5.0, 0.25) var blocked_destination_cooldown_seconds := 1.5

func _physics_process(_delta: float) -> void:
	if entity == null:
		return
	destination_marker_remaining = maxf(destination_marker_remaining - _delta, 0.0)
	_blocked_destination_remaining = maxf(_blocked_destination_remaining - _delta, 0.0)
	if _blocked_destination_remaining <= 0.0:
		_blocked_destination = null

	if not _path.is_empty():
		_follow_path()
	elif target_position != null:
		var distance_to_target := entity.global_position.distance_to(target_position)
		if distance_to_target <= _arrival_distance():
			_complete_direct_destination(entity.global_position.direction_to(target_position))
		else:
			move_direction = entity.global_position.direction_to(target_position)

	var direction := move_direction.normalized()
	var position_before_move := entity.global_position
	if direction != Vector2.ZERO:
		_last_travel_direction = direction
		entity.turn_towards(direction, _delta)
	elif _finishing_rotation_direction != Vector2.ZERO:
		_advance_finishing_rotation(_delta)
	var movement_speed := speed_meters_per_second * pixels_per_meter
	if _formation_speed_pixels_per_second >= 0.0:
		movement_speed = minf(movement_speed, _formation_speed_pixels_per_second)
	entity.velocity = direction * movement_speed
	if direction != Vector2.ZERO:
		entity.push_teammates(direction, entity.velocity.length() * _delta)
	entity.move_and_slide()
	if direction != Vector2.ZERO:
		_track_progress(position_before_move, _delta)
	else:
		_reset_stuck_tracking()
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
	_reset_stuck_tracking()
	_arrival_buffer = 0.0
	_finishing_rotation_direction = Vector2.ZERO
	target_position = null
	destination_position = null
	destination_marker_remaining = 0.0
	move_direction = direction

func move_to(destination: Vector2, arrival_buffer: float = 0.0) -> void:
	if _blocked_destination_remaining > 0.0 and _blocked_destination is Vector2 and (_blocked_destination as Vector2).distance_to(destination) <= 8.0:
		return
	_clear_formation_speed()
	_arrival_buffer = maxf(arrival_buffer, 0.0)
	_finishing_rotation_direction = Vector2.ZERO
	var previous_destination: Variant = destination_position
	var is_same_destination := previous_destination is Vector2 and (previous_destination as Vector2).distance_to(destination) <= 2.0
	if not is_same_destination:
		_reset_stuck_tracking()
		_blocked_destination = null
		_blocked_destination_remaining = 0.0
		if not _issuing_stalemate_escape:
			_stalemate_escape_attempted = false
	destination_position = destination
	var terrain_map := _find_terrain_map()
	if terrain_map != null:
		# The navigation grid describes tile occupancy, while physics resolves the
		# unit's actual circle. Keep the center farther from tile corners than the
		# nominal clearance or units can vibrate against an obstacle edge.
		var navigation_clearance := maxf(path_clearance, entity.collision_radius + entity.collision_leeway + 2.0)
		var path := terrain_map.find_path(entity.global_position, destination, navigation_clearance, entity)
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
	_reset_stuck_tracking()
	_arrival_buffer = 0.0
	_finishing_rotation_direction = Vector2.ZERO
	target_position = null
	destination_position = null
	destination_marker_remaining = 0.0

func stop() -> void:
	_clear_escape_collision_exceptions()
	_clear_path()
	_clear_formation_speed()
	_reset_stuck_tracking()
	_arrival_buffer = 0.0
	_finishing_rotation_direction = Vector2.ZERO
	target_position = null
	destination_position = null
	destination_marker_remaining = 0.0
	move_direction = Vector2.ZERO

func finish_rotation_towards_last_travel_direction() -> void:
	# Used by group movement when it settles a unit externally rather than
	# allowing the movement path to reach its own completion branch.
	_finishing_rotation_direction = Vector2.ZERO
	_begin_finishing_rotation(_last_travel_direction)

func is_moving() -> bool:
	return not _path.is_empty() or target_position != null or move_direction.length_squared() > 0.0

func get_destination_position() -> Variant:
	return destination_position

func get_navigation_path() -> Array[Vector2]:
	var planned_path: Array[Vector2] = _path.duplicate()
	return planned_path

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
		_complete_destination()
		return

	var waypoint := _path[_path_index]
	var final_direction := entity.global_position.direction_to(waypoint)
	var is_final_waypoint := _path_index == _path.size() - 1
	var waypoint_arrival_distance := _arrival_distance() if is_final_waypoint else stopping_distance
	if entity.global_position.distance_to(waypoint) <= waypoint_arrival_distance:
		_path_index += 1
		if _path_index >= _path.size():
			_complete_destination(final_direction)
			return
		waypoint = _path[_path_index]

	move_direction = entity.global_position.direction_to(waypoint)

func _clear_path() -> void:
	_path.clear()
	_path_index = 0

func _track_progress(position_before_move: Vector2, delta: float) -> void:
	var distance_moved := entity.global_position.distance_to(position_before_move)
	var goal_progress_stuck := false
	var progress_target: Variant = destination_position
	if not _path.is_empty() and _path_index < _path.size():
		progress_target = _path[_path_index]
	if progress_target is Vector2:
		var goal_distance := entity.global_position.distance_to(progress_target as Vector2)
		var target_changed := not (_last_progress_target is Vector2) or (_last_progress_target as Vector2).distance_to(progress_target as Vector2) > 0.1
		if target_changed or _best_goal_distance < 0.0:
			_goal_stuck_ticks = 0
			_goal_stall_seconds = 0.0
			_best_goal_distance = goal_distance
		elif goal_distance < _best_goal_distance - 1.0:
			_goal_stuck_ticks = 0
			_goal_stall_seconds = 0.0
			_best_goal_distance = goal_distance
		else:
			_goal_stuck_ticks += 1
			_goal_stall_seconds += delta
		_last_goal_distance = goal_distance
		_last_progress_target = progress_target
		goal_progress_stuck = _goal_stall_seconds >= goal_stall_timeout_seconds
	else:
		_goal_stuck_ticks = 0
		_goal_stall_seconds = 0.0
		_best_goal_distance = -1.0
		_last_progress_target = null

	if distance_moved >= minimum_progress_per_tick:
		_stuck_ticks = 0
	else:
		_stuck_ticks += 1

	if goal_progress_stuck:
		# A vibrating unit can move enough to evade the raw displacement counter
		# while making no progress toward its destination. Break overlapping
		# teammate contacts before attempting the lateral escape.
		entity.separate_overlapping_teammates()
		_stuck_ticks = stuck_tick_limit
		_goal_stuck_ticks = 0

	if _stuck_ticks < stuck_tick_limit:
		return

	if not _stuck_repath_attempted and destination_position != null:
		_stuck_repath_attempted = true
		var blocked_destination := destination_position as Vector2
		# A dynamic body may have blocked the route since the original path was
		# calculated. Give the path system one fresh chance before giving up.
		move_to(blocked_destination, _arrival_buffer)
		return

	if not _stalemate_escape_attempted and destination_position != null:
		var escape_position: Variant = _find_stalemate_escape(destination_position as Vector2)
		if escape_position != null:
			_stalemate_escape_attempted = true
			_stalemate_resume_destination = destination_position
			_issuing_stalemate_escape = true
			_set_escape_collision_exceptions()
			move_to(escape_position as Vector2)
			_issuing_stalemate_escape = false
			if destination_position == null:
				_clear_escape_collision_exceptions()
			return

	# Do not leave a stale target/path active after a persistent blockage. The
	# caller can issue a new order, or an AI behavior can choose another state.
	# Remember this destination briefly so an AI repeatedly reissuing the same
	# blocked order cannot immediately restart the vibration loop.
	var failed_destination: Variant = destination_position
	stop()
	if failed_destination is Vector2:
		_blocked_destination = failed_destination
		_blocked_destination_remaining = blocked_destination_cooldown_seconds

func _reset_stuck_tracking() -> void:
	_stuck_ticks = 0
	_goal_stuck_ticks = 0
	_last_goal_distance = -1.0
	_best_goal_distance = -1.0
	_last_progress_target = null
	_goal_stall_seconds = 0.0
	_stuck_repath_attempted = false

func _complete_destination(completion_direction: Vector2 = Vector2.ZERO) -> void:
	var resume_destination: Variant = _stalemate_resume_destination
	var resume_arrival_buffer := _arrival_buffer
	if completion_direction.length_squared() <= 0.0:
		completion_direction = _last_travel_direction
	_stalemate_resume_destination = null
	stop()
	if resume_destination is Vector2:
		# The sidestep was only an escape maneuver; continue the original order.
		_issuing_stalemate_escape = true
		move_to(resume_destination as Vector2, resume_arrival_buffer)
		_issuing_stalemate_escape = false
	else:
		_begin_finishing_rotation(completion_direction)

func _complete_direct_destination(completion_direction: Vector2) -> void:
	if completion_direction.length_squared() <= 0.0:
		completion_direction = move_direction
	stop()
	_begin_finishing_rotation(completion_direction)

func _begin_finishing_rotation(direction: Vector2) -> void:
	if direction.length_squared() <= 0.0:
		return
	_finishing_rotation_direction = direction.normalized()

func _advance_finishing_rotation(delta: float) -> void:
	var remaining_angle := absf(entity.facing_direction.angle_to(_finishing_rotation_direction))
	if remaining_angle <= deg_to_rad(1.0):
		entity.set_facing_direction(_finishing_rotation_direction)
		_finishing_rotation_direction = Vector2.ZERO
		return
	entity.turn_towards(_finishing_rotation_direction, delta)

func _arrival_distance() -> float:
	return stopping_distance + _arrival_buffer

func _find_stalemate_escape(original_destination: Vector2) -> Variant:
	var travel := entity.global_position.direction_to(original_destination)
	if travel.length_squared() <= 0.0:
		travel = Vector2.RIGHT
	var side := travel.orthogonal().normalized()
	var escape_distance := maxf(entity.collision_radius * 3.5, 40.0)
	var candidates := [
		entity.global_position + side * escape_distance,
		entity.global_position - side * escape_distance,
		entity.global_position - travel * escape_distance,
	]
	var terrain_map := _find_terrain_map()
	for candidate in candidates:
		if terrain_map != null:
			var candidate_path := terrain_map.find_path(entity.global_position, candidate, maxf(path_clearance, entity.collision_radius + entity.collision_leeway + 2.0))
			if candidate_path.is_empty():
				continue
		# Teammates are the dynamic blockage this escape is intended to break.
		# Structures and enemy bodies remain valid blockers.
		if _is_position_blocked(candidate, true):
			continue
		return candidate
	return null

func _is_position_blocked(position: Vector2, ignore_teammates: bool = false) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = entity.collision_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = entity.collision_mask
	query.exclude = [entity.get_rid()]
	if ignore_teammates:
		for candidate in entity.get_nearby_entities(128.0):
			if candidate is Entity and entity.is_teammate(candidate as Entity):
				query.exclude.append((candidate as Entity).get_rid())
	return not entity.get_world_2d().direct_space_state.intersect_shape(query, 8).is_empty()

func _set_escape_collision_exceptions() -> void:
	_clear_escape_collision_exceptions()
	for candidate in entity.get_nearby_entities(128.0):
		if candidate == entity or not candidate is Entity:
			continue
		var teammate := candidate as Entity
		if not entity.is_teammate(teammate) or teammate.grounded:
			continue
		if entity.global_position.distance_to(teammate.global_position) > 64.0:
			continue
		if entity.is_formation_collision_ignored(teammate):
			continue
		entity.set_formation_collision_ignored(teammate, true)
		teammate.set_formation_collision_ignored(entity, true)
		_escape_collision_teammates.append(teammate)

func _clear_escape_collision_exceptions() -> void:
	for teammate in _escape_collision_teammates:
		if is_instance_valid(teammate):
			entity.set_formation_collision_ignored(teammate, false)
			teammate.set_formation_collision_ignored(entity, false)
	_escape_collision_teammates.clear()

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	if maps.is_empty():
		return null
	return maps[0] as TerrainMap
