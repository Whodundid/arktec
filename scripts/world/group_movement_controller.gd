class_name GroupMovementController
extends Node2D

## Centralizes right-click orders for selected player units.
## Formation mode is a command option, not a permanent unit behavior.

@export var formation_enabled := false
@export_range(16.0, 96.0, 1.0) var formation_spacing := 36.0
@export_range(0.0, 2.0, 0.05) var arrival_footprint_scale := 0.75

var _group_destination: Variant = null
var _group_marker_remaining := 0.0
var _group_entities: Array[Entity] = []
var _active_group_entities: Array[Entity] = []
var _active_group_destination: Variant = null
var _active_group_unit_arrival_radius := 0.0
var _formation_entities: Array[Entity] = []
var _formation_origin := Vector2.ZERO
var _formation_goal := Vector2.ZERO
var _formation_offsets: Array[Vector2] = []
var _formation_layout_entities: Array[Entity] = []
var _formation_layout_offsets: Array[Vector2] = []
var _formation_elapsed := 0.0
var _formation_duration := 0.0
var _formation_group_speed := 0.0
var _formation_retarget_remaining := 0.0
const FORMATION_RETARGET_INTERVAL := 0.12
# Keep this smaller than the distance a formation travels between correction
# ticks. Otherwise a unit can finish its temporary slot path, report no
# destination, and wait for the next correction before moving again.
const FORMATION_DESTINATION_REFRESH_DISTANCE := 12.0
const COMMAND_CONTEXT_ORDER := &"context_order"
const COMMAND_ATTACK_MOVE := &"attack_move"
const COMMAND_STANCE := &"stance"

func _ready() -> void:
	add_to_group("group_movement_controller")
	NetworkSession.command_received.connect(_on_network_command)
	set_process(true)

func _process(delta: float) -> void:
	_group_marker_remaining = maxf(_group_marker_remaining - delta, 0.0)
	if _group_marker_remaining <= 0.0:
		_group_destination = null
		_group_entities.clear()
	_update_group_arrival()
	_update_formation_motion(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		formation_enabled = not formation_enabled
		if not formation_enabled:
			_clear_formation_motion()
			_clear_formation_layout()
		print("Formation movement: %s" % ("ON" if formation_enabled else "OFF"))
		get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var selected_building := _selected_player_building()
	if selected_building != null:
		var rally_world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		selected_building.set_training_rally_point(_rally_target_position(rally_world_position, selected_building))
		get_viewport().set_input_as_handled()
		return
	var selected := _selected_player_entities()
	if selected.is_empty():
		return

	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
	var target_building := _friendly_building_at(world_position)
	if target_building != null:
		NetworkSession.submit_command(COMMAND_CONTEXT_ORDER, _entity_ids(selected), {"destination": target_building.global_position, "building_id": target_building.network_entity_id, "formation": formation_enabled})
		get_viewport().set_input_as_handled()
		return
	var vein := _ore_vein_at(world_position)
	if vein != null:
		var harvest_ordered := false
		for entity in selected:
			var alert := entity.get_component(AlertComponent) as AlertComponent
			var harvest := entity.get_component(HarvestComponent) as HarvestComponent
			if alert != null and alert.role == AlertComponent.Role.BUILDER and harvest != null:
				harvest_ordered = harvest.request_harvest(vein) or harvest_ordered
		if harvest_ordered:
			get_viewport().set_input_as_handled()
			return
	# A right-click on an enemy is an explicit attack order. Right-clicking
	# elsewhere remains a manual move and ignores enemies encountered in range.
	NetworkSession.submit_command(COMMAND_CONTEXT_ORDER, _entity_ids(selected), {"destination": world_position, "formation": formation_enabled})
	get_viewport().set_input_as_handled()

func _ore_vein_at(world_position: Vector2) -> OreVein:
	var closest: OreVein
	var closest_distance := 56.0
	for candidate in get_tree().get_nodes_in_group("ore_veins"):
		if not candidate is OreVein or not is_instance_valid(candidate):
			continue
		var vein := candidate as OreVein
		if vein.ore <= 1.0:
			continue
		var distance := vein.global_position.distance_to(world_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest = vein
	return closest

func _friendly_building_at(world_position: Vector2) -> EnemySpawnerBuilding:
	var closest: EnemySpawnerBuilding
	var closest_distance := 48.0
	for candidate in get_tree().get_nodes_in_group("buildings"):
		if not candidate is EnemySpawnerBuilding or not is_instance_valid(candidate):
			continue
		var building := candidate as EnemySpawnerBuilding
		var team := building.get_component(TeamComponent) as TeamComponent
		if team == null or team.team != TeamComponent.Team.PLAYER:
			continue
		var distance := building.global_position.distance_to(world_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest = building
	return closest

func _selected_player_building() -> EnemySpawnerBuilding:
	for candidate in get_tree().get_nodes_in_group("entities"):
		if not candidate is EnemySpawnerBuilding or not is_instance_valid(candidate) or not (candidate as Entity).is_selected:
			continue
		var building := candidate as EnemySpawnerBuilding
		var team := building.get_component(TeamComponent) as TeamComponent
		if team != null and team.team == TeamComponent.Team.PLAYER and building.is_owned_by_peer(NetworkSession.get_local_peer_id()):
			return building
	return null

func _rally_target_position(world_position: Vector2, owner: EnemySpawnerBuilding) -> Vector2:
	var closest_position := world_position
	var closest_distance := 56.0
	for candidate in get_tree().get_nodes_in_group("ore_veins"):
		if not candidate is OreVein or not is_instance_valid(candidate):
			continue
		var vein := candidate as OreVein
		if vein.ore <= 0.0:
			continue
		var distance := vein.global_position.distance_to(world_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_position = vein.global_position
	for candidate in get_tree().get_nodes_in_group("entities"):
		if candidate == owner or not candidate is Entity or not is_instance_valid(candidate):
			continue
		var entity := candidate as Entity
		var distance := entity.global_position.distance_to(world_position)
		if distance >= closest_distance:
			continue
		closest_distance = distance
		closest_position = entity.global_position
	return closest_position

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
		if team != null and team.is_player_controlled() and entity.is_owned_by_peer(NetworkSession.get_local_peer_id()) and entity.get_component(MovementComponent) != null:
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
	NetworkSession.submit_command(COMMAND_ATTACK_MOVE, _entity_ids(selected), {"destination": destination, "formation": formation_enabled})

func request_stance(mode: int) -> void:
	var selected := _selected_player_entities()
	if selected.is_empty():
		return
	NetworkSession.submit_command(COMMAND_STANCE, _entity_ids(selected), {"mode": mode})

func _on_network_command(sender_peer_id: int, command_type: StringName, entity_ids: Array, payload: Dictionary) -> void:
	if command_type != COMMAND_CONTEXT_ORDER and command_type != COMMAND_ATTACK_MOVE and command_type != COMMAND_STANCE:
		return
	var entities := _resolve_owned_entities(sender_peer_id, entity_ids)
	if entities.is_empty():
		return

	if command_type == COMMAND_STANCE:
		var mode := int(payload.get("mode", -1))
		if mode != CombatComponent.AUTO_ATTACK_MOVE and mode != CombatComponent.AUTO_HOLD_POSITION:
			return
		for entity in entities:
			var combat := entity.get_component(CombatComponent) as CombatComponent
			if combat != null:
				combat.set_auto_target_mode(mode)
		return

	var destination_value: Variant = payload.get("destination")
	if not destination_value is Vector2:
		return
	var destination := destination_value as Vector2
	if not destination.is_finite():
		return
	var building_id := int(payload.get("building_id", 0))
	if building_id > 0 and _issue_building_order(entities, building_id):
		return
	_cancel_harvesting_orders(entities)
	var previous_formation_mode := formation_enabled
	formation_enabled = bool(payload.get("formation", false))
	if command_type == COMMAND_CONTEXT_ORDER:
		if not _try_issue_attack(entities, destination):
			_issue_move(entities, destination)
	else:
		for entity in entities:
			var combat := entity.get_component(CombatComponent) as CombatComponent
			if combat != null:
				combat.arm_attack_move()
		if not _try_issue_attack(entities, destination):
			_confirm_attack_move(entities, destination)
	formation_enabled = previous_formation_mode

func _cancel_harvesting_orders(entities: Array[Entity]) -> void:
	for entity in entities:
		var harvest := entity.get_component(HarvestComponent) as HarvestComponent
		if harvest != null:
			harvest.cancel_if_mining()

func _issue_building_order(entities: Array[Entity], building_id: int) -> bool:
	var target_value := NetworkSession.get_entity(building_id)
	if target_value == null or not target_value is EnemySpawnerBuilding:
		return false
	var building := target_value as EnemySpawnerBuilding
	var building_team := building.get_component(TeamComponent) as TeamComponent
	if building_team == null or building_team.team != TeamComponent.Team.PLAYER:
		return false
	for entity in entities:
		var combat := entity.get_component(CombatComponent) as CombatComponent
		if combat != null:
			combat.begin_manual_move()
		var harvest := entity.get_component(HarvestComponent) as HarvestComponent
		if harvest != null and harvest.request_return_to_building(building):
			continue
		if harvest != null:
			harvest.cancel_if_mining()
		var movement := entity.get_component(MovementComponent) as MovementComponent
		if movement != null:
			var approach := building.get_building_approach_position(entity.global_position)
			movement.move_to(approach)
	return true

func _entity_ids(entities: Array[Entity]) -> Array:
	var ids: Array = []
	for entity in entities:
		if entity.network_entity_id > 0:
			ids.append(entity.network_entity_id)
	return ids

func _resolve_owned_entities(sender_peer_id: int, entity_ids: Array) -> Array[Entity]:
	var resolved: Array[Entity] = []
	var seen: Dictionary = {}
	for id_value in entity_ids:
		var entity_id := int(id_value)
		if entity_id <= 0 or seen.has(entity_id):
			continue
		seen[entity_id] = true
		var entity := NetworkSession.get_entity(entity_id)
		if entity == null or not entity.is_owned_by_peer(sender_peer_id):
			continue
		var team := entity.get_component(TeamComponent) as TeamComponent
		if team == null or not team.is_player_controlled() or entity.get_component(MovementComponent) == null:
			continue
		resolved.append(entity)
	return resolved

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
	var leader_combat: CombatComponent
	for entity in selected:
		var candidate_combat := entity.get_component(CombatComponent) as CombatComponent
		if candidate_combat != null:
			leader_combat = candidate_combat
			break
	if leader_combat == null or not leader_combat.try_set_target_at(world_position):
		return false
	_group_destination = null
	_group_entities.clear()
	_clear_group_arrival()
	_clear_formation_motion()
	_clear_formation_layout()
	var target := leader_combat.target
	for index in range(1, selected.size()):
		var combat := selected[index].get_component(CombatComponent) as CombatComponent
		if combat != null:
			combat.set_target(target, false)
			var movement := selected[index].get_component(MovementComponent) as MovementComponent
			if movement != null:
				if selected[index].global_position.distance_to(target.global_position) > combat.attack_range:
					movement.move_to(target.global_position, combat.attack_range)
				else:
					movement.stop()
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
	_clear_group_arrival()
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
		var arrival_buffer := _group_arrival_buffer(selected)
		if entity.global_position.distance_to(destinations[index]) <= movement.stopping_distance + arrival_buffer:
			movement.stop()
			actual_destinations.append(entity.global_position)
			continue
		movement.move_to(destinations[index], arrival_buffer)
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
	_arm_group_arrival(selected, _group_destination as Vector2)
	if formation_enabled:
		_clear_group_arrival()
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
	# Discard the previous travel paths immediately. Otherwise a reversal can
	# briefly send units toward their old slots before the next correction tick.
	for entity in _formation_entities:
		if not is_instance_valid(entity):
			continue
		var movement := entity.get_component(MovementComponent) as MovementComponent
		if movement != null:
			movement.stop()

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
	if _has_matching_formation_layout(_formation_entities):
		# Keep the established world-space arrangement when a completed formation
		# receives another order. Recomputing from the new travel heading would
		# swap front and back units on a 180-degree move.
		_formation_offsets = _formation_layout_offsets.duplicate()
	else:
		var final_slots := _formation_destinations(_formation_entities, goal)
		_formation_offsets.clear()
		for final_slot in final_slots:
			_formation_offsets.append(final_slot - goal)
		_formation_layout_entities = _formation_entities.duplicate()
		_formation_layout_offsets = _formation_offsets.duplicate()
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
	var is_final_formation_position := progress >= 1.0
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
		# The slot is moving with the formation during transit, so treating the
		# current slot as an arrival point makes units stop, lose their destination,
		# and then restart every few frames. Only use the footprint buffer once the
		# formation center has reached its final destination.
		var arrival_buffer := _group_arrival_buffer(_formation_entities) if is_final_formation_position else 0.0
		if distance > movement.stopping_distance + arrival_buffer:
			all_arrived = false
			var current_destination: Variant = movement.get_destination_position()
			var destination_needs_refresh := current_destination == null
			if current_destination is Vector2:
				destination_needs_refresh = (current_destination as Vector2).distance_to(slot) > FORMATION_DESTINATION_REFRESH_DISTANCE
			if destination_needs_refresh:
				movement.move_to(slot, arrival_buffer)
			# Slot correction and group travel are separate concerns. Use the
			# group's travel speed immediately so small early slot errors do not
			# create an artificial acceleration/inertia ramp.
			var formation_speed := _formation_group_speed
			if formation_speed <= 0.0:
				formation_speed = movement.get_move_speed_pixels_per_second()
			movement.set_formation_speed_pixels_per_second(minf(movement.get_move_speed_pixels_per_second(), formation_speed))
		elif is_final_formation_position:
			movement.finish_rotation_towards_last_travel_direction()
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

func _clear_formation_layout() -> void:
	_formation_layout_entities.clear()
	_formation_layout_offsets.clear()

func _has_matching_formation_layout(entities: Array[Entity]) -> bool:
	if entities.size() != _formation_layout_entities.size() or entities.is_empty():
		return false
	for index in range(entities.size()):
		if _formation_layout_entities[index] != entities[index]:
			return false
	return _formation_layout_offsets.size() == entities.size()

func _arm_group_arrival(entities: Array[Entity], destination: Vector2) -> void:
	if entities.is_empty() or formation_enabled:
		return
	_active_group_entities = entities.duplicate()
	_active_group_destination = destination
	_active_group_unit_arrival_radius = _group_unit_arrival_radius(entities)

func _clear_group_arrival() -> void:
	_active_group_entities.clear()
	_active_group_destination = null
	_active_group_unit_arrival_radius = 0.0

func _update_group_arrival() -> void:
	if _active_group_entities.is_empty() or not _active_group_destination is Vector2:
		return
	var all_units_arrived := true
	var valid_count := 0
	for entity in _active_group_entities:
		if not is_instance_valid(entity):
			continue
		valid_count += 1
		if entity.global_position.distance_to(_active_group_destination as Vector2) > _active_group_unit_arrival_radius:
			all_units_arrived = false
			break
	if valid_count == 0:
		_clear_group_arrival()
		return
	if not all_units_arrived:
		return
	# The order is satisfied as a group. Stopping everyone together prevents
	# trailing units from pushing already-settled units sideways to reach the
	# same point.
	for entity in _active_group_entities:
		if is_instance_valid(entity):
			var movement := entity.get_component(MovementComponent) as MovementComponent
			if movement != null:
				movement.stop()
				movement.finish_rotation_towards_last_travel_direction()
	_clear_group_arrival()

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

func _group_arrival_buffer(entities: Array[Entity]) -> float:
	# Arrival is based on the physical footprint of the units, not the number of
	# units selected. This lets a blob settle near a point instead of making its
	# front unit push through the rest of the group to touch one exact pixel.
	var largest_radius := 0.0
	var largest_leeway := 0.0
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		largest_radius = maxf(largest_radius, entity.collision_radius)
		largest_leeway = maxf(largest_leeway, entity.collision_leeway)
	return largest_radius * arrival_footprint_scale + largest_leeway

func _group_unit_arrival_radius(entities: Array[Entity]) -> float:
	var largest_radius := 0.0
	var largest_leeway := 0.0
	var largest_stopping_distance := 0.0
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		largest_radius = maxf(largest_radius, entity.collision_radius)
		largest_leeway = maxf(largest_leeway, entity.collision_leeway)
		var movement := entity.get_component(MovementComponent) as MovementComponent
		if movement != null:
			largest_stopping_distance = maxf(largest_stopping_distance, movement.stopping_distance)
	if largest_radius <= 0.0:
		return 0.0
	return largest_stopping_distance + largest_radius * arrival_footprint_scale + largest_leeway

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
