class_name HarvestComponent
extends EntityComponent

const ORE_VEIN_SCRIPT = preload("res://scripts/world/ore_vein.gd")

## First worker behavior: mine a vein, walk home, deposit, repeat.

@export var enabled := true
@export_range(1.0, 30.0, 0.5) var harvest_per_second := 8.0
@export_range(1.0, 200.0, 1.0) var carry_capacity := 10.0
@export_range(4.0, 100.0, 1.0) var working_radius := 58.0
@export_range(0.5, 10.0, 0.5) var harvest_action_duration := 3.0
@export_range(1.0, 50.0, 1.0) var repair_per_second := 12.0
@export_range(24.0, 160.0, 4.0) var repair_radius := 72.0
@export_range(0.0, 256.0, 8.0) var alternate_vein_distance_tolerance := 96.0
var carried_ore := 0.0
var _mining_vein := false
var _harvest_action_remaining := 0.0
var _returning_home := false
var _movement: MovementComponent
var _alert: AlertComponent
var _wander: WanderComponent
var _target_vein: OreVein
var _repair_target: EnemySpawnerBuilding
var _home: Node2D
var _home_approach_position: Variant = null
var _decision_remaining := 0.0
var _manual_harvest_active := false

func on_entity_ready() -> void:
	_movement = entity.get_component(MovementComponent) as MovementComponent
	_alert = entity.get_component(AlertComponent) as AlertComponent
	_wander = entity.get_component(WanderComponent) as WanderComponent
	_decision_remaining = fmod(float(entity.get_instance_id()), 0.5)

func _physics_process(delta: float) -> void:
	if (not enabled and not _manual_harvest_active) or _movement == null:
		return
	if _alert != null and _alert.role != AlertComponent.Role.BUILDER:
		_release_mining_access()
		if _wander != null:
			_wander.enabled = true
		return
	if _alert != null and _alert.construction_active:
		_release_mining_access()
		entity.set_action_state(Entity.ActionState.CONSTRUCTING)
		return
	if _alert != null and _alert.state != AlertComponent.State.IDLE:
		_release_mining_access()
		return
	if _wander != null:
		_wander.enabled = false
	if _returning_home:
		entity.set_action_state(Entity.ActionState.RETURNING_TO_BASE)
		_go_home()
		return
	if _update_repair(delta):
		return
	_decision_remaining -= delta
	if _decision_remaining <= 0.0:
		_decision_remaining = 0.5
		_choose_target_if_needed()
	if carried_ore >= carry_capacity or (_target_vein == null and carried_ore > 0.0):
		_returning_home = true
		_home_approach_position = null
		entity.set_action_state(Entity.ActionState.RETURNING_TO_BASE)
		_go_home()
		return
	if _target_vein == null:
		return
	var sandbox := _find_battle_sandbox()
	if sandbox != null and bool(sandbox.call("request_ore_security", entity, _target_vein)):
		_release_mining_access()
		# The vein is currently inside an enemy threat area. A builder should
		# abandon the mining attempt and return to its Command Center, not stop
		# indefinitely at the resource while combat units are dispatched.
		_returning_home = true
		_home_approach_position = null
		entity.set_action_state(Entity.ActionState.RETURNING_TO_BASE)
		_go_home()
		return
	# MovementComponent stops at stopping_distance + arrival_buffer. Keep the
	# requested arrival point aligned with our actual interaction radius, or a
	# worker can get trapped forever just outside the harvest check.
	var approach_position := _get_approach_position(_target_vein)
	var distance_to_vein := entity.global_position.distance_to(_target_vein.global_position)
	var mining_enter_radius := maxf(working_radius + 12.0, _target_vein.harvest_radius + 12.0)
	var mining_exit_radius := mining_enter_radius + 16.0
	if _mining_vein and distance_to_vein > mining_exit_radius:
		_mining_vein = false
		_release_mining_access()
	if not _mining_vein and distance_to_vein <= mining_enter_radius:
		if _target_vein.request_mining_access(entity):
			_mining_vein = true
			_harvest_action_remaining = harvest_action_duration
			entity.set_action_state(Entity.ActionState.HARVESTING)
			_movement.stop()
		else:
			# Prefer a nearby vein that is genuinely available over waiting forever
			# behind another worker. Keep the queue when no comparable alternative
			# exists, so workers do not thrash between distant resource patches.
			if not _switch_to_available_alternative():
				_movement.stop()
				entity.set_action_state(Entity.ActionState.WAITING_FOR_RESOURCE)
				return
	if _mining_vein:
		_movement.stop()
		_harvest_action_remaining = maxf(_harvest_action_remaining - delta, 0.0)
		if _harvest_action_remaining > 0.0:
			entity.set_action_state(Entity.ActionState.HARVESTING)
			return
		# Mining is a discrete action: collect one full load when the action
		# completes, then immediately begin the trip home.
		carried_ore = minf(carry_capacity, _target_vein.harvest(carry_capacity))
		entity.queue_redraw()
		_mining_vein = false
		_release_mining_access()
		_returning_home = true
		_home_approach_position = null
		entity.set_action_state(Entity.ActionState.RETURNING_TO_BASE)
		_go_home()
	else:
		# Do not re-plan this same approach every physics frame when terrain
		# resolves the endpoint slightly differently. MovementComponent owns
		# stuck-route recovery; workers only issue a new path once idle.
		if not _movement.is_moving():
			_movement.move_to(approach_position)

func _get_approach_position(vein: OreVein) -> Vector2:
	# Give workers deterministic slots around the vein instead of making every
	# worker path to the exact same point and push the front worker forever.
	var assigned: Array[HarvestComponent] = []
	for candidate in get_tree().get_nodes_in_group("entities"):
		if not candidate is Entity:
			continue
		var harvest := (candidate as Entity).get_component(HarvestComponent) as HarvestComponent
		if harvest != null and harvest._target_vein == vein:
			assigned.append(harvest)
	assigned.sort_custom(func(first: HarvestComponent, second: HarvestComponent) -> bool:
		return first.entity.get_instance_id() < second.entity.get_instance_id()
	)
	var slot := assigned.find(self)
	if slot < 0:
		slot = absi(entity.get_instance_id()) % 6
	return vein.global_position + Vector2.RIGHT.rotated(float(slot) * TAU / 6.0) * 52.0

func _choose_target_if_needed() -> void:
	if not enabled and not _manual_harvest_active:
		return
	if is_instance_valid(_target_vein) and _target_vein.ore > 0.5:
		return
	if _manual_harvest_active:
		_manual_harvest_active = false
		entity.set_action_state(Entity.ActionState.IDLE)
		return
	_target_vein = null
	_mining_vein = false
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("ore_veins"):
		if is_instance_valid(candidate) and candidate.get_script() == ORE_VEIN_SCRIPT and float(candidate.get("ore")) > 1.0:
			var distance := entity.global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				_target_vein = candidate as OreVein

func _switch_to_available_alternative() -> bool:
	if not is_instance_valid(_target_vein):
		return false
	var original_distance := entity.global_position.distance_to(_target_vein.global_position)
	var best_vein: OreVein
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("ore_veins"):
		if not candidate is OreVein or candidate == _target_vein or not is_instance_valid(candidate):
			continue
		var vein := candidate as OreVein
		if vein.ore <= 1.0 or not vein.is_available_for_mining(entity):
			continue
		var distance := entity.global_position.distance_to(vein.global_position)
		if distance > original_distance + alternate_vein_distance_tolerance or distance >= best_distance:
			continue
		best_distance = distance
		best_vein = vein
	if not is_instance_valid(best_vein):
		return false
	_target_vein.release_mining_access(entity)
	_target_vein = best_vein
	_movement.stop()
	entity.set_action_state(Entity.ActionState.IDLE)
	return true

func _update_repair(delta: float) -> bool:
	if is_instance_valid(_repair_target):
		var target_health := _repair_target.get_component(HealthComponent) as HealthComponent
		if target_health == null or target_health.current_health >= target_health.maximum_health:
			_repair_target = null
	if not is_instance_valid(_repair_target):
		_repair_target = _find_repair_target()
	if not is_instance_valid(_repair_target):
		return false

	entity.set_action_state(Entity.ActionState.CONSTRUCTING)
	var distance_to_target := entity.global_position.distance_to(_repair_target.global_position)
	if distance_to_target > repair_radius:
		if not _movement.is_moving():
			_movement.move_to(_repair_target.global_position, repair_radius - _movement.stopping_distance)
		return true

	_movement.stop()
	var health := _repair_target.get_component(HealthComponent) as HealthComponent
	if health != null:
		health.heal(repair_per_second * delta)
	return true

func _find_repair_target() -> EnemySpawnerBuilding:
	var best_target: EnemySpawnerBuilding
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("territory_owners"):
		if not candidate is EnemySpawnerBuilding or not is_instance_valid(candidate):
			continue
		var building := candidate as EnemySpawnerBuilding
		if building.faction_team != _team() or building.under_construction:
			continue
		var health := building.get_component(HealthComponent) as HealthComponent
		if health == null or health.current_health >= health.maximum_health:
			continue
		var distance := entity.global_position.distance_squared_to(building.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = building
	return best_target

func _go_home() -> void:
	_release_mining_access()
	if not is_instance_valid(_home):
		_home_approach_position = null
		_home = _find_home()
	if _home == null:
		return
	if not _home_approach_position is Vector2:
		var approach_position := _home.global_position
		if _home.has_method("get_building_approach_position"):
			var profiling := DeepProfiler.is_enabled()
			var approach_started_usec := Time.get_ticks_usec() if profiling else 0
			approach_position = _home.call("get_building_approach_position", entity.global_position)
			if profiling:
				DeepProfiler.record_timing("harvest.home_approach", Time.get_ticks_usec() - approach_started_usec, entity)
		if DeepProfiler.is_enabled():
			DeepProfiler.increment("harvest.home_approach_calculations")
		_home_approach_position = approach_position
	var approach_position := _home_approach_position as Vector2
	if entity.global_position.distance_to(approach_position) > 14.0:
		var current_destination: Variant = _movement.get_destination_position()
		var already_heading_home := _movement.is_moving() and current_destination is Vector2 and (current_destination as Vector2).distance_to(approach_position) <= 2.0
		if not already_heading_home:
			if DeepProfiler.is_enabled():
				DeepProfiler.increment("harvest.home_move_requests")
			_movement.move_to(approach_position)
	else:
		_movement.stop()
		ResourceLedger.add_ore(_team(), roundi(carried_ore))
		carried_ore = 0.0
		entity.queue_redraw()
		_returning_home = false
		_home_approach_position = null
		if not _manual_harvest_active or not is_instance_valid(_target_vein) or _target_vein.ore <= 1.0:
			_target_vein = null
			_manual_harvest_active = false
		_mining_vein = false
		entity.set_action_state(Entity.ActionState.IDLE)

func _release_mining_access() -> void:
	if is_instance_valid(_target_vein):
		_target_vein.release_mining_access(entity)
	_mining_vein = false
	_harvest_action_remaining = 0.0
	if entity.action_state == Entity.ActionState.HARVESTING or entity.action_state == Entity.ActionState.WAITING_FOR_RESOURCE:
		entity.set_action_state(Entity.ActionState.IDLE)

func cancel_harvest_action() -> void:
	_release_mining_access()
	_target_vein = null
	_mining_vein = false
	_harvest_action_remaining = 0.0
	_returning_home = false
	_home_approach_position = null
	_manual_harvest_active = false

func cancel_if_mining() -> void:
	# A player move interrupts the worker's approach/mining order, but does not
	# abandon a load that is already being carried home.
	if not _returning_home and (is_instance_valid(_target_vein) or _mining_vein):
		cancel_harvest_action()

func request_harvest(vein: OreVein) -> bool:
	if not is_instance_valid(vein) or vein.ore <= 1.0 or _movement == null or _returning_home:
		return false
	if _alert != null and _alert.role != AlertComponent.Role.BUILDER:
		return false
	_release_mining_access()
	_repair_target = null
	_target_vein = vein
	_manual_harvest_active = true
	vein.flash_harvest_target()
	_movement.move_to(_get_approach_position(vein))
	entity.set_action_state(Entity.ActionState.PLAYER_COMMAND)
	return true

func request_return_to_building(building: EnemySpawnerBuilding) -> bool:
	if not is_instance_valid(building) or _movement == null or _team() != building.faction_team or carried_ore <= 0.0:
		return false
	_release_mining_access()
	_target_vein = null
	_manual_harvest_active = false
	_returning_home = true
	_home = building
	_home_approach_position = null
	entity.set_action_state(Entity.ActionState.RETURNING_TO_BASE)
	_go_home()
	return true

func can_start_construction() -> bool:
	# Construction orders are allowed to interrupt a return trip. Keep the
	# carried load; once construction finishes, the normal harvest loop sends
	# the builder home to deposit it.
	return true

func _find_home() -> Node2D:
	var best: Node2D
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("territory_owners"):
		if candidate is Node2D and candidate.get("faction_team") == _team() and not bool(candidate.get("under_construction")) and (not candidate.has_method("is_main_building") or bool(candidate.call("is_main_building"))):
			var distance := entity.global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				best = candidate as Node2D
	return best

func _find_battle_sandbox() -> Node:
	var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
	return null if sandboxes.is_empty() else sandboxes[0] as Node

func _team() -> int:
	var team := entity.get_component(TeamComponent) as TeamComponent
	return team.team if team != null else TeamComponent.Team.NEUTRAL
