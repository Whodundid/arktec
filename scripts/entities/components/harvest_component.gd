class_name HarvestComponent
extends EntityComponent

const ORE_VEIN_SCRIPT = preload("res://scripts/world/ore_vein.gd")

## First worker behavior: mine a vein, walk home, deposit, repeat.

@export var enabled := true
@export_range(1.0, 30.0, 0.5) var harvest_per_second := 8.0
@export_range(1.0, 200.0, 1.0) var carry_capacity := 40.0
@export_range(4.0, 100.0, 1.0) var working_radius := 58.0
var carried_ore := 0.0
var _mining_vein := false
var _returning_home := false
var _movement: MovementComponent
var _alert: AlertComponent
var _wander: WanderComponent
var _target_vein: OreVein
var _home: Node2D
var _decision_remaining := 0.0

func on_entity_ready() -> void:
	_movement = entity.get_component(MovementComponent) as MovementComponent
	_alert = entity.get_component(AlertComponent) as AlertComponent
	_wander = entity.get_component(WanderComponent) as WanderComponent
	_decision_remaining = fmod(float(entity.get_instance_id()), 0.5)

func _physics_process(delta: float) -> void:
	if not enabled or _movement == null:
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
	_decision_remaining -= delta
	if _decision_remaining <= 0.0:
		_decision_remaining = 0.5
		_choose_target_if_needed()
	if carried_ore >= carry_capacity or (_target_vein == null and carried_ore > 0.0):
		_returning_home = true
		entity.set_action_state(Entity.ActionState.RETURNING_TO_BASE)
		_go_home()
		return
	if _target_vein == null:
		return
	var sandbox := _find_battle_sandbox()
	if sandbox != null and bool(sandbox.call("request_ore_security", entity, _target_vein)):
		_mining_vein = false
		_release_mining_access()
		_movement.stop()
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
			entity.set_action_state(Entity.ActionState.HARVESTING)
			_movement.stop()
		else:
			# This worker is queued behind the current miner. Hold the approach
			# position instead of trying to overlap the active worker.
			_movement.stop()
			entity.set_action_state(Entity.ActionState.WAITING_FOR_RESOURCE)
			return
	if _mining_vein:
		_movement.stop()
		carried_ore = minf(carry_capacity, carried_ore + _target_vein.harvest(harvest_per_second * delta))
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
	if is_instance_valid(_target_vein) and _target_vein.ore > 0.5:
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

func _go_home() -> void:
	_release_mining_access()
	_home = _find_home()
	if _home == null:
		return
	if entity.global_position.distance_to(_home.global_position) > 72.0:
		_movement.move_to(_home.global_position, 60.0)
	else:
		_movement.stop()
		ResourceLedger.add_ore(_team(), roundi(carried_ore))
		carried_ore = 0.0
		_returning_home = false
		_target_vein = null
		_mining_vein = false
		entity.set_action_state(Entity.ActionState.IDLE)

func _release_mining_access() -> void:
	if is_instance_valid(_target_vein):
		_target_vein.release_mining_access(entity)
	if entity.action_state == Entity.ActionState.HARVESTING or entity.action_state == Entity.ActionState.WAITING_FOR_RESOURCE:
		entity.set_action_state(Entity.ActionState.IDLE)

func cancel_harvest_action() -> void:
	_release_mining_access()
	_target_vein = null
	_mining_vein = false
	_returning_home = false

func can_start_construction() -> bool:
	# A worker carrying a load is already committed to returning it. Mining can
	# be interrupted for a strategic construction order, but a return trip may
	# not be abandoned halfway through.
	return not _returning_home

func _find_home() -> Node2D:
	var best: Node2D
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("territory_owners"):
		if candidate is Node2D and candidate.get("faction_team") == _team() and not bool(candidate.get("under_construction")):
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
