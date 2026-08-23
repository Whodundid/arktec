class_name GroupMovementController
extends Node2D

## Centralizes right-click orders for selected player units.
## Formation mode is a command option, not a permanent unit behavior.

@export var formation_enabled := false
@export_range(16.0, 96.0, 1.0) var formation_spacing := 36.0

var _group_destination: Variant = null
var _group_marker_remaining := 0.0
var _group_entities: Array[Entity] = []
var _formation_entities: Array[Entity] = []
var _formation_origin := Vector2.ZERO
var _formation_goal := Vector2.ZERO
var _formation_offsets: Array[Vector2] = []
var _formation_elapsed := 0.0
var _formation_duration := 0.0
var _formation_group_speed := 0.0
var _formation_retarget_remaining := 0.0
const FORMATION_RETARGET_INTERVAL := 0.12

func _ready() -> void:
	add_to_group("group_movement_controller")
	set_process(true)

func _process(delta: float) -> void:
	_group_marker_remaining = maxf(_group_marker_remaining - delta, 0.0)
	if _group_marker_remaining <= 0.0:
		_group_destination = null
		_group_entities.clear()
	_update_formation_motion(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		formation_enabled = not formation_enabled
		if not formation_enabled:
			_clear_formation_motion()
		print("Formation movement: %s" % ("ON" if formation_enabled else "OFF"))
		get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var selected := _selected_player_entities()
	if selected.is_empty():
		return

	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
	# A right-click on an enemy is an explicit attack order. Right-clicking
	# elsewhere remains a manual move and ignores enemies encountered in range.
	if _try_issue_attack(selected, world_position):
		get_viewport().set_input_as_handled()
		return
	_issue_move(selected, world_position)
	get_viewport().set_input_as_handled()

func is_formation_enabled() -> bool:
	return formation_enabled

func has_group_marker() -> bool:
	return _group_destination != null and _group_marker_remaining > 0.0

func get_group_destination() -> Variant:
	return _group_destination

func get_group_marker_alpha() -> float:
	return clampf(_group_marker_remaining / 0.5, 0.0, 1.0)

func get_group_marker_color() -> Color:
	return Color("5ee27a")

func is_entity_in_group_order(entity: Entity) -> bool:
	return has_group_marker() and _group_entities.has(entity)

func is_entity_in_formation(entity: Entity) -> bool:
	return _formation_entities.has(entity)

func _selected_player_entities() -> Array[Entity]:
	var selected: Array[Entity] = []
	for candidate in get_tree().get_nodes_in_group("entities"):
		if not candidate is Entity or not (candidate as Entity).is_selected:
			continue
		var entity := candidate as Entity
		var team := entity.get_component(TeamComponent) as TeamComponent
		if team != null and team.is_player_controlled() and entity.get_component(MovementComponent) != null:
			selected.append(entity)
	return selected

func arm_attack_move() -> void:
	for entity in _selected_player_entities():
		var combat := entity.get_component(CombatComponent) as CombatComponent
		if combat != null:
			combat.arm_attack_move()

func has_attack_move_armed() -> bool:
	for entity in _selected_player_entities():
		var combat := entity.get_component(CombatComponent) as CombatComponent
		if combat != null and combat.attack_move_armed:
			return true
	return false

func confirm_attack_move(destination: Vector2) -> void:
	var selected := _selected_player_entities()
	if not _has_attack_move_armed(selected):
		return
	if _try_issue_attack(selected, destination):
		return
	_confirm_attack_move(selected, destination)

func _has_attack_move_armed(selected: Array[Entity]) -> bool:
	for entity in selected:
		var combat := entity.get_component(CombatComponent) as CombatComponent
		if combat != null and combat.attack_move_armed:
			return true
	return false

func _confirm_attack_move(selected: Array[Entity], destination: Vector2) -> void:
	_clear_formation_motion()
	_group_destination = destination
	_group_entities = selected.duplicate()
	_group_marker_remaining = 0.5
	var destinations := _formation_destinations(selected, destination) if formation_enabled else _free_move_destinations(selected, destination)
	var actual_destinations: Array[Vector2] = []
	for index in range(selected.size()):
		var combat := selected[index].get_component(CombatComponent) as CombatComponent
		if combat != null:
			combat.confirm_attack_move(destinations[index])
		var movement := selected[index].get_component(MovementComponent) as MovementComponent
		var resolved: Variant = movement.get_destination_position() if movement != null else null
		if resolved != null:
			actual_destinations.append(resolved as Vector2)
	# If every unit was already in attack range, no movement destination exists.
	# Keep the marker at the player's clicked location instead of averaging the
	# units' current positions and drawing it underneath them.
	if not actual_destinations.is_empty():
		var destination_sum := Vector2.ZERO
		for actual_destination in actual_destinations:
			destination_sum += actual_destination
		_group_destination = destination_sum / float(actual_destinations.size())
	if formation_enabled:
		_begin_formation_motion(selected, _group_destination as Vector2)

func _try_issue_attack(selected: Array[Entity], world_position: Vector2) -> bool:
	var leader_combat := selected[0].get_component(CombatComponent) as CombatComponent
	if leader_combat == null or not leader_combat.try_set_target_at(world_position):
		return false
	_group_destination = null
	_group_entities.clear()
	_clear_formation_motion()
	var target := leader_combat.target
	for index in range(1, selected.size()):
		var combat := selected[index].get_component(CombatComponent) as CombatComponent
		if combat != null:
			combat.set_target(target)
	return true

func _issue_move(selected: Array[Entity], destination: Vector2) -> void:
	# A right-click is always a manual move, so it cancels any armed or active
	# attack-move state before potentially retargeting the live formation.
	for entity in selected:
		var combat := entity.get_component(CombatComponent) as CombatComponent
		if combat != null:
			combat.begin_manual_move()
	if formation_enabled:
		if not _formation_entities.is_empty():
			_retarget_active_formation(destination)
			return
	_clear_formation_motion()
	_group_destination = destination
	_group_entities = selected.duplicate()
	_group_marker_remaining = 0.5
	var destinations := _formation_destinations(selected, destination) if formation_enabled else _free_move_destinations(selected, destination)
	var actual_destinations: Array[Vector2] = []

	for index in range(selected.size()):
		var entity := selected[index]
		var movement := entity.get_component(MovementComponent) as MovementComponent
		if movement == null:
			continue
		if entity.global_position.distance_to(destinations[index]) <= movement.stopping_distance:
			movement.stop()
			actual_destinations.append(entity.global_position)
			continue
		movement.move_to(destinations[index])
		var resolved_destination: Variant = movement.get_destination_position()
		if resolved_destination != null:
			actual_destinations.append(resolved_destination as Vector2)
		else:
			actual_destinations.append(entity.global_position)

	if formation_enabled:
		var slowest_travel_time := 0.0
		for index in range(selected.size()):
			var movement := selected[index].get_component(MovementComponent) as MovementComponent
			var speed := maxf(movement.get_move_speed_pixels_per_second(), 0.1)
			slowest_travel_time = maxf(slowest_travel_time, selected[index].global_position.distance_to(actual_destinations[index]) / speed)
		if slowest_travel_time > 0.0:
			for index in range(selected.size()):
				var movement := selected[index].get_component(MovementComponent) as MovementComponent
				var distance := selected[index].global_position.distance_to(actual_destinations[index])
				movement.set_formation_speed_pixels_per_second(distance / slowest_travel_time)

	if not actual_destinations.is_empty():
		var destination_sum := Vector2.ZERO
		for actual_destination in actual_destinations:
			destination_sum += actual_destination
		_group_destination = destination_sum / float(actual_destinations.size())
	if formation_enabled:
		_begin_formation_motion(selected, _group_destination as Vector2)

func _retarget_active_formation(destination: Vector2) -> void:
	var progress := clampf(_formation_elapsed / maxf(_formation_duration, 0.1), 0.0, 1.0)
	var current_center := _formation_origin.lerp(_formation_goal, progress)
	_formation_origin = current_center
	_formation_goal = destination
	_formation_elapsed = 0.0
	var group_speed := maxf(_formation_group_speed, 0.1)
	_formation_duration = maxf(current_center.distance_to(destination) / group_speed, 0.1)
	_formation_retarget_remaining = 0.0
	_group_destination = destination
	_group_marker_remaining = 0.5

func _begin_formation_motion(selected: Array[Entity], goal: Vector2) -> void:
	if selected.is_empty():
		return
	_formation_entities = selected.duplicate()
	_set_formation_collision_exceptions(true)
	_formation_goal = goal
	var position_sum := Vector2.ZERO
	for entity in _formation_entities:
		position_sum += entity.global_position
	_formation_origin = position_sum / float(_formation_entities.size())
	var final_slots := _formation_destinations(_formation_entities, goal)
	_formation_offsets.clear()
	for final_slot in final_slots:
		_formation_offsets.append(final_slot - goal)
	_formation_duration = 0.0
	for index in range(_formation_entities.size()):
		var movement := _formation_entities[index].get_component(MovementComponent) as MovementComponent
		if movement == null:
			continue
		var speed := maxf(movement.get_move_speed_pixels_per_second(), 0.1)
		var final_slot := goal + _formation_offsets[index]
		_formation_duration = maxf(_formation_duration, _formation_entities[index].global_position.distance_to(final_slot) / speed)
	_formation_elapsed = 0.0
	_formation_group_speed = _formation_origin.distance_to(_formation_goal) / maxf(_formation_duration, 0.1)
	_formation_retarget_remaining = 0.0

func _update_formation_motion(delta: float) -> void:
	if _formation_entities.is_empty():
		return
	_formation_elapsed += delta
	_formation_retarget_remaining -= delta
	if _formation_retarget_remaining > 0.0:
		return
	_formation_retarget_remaining = FORMATION_RETARGET_INTERVAL
	var progress := clampf(_formation_elapsed / maxf(_formation_duration, 0.1), 0.0, 1.0)
	var formation_center := _formation_origin.lerp(_formation_goal, progress)
	var all_arrived := true
	for index in range(_formation_entities.size()):
		var entity := _formation_entities[index]
		if not is_instance_valid(entity):
			continue
		var movement := entity.get_component(MovementComponent) as MovementComponent
		if movement == null:
			continue
		# Combat owns movement once attack-move has acquired a target. Do not
		# reissue the formation slot order and make the unit ignore that target.
		var combat := entity.get_component(CombatComponent) as CombatComponent
		if combat != null and is_instance_valid(combat.target):
			movement.stop()
			continue
		var slot := formation_center + _formation_offsets[index]
		var distance := entity.global_position.distance_to(slot)
		if distance > movement.stopping_distance:
			all_arrived = false
			movement.move_to(slot)
			# Slot correction and group travel are separate concerns. Use the
			# group's travel speed immediately so small early slot errors do not
			# create an artificial acceleration/inertia ramp.
			var formation_speed := _formation_group_speed
			if formation_speed <= 0.0:
				formation_speed = movement.get_move_speed_pixels_per_second()
			movement.set_formation_speed_pixels_per_second(minf(movement.get_move_speed_pixels_per_second(), formation_speed))
	if progress >= 1.0 and all_arrived:
		_clear_formation_motion()

func _clear_formation_motion() -> void:
	_set_formation_collision_exceptions(false)
	_formation_entities.clear()
	_formation_offsets.clear()
	_formation_elapsed = 0.0
	_formation_duration = 0.0
	_formation_group_speed = 0.0
	_formation_retarget_remaining = 0.0

func _set_formation_collision_exceptions(ignored: bool) -> void:
	for first_index in range(_formation_entities.size()):
		var first := _formation_entities[first_index]
		if not is_instance_valid(first):
			continue
		for second_index in range(first_index + 1, _formation_entities.size()):
			var second := _formation_entities[second_index]
			if not is_instance_valid(second):
				continue
			first.set_formation_collision_ignored(second, ignored)
			second.set_formation_collision_ignored(first, ignored)
			if not ignored:
				first.separate_from_teammate(second)

func _free_move_destinations(selected: Array[Entity], destination: Vector2) -> Array[Vector2]:
	var destinations: Array[Vector2] = []
	for _entity in selected:
		destinations.append(destination)
	return destinations

func _formation_destinations(selected: Array[Entity], destination: Vector2) -> Array[Vector2]:
	var destinations: Array[Vector2] = []
	var columns := maxi(1, ceili(sqrt(float(selected.size()))))
	var rows := ceili(float(selected.size()) / float(columns))
	var position_sum := Vector2.ZERO
	for entity in selected:
		position_sum += entity.global_position
	var centroid := position_sum / float(selected.size())
	var heading := centroid.direction_to(destination)
	if heading == Vector2.ZERO:
		heading = Vector2.RIGHT
	var right := heading.orthogonal()
	for index in range(selected.size()):
		var column := index % columns
		var row := index / columns
		var local_x := (float(column) - float(columns - 1) * 0.5) * formation_spacing
		var local_y := (float(row) - float(rows - 1) * 0.5) * formation_spacing
		destinations.append(destination + right * local_x + heading * local_y)
	return destinations
