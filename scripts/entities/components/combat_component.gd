class_name CombatComponent
extends EntityComponent

## RTS-style combat behavior. An order gives this component a target; after
## that, the entity owns its own facing, cooldown, and projectile creation.

signal target_changed(target: Entity)
signal shot_fired(projectile: Node2D, target: Entity)
signal attack_stopped(reason: String)

enum AutoTargetMode {
	ATTACK_MOVE,
	HOLD_POSITION,
}

const AUTO_ATTACK_MOVE := AutoTargetMode.ATTACK_MOVE
const AUTO_HOLD_POSITION := AutoTargetMode.HOLD_POSITION

@export var projectile_scene: PackedScene
@export var attack_range := 420.0
@export var fire_interval := 0.45
@export var projectile_speed := 900.0
@export var projectile_damage := 20.0
@export var projectile_radius := 6.0
@export var auto_target_mode := AutoTargetMode.ATTACK_MOVE
@export_range(0.05, 0.5, 0.01) var target_scan_interval := 0.25
@export_range(0.05, 0.5, 0.01) var line_of_sight_check_interval := 0.2

var target: Entity
var _cooldown := 0.0
var _movement_blocked_last_frame := false
var _los_move_requested := false
var attack_move_armed := false
var _attack_move_active := true
var _manual_move_active := false
var _target_scan_remaining := 0.0
var _line_of_sight_remaining := 0.0
var _cached_line_of_sight := false
var _cached_line_of_sight_target: Entity

func on_entity_ready() -> void:
	# Spread otherwise-identical sensing work across the physics frame instead
	# of making every spawned unit perform its expensive scan simultaneously.
	_target_scan_remaining = fmod(float(entity.get_instance_id()), target_scan_interval)
	_line_of_sight_remaining = 0.0

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	_target_scan_remaining = maxf(_target_scan_remaining - delta, 0.0)
	_line_of_sight_remaining = maxf(_line_of_sight_remaining - delta, 0.0)

	var movement := entity.get_component(MovementComponent) as MovementComponent
	var alert := entity.get_component(AlertComponent) as AlertComponent
	var is_builder := alert != null and alert.role == AlertComponent.Role.BUILDER
	if _manual_move_active and (movement == null or not movement.is_moving()):
		_manual_move_active = false
	if target == null and not is_builder and not _manual_move_active and _attack_move_active and auto_target_mode == AutoTargetMode.ATTACK_MOVE and _target_scan_remaining <= 0.0:
		_target_scan_remaining = target_scan_interval
		_acquire_nearest_visible_target()
	if movement != null and movement.is_moving():
		# Attack parties may have a strategic building target, but they should
		# still react to hostile units they encounter on the way there.
		if not is_builder and target != null and target.grounded and _target_scan_remaining <= 0.0:
			_target_scan_remaining = target_scan_interval
			if _acquire_nearest_visible_unit():
				return
		if not _movement_blocked_last_frame:
			attack_stopped.emit("moving")
		_movement_blocked_last_frame = true
		return
	_movement_blocked_last_frame = false

	if target == null:
		return

	if not _is_valid_target():
		if target != null:
			_clear_target("target_invalid")
		return

	if not _has_line_of_sight():
		if movement != null and not movement.is_moving() and not _los_move_requested:
			_request_line_of_sight_position(movement)
		return
	_los_move_requested = false

	var distance := entity.global_position.distance_to(target.global_position)
	if distance > attack_range:
		attack_stopped.emit("target_out_of_range")
		return

	entity.set_facing_direction(entity.global_position.direction_to(target.global_position))
	if _cooldown <= 0.0:
		_fire()

func try_set_target_at(world_position: Vector2) -> bool:
	var best_target: Entity = null
	var best_distance := INF
	# Resolve the click around the cursor, rather than around the attacking unit.
	# The old query only inspected the leader's 28px neighborhood, so a right
	# click on any enemy farther away silently became a move order.
	for candidate in get_tree().get_nodes_in_group("entities"):
		if not candidate is Entity or candidate == entity or not is_instance_valid(candidate):
			continue
		var possible_target := candidate as Entity
		if not _is_opponent(possible_target) or possible_target.get_component(HealthComponent) == null:
			continue
		var click_radius := maxf(28.0, possible_target.collision_radius + 12.0)
		var distance := possible_target.global_position.distance_to(world_position)
		if distance <= click_radius and distance < best_distance:
			best_target = possible_target
			best_distance = distance

	if best_target == null:
		return false
	# An explicit attack replaces the previous order. Close distance when the
	# target is outside weapon range, then let combat take over on arrival.
	var movement := entity.get_component(MovementComponent) as MovementComponent
	set_target(best_target, false)
	if movement != null:
		if entity.global_position.distance_to(best_target.global_position) > attack_range:
			movement.move_to(best_target.global_position, attack_range)
		else:
			movement.stop()
	return true

func arm_attack_move() -> void:
	auto_target_mode = AutoTargetMode.ATTACK_MOVE
	_attack_move_active = true
	attack_move_armed = true
	if target == null:
		_clear_target("attack_move_ready")

func confirm_attack_move(destination: Vector2) -> void:
	if not attack_move_armed:
		return
	attack_move_armed = false
	# A new attack-move order always replaces the previous attack or move.
	if target != null:
		_clear_target("attack_move_order")
	_attack_move_active = true
	_manual_move_active = false
	# Resolve enemies already in range before issuing the travel order. This
	# makes attack-move visibly different from a manual right-click immediately,
	# instead of waiting for the next movement tick to discover the target.
	if _acquire_nearest_visible_target():
		return
	var movement := entity.get_component(MovementComponent) as MovementComponent
	if movement != null:
		movement.move_to(destination)

func cancel_attack_move(reason: String = "manual_move") -> void:
	attack_move_armed = false
	auto_target_mode = AutoTargetMode.ATTACK_MOVE
	_attack_move_active = true
	_clear_target(reason)

func begin_manual_move() -> void:
	# A right-click cancels Hold Position and restores ordinary auto-engagement.
	attack_move_armed = false
	auto_target_mode = AutoTargetMode.ATTACK_MOVE
	_attack_move_active = true
	_manual_move_active = true
	_clear_target("manual_move")

func set_target(new_target: Entity, stop_movement: bool = true) -> void:
	if not _is_opponent(new_target):
		return
	var movement := entity.get_component(MovementComponent) as MovementComponent
	if stop_movement and movement != null:
		movement.stop()
	target = new_target
	_target_scan_remaining = 0.0
	_line_of_sight_remaining = 0.0
	_cached_line_of_sight_target = null
	attack_move_armed = false
	_attack_move_active = auto_target_mode != AutoTargetMode.HOLD_POSITION
	_manual_move_active = false
	_cooldown = 0.0
	_los_move_requested = false
	target_changed.emit(target)

func clear_target(reason: String = "manual") -> void:
	_clear_target(reason)

func is_manual_move_active() -> bool:
	return _manual_move_active

func acquire_nearest_visible_unit() -> bool:
	return _acquire_nearest_visible_unit()

func acquire_nearest_visible_target() -> bool:
	return _acquire_nearest_visible_target()

func set_auto_target_mode(new_mode: int) -> void:
	auto_target_mode = new_mode
	if auto_target_mode == AutoTargetMode.HOLD_POSITION:
		attack_move_armed = false
		_attack_move_active = false
		var movement := entity.get_component(MovementComponent) as MovementComponent
		if movement != null:
			movement.stop()
		_clear_target("hold_position")
	else:
		_attack_move_active = true

func _acquire_nearest_visible_target() -> bool:
	var best_target: Entity = null
	var best_distance := INF
	for candidate in entity.get_nearby_entities(attack_range):
		if not candidate is Entity or candidate == entity:
			continue
		var possible_target := candidate as Entity
		if not _is_opponent(possible_target) or not is_instance_valid(possible_target.get_component(HealthComponent)):
			continue
		var distance := entity.global_position.distance_to(possible_target.global_position)
		if distance > attack_range or distance >= best_distance:
			continue
		if not _has_line_of_sight_to(possible_target):
			continue
		best_target = possible_target
		best_distance = distance

	if best_target != null:
		target = best_target
		var movement := entity.get_component(MovementComponent) as MovementComponent
		if movement != null:
			movement.stop()
		_cooldown = 0.0
		target_changed.emit(target)
		return true
	return false

func _acquire_nearest_visible_unit() -> bool:
	var best_target: Entity = null
	var best_distance := INF
	for candidate in entity.get_nearby_entities(attack_range):
		if not candidate is Entity or candidate == entity:
			continue
		var possible_target := candidate as Entity
		if possible_target.grounded or not _is_opponent(possible_target) or not is_instance_valid(possible_target.get_component(HealthComponent)):
			continue
		var distance := entity.global_position.distance_to(possible_target.global_position)
		if distance > attack_range or distance >= best_distance:
			continue
		if not _has_line_of_sight_to(possible_target):
			continue
		best_target = possible_target
		best_distance = distance

	if best_target == null:
		return false
	target = best_target
	var movement := entity.get_component(MovementComponent) as MovementComponent
	if movement != null:
		movement.stop()
	_cooldown = 0.0
	target_changed.emit(target)
	return true

func _fire() -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as Node2D
	if projectile == null:
		return
	projectile.global_position = entity.global_position + entity.facing_direction * 18.0
	projectile.set("direction", entity.facing_direction)
	projectile.set("speed", projectile_speed)
	projectile.set("damage", projectile_damage)
	projectile.set("collision_radius", projectile_radius)
	projectile.set("source", entity)
	projectile.set("target", target)
	get_tree().current_scene.add_child(projectile)
	_cooldown = fire_interval
	shot_fired.emit(projectile, target)

func _is_valid_target() -> bool:
	return is_instance_valid(target) and _is_opponent(target) and target.get_component(HealthComponent) != null

func _has_line_of_sight() -> bool:
	if _cached_line_of_sight_target != target or _line_of_sight_remaining <= 0.0:
		_cached_line_of_sight = _has_line_of_sight_to(target)
		_cached_line_of_sight_target = target
		_line_of_sight_remaining = line_of_sight_check_interval
	return _cached_line_of_sight

func _has_line_of_sight_to(candidate: Entity) -> bool:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	if maps.is_empty():
		return true
	return (maps[0] as TerrainMap).has_line_of_sight(
		entity.global_position,
		candidate.global_position,
		projectile_radius,
		[candidate.get_rid()]
	)

func _request_line_of_sight_position(movement: MovementComponent) -> void:
	_los_move_requested = true
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	if maps.is_empty():
		return
	var firing_position := (maps[0] as TerrainMap).find_closest_line_of_sight_position(
		entity.global_position,
		target.global_position,
		attack_range,
		movement.path_clearance,
		[target.get_rid()]
	)
	if firing_position.is_empty():
		attack_stopped.emit("no_line_of_sight_position")
		return
	movement.move_to(firing_position["position"])

func _is_opponent(candidate: Entity) -> bool:
	if candidate == null:
		return false
	var own_team := entity.get_component(TeamComponent) as TeamComponent
	var other_team := candidate.get_component(TeamComponent) as TeamComponent
	return own_team != null and other_team != null and own_team.team != other_team.team

func _clear_target(reason: String) -> void:
	target = null
	_cached_line_of_sight_target = null
	_line_of_sight_remaining = 0.0
	_los_move_requested = false
	attack_stopped.emit(reason)
