class_name EnemySpawnerBuilding
extends Entity

## Enemy structure that maintains a small, bounded group of attackers.

enum BuildingType { MAIN, BARRACKS, SUPPLY }

signal enemy_spawned(enemy: Entity)
signal building_destroyed

@export var enemy_scene: PackedScene
@export var initial_spawn_count := -1
@export var initial_spawn_role := -1
@export var initial_spawn_roles: Array[int] = []
@export var building_type := BuildingType.MAIN
@export_range(1, 10, 1) var supply_bonus := 3
@export var counts_as_starting_building := false
@export_range(0.4, 1.5, 0.05) var footprint_scale := 1.0
@export var display_name := "Enemy Spawner"
@export var faction_name := "Red Faction"
@export var faction_team: TeamComponent.Team = TeamComponent.Team.ENEMY
@export var spawn_positions := [
	Vector2(-52, -44),
	Vector2(52, -44),
	Vector2(-52, 40),
	Vector2(52, 40),
	Vector2(0, 72),
]
@export var max_active_enemies := 3
@export var respawn_delay := 4.0
@export_range(0.0, 10.0, 0.1) var respawn_jitter := 0.0
@export_range(0.0, 10.0, 0.1) var initial_spawn_jitter := 0.0
@export_range(0.0, 1.0, 0.01) var builder_chance := 0.0
@export var guarantee_builder := false
@export var autonomous := true
@export var auto_train := true
@export var under_construction := false
@export_range(16.0, 160.0, 1.0) var construction_presence_radius := 72.0
@export_range(0.0, 1.0, 0.01) var construction_progress := 0.0
@export_range(1.0, 10000.0, 1.0) var construction_max_health := 250.0
@export_range(32.0, 600.0, 1.0) var territory_radius := 180.0
@export_range(32.0, 800.0, 1.0) var defense_alert_radius := 320.0
@export_range(0.05, 1.0, 0.05) var defense_alert_cooldown := 0.25
@export var training_cost := 25
@export_range(1.0, 30.0, 0.5) var training_interval := 12.0
@export_range(1, 5, 1) var training_queue_limit := 5

var _active_enemies: Array[Entity] = []
var _next_spawn_index := 0
var _destroyed := false
var _random := RandomNumberGenerator.new()
var _builder_spawned := false
var shared_territory_owner: Node2D
var _defense_alert_remaining := 0.0
var _training_remaining := 0.0
var _training_retry_remaining := 0.0
var _training_start_retry_remaining := 0.0
var _training_waiting := false
var _training_reserved := false
var _initial_spawn_complete := false
var _training_role := -1
var _training_queue: Array[int] = []
var _training_rally_position: Variant = null

func _ready() -> void:
	super._ready()
	scale = Vector2.ONE * footprint_scale
	display_name = "Supply Depot" if is_supply_building() else ("Barracks" if building_type == BuildingType.BARRACKS else "Command Center")
	_random.randomize()
	add_to_group("territory_owners")
	var building_team := get_component(TeamComponent) as TeamComponent
	if building_team != null:
		building_team.team = faction_team
	var health := get_component(HealthComponent) as HealthComponent
	if health != null:
		health.died.connect(_on_building_died)
		health.attacked.connect(_on_building_attacked)
	call_deferred("_spawn_initial_enemies")
	queue_redraw()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_defense_alert_remaining = maxf(_defense_alert_remaining - delta, 0.0)
	if not is_simulation_authority() or _destroyed or under_construction or not _initial_spawn_complete:
		return
	if is_supply_building():
		return
	if _active_enemies.size() >= max_active_enemies and _training_role >= 0:
		# This can happen while delayed initial garrison spawns are still arriving.
		# If they filled the building before a queued unit finished, cancel that
		# queued training and return its reservation.
		_refund_training_reservations()
		_training_remaining = 0.0
		_training_role = -1
		_training_start_retry_remaining = 0.0
		_training_waiting = false
		return
	if _training_role < 0:
		if not auto_train:
			return
		if not _training_queue.is_empty():
			_start_next_training()
			return
		_training_start_retry_remaining = maxf(_training_start_retry_remaining - delta, 0.0)
		if _training_start_retry_remaining > 0.0:
			return
		var can_train := true
		var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
		if not sandboxes.is_empty() and sandboxes[0].has_method("can_start_unit_training"):
			can_train = bool(sandboxes[0].call("can_start_unit_training", self))
		if can_train and ResourceLedger.spend_ore(faction_team, training_cost):
			# Reserve the full cost before showing a training bar. The reservation
			# belongs to this building until the unit spawns or training is canceled.
			_training_role = _choose_training_role()
			_training_remaining = training_interval
			_training_retry_remaining = 0.0
			_training_waiting = false
			_training_reserved = true
			_training_queue.clear()
			_training_start_retry_remaining = 0.0
			queue_redraw()
		else:
			# No ore means no training order yet. Retry periodically without
			# repeatedly touching the faction balance every physics frame.
			_training_start_retry_remaining = 0.5
			return
	else:
		if not _training_waiting and _can_advance_training():
			_training_remaining = maxf(_training_remaining - delta, 0.0)
		elif _training_waiting or not _can_advance_training():
			_training_retry_remaining = maxf(_training_retry_remaining - delta, 0.0)
		queue_redraw()
		if _training_remaining <= 0.0 and (not _training_waiting or _training_retry_remaining <= 0.0):
			if _spawn_enemy(_training_role):
				_training_role = -1
				_training_remaining = 0.0
				_training_retry_remaining = 0.0
				_training_waiting = false
				_training_reserved = false
				_start_next_training()
			else:
				# The unit is finished but cannot enter the world yet (usually because
				# ore is unavailable or every local spawn point is occupied). Keep the
				# progress bar full and retry without making progress visibly jump back.
				_training_remaining = 0.0
				_training_retry_remaining = 1.0
				_training_waiting = true

func request_training(role_override: int) -> bool:
	if not is_simulation_authority() or _destroyed or under_construction or not _initial_spawn_complete:
		return false
	if not can_train_role(role_override):
		return false
	if _training_queue.size() + (1 if _training_role >= 0 else 0) >= training_queue_limit:
		return false
	if not ResourceLedger.spend_ore(faction_team, training_cost):
		return false
	_training_queue.append(role_override)
	if _training_role < 0:
		_start_next_training()
	queue_redraw()
	return true

func _start_next_training() -> void:
	if _training_role >= 0 or _training_queue.is_empty():
		return
	_training_role = _training_queue.pop_front()
	_training_remaining = training_interval
	_training_retry_remaining = 0.0
	_training_waiting = false
	_training_reserved = true
	_training_start_retry_remaining = 0.0
	queue_redraw()

func _can_advance_training() -> bool:
	var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
	if sandboxes.is_empty() or not sandboxes[0].has_method("can_advance_unit_training"):
		return true
	return bool(sandboxes[0].call("can_advance_unit_training", self))

func _spawn_initial_enemies() -> void:
	if not is_simulation_authority():
		return
	if under_construction:
		return
	var initial_count := max_active_enemies if initial_spawn_count < 0 else initial_spawn_count
	for index in range(initial_count):
		var role := initial_spawn_role
		if index < initial_spawn_roles.size():
			role = initial_spawn_roles[index]
		if initial_spawn_jitter <= 0.0:
			_spawn_initial_enemy(role)
		else:
			var timer := get_tree().create_timer(_random.randf_range(0.0, initial_spawn_jitter), false)
			timer.timeout.connect(_spawn_initial_enemy.bind(role))
	_initial_spawn_complete = true

func _spawn_initial_enemy(role_override: int = -1) -> void:
	if not ResourceLedger.spend_ore(faction_team, training_cost):
		return
	if not _spawn_enemy(role_override if role_override >= 0 else initial_spawn_role):
		# Initial units are an immediate garrison, so a failed placement should
		# not consume the faction's reserved cost.
		ResourceLedger.add_ore(faction_team, training_cost)

func _spawn_enemy(role_override: int = -1) -> bool:
	if not is_simulation_authority():
		return false
	if _destroyed or enemy_scene == null or _active_enemies.size() >= max_active_enemies:
		return false
	var enemy := enemy_scene.instantiate() as Entity
	if enemy == null:
		return false
	var spawn_position: Variant = _find_spawn_position(enemy)
	if not spawn_position is Vector2:
		# Keep the ore reserved for the queued unit. The next training tick will
		# try again after the local area has become available.
		enemy.queue_free()
		return false
	var spawn_index := _next_spawn_index
	var assigned_role := role_override if role_override >= 0 else _choose_training_role()
	if guarantee_builder and assigned_role == AlertComponent.Role.BUILDER:
		_builder_spawned = true
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = spawn_position as Vector2
	if not autonomous:
		enemy.owning_peer_id = NetworkSession.get_local_peer_id()
	_next_spawn_index += 1
	enemy.set("display_name", AlertComponent.get_role_name(assigned_role))
	var faction_color := _faction_color()
	var role_color := faction_color
	if assigned_role == AlertComponent.Role.GUARD:
		role_color = faction_color.darkened(0.22)
	elif assigned_role == AlertComponent.Role.FLANKER:
		role_color = faction_color.lightened(0.18)
	elif assigned_role == AlertComponent.Role.BUILDER:
		# Builders keep their faction ring/pennant, while the dark green body
		# makes their special role immediately readable in a crowded fight.
		role_color = Color("3f8f5f")
	enemy.set("body_color", role_color)
	enemy.collision_layer = 4
	enemy.collision_mask = 15
	var team := enemy.get_component(TeamComponent) as TeamComponent
	if team != null:
		team.team = faction_team
	var wander := enemy.get_component(WanderComponent) as WanderComponent
	if wander != null:
		wander.enabled = autonomous
		var territory_owner: Node2D = shared_territory_owner if is_instance_valid(shared_territory_owner) else self
		wander.set_territory_owner(territory_owner, territory_radius)
	var alert := enemy.get_component(AlertComponent) as AlertComponent
	if alert != null:
		alert.enabled = autonomous
		alert.set_role(assigned_role)
		enemy.queue_redraw()
	var harvest := enemy.get_component(HarvestComponent) as HarvestComponent
	var rally_is_ore := false
	if harvest != null:
		harvest.enabled = autonomous
		if not autonomous and assigned_role == AlertComponent.Role.BUILDER:
			var rally_vein := _rally_ore_vein()
			if rally_vein != null:
				rally_is_ore = true
				harvest.request_harvest(rally_vein)
	var combat := enemy.get_component(CombatComponent) as CombatComponent
	if combat != null and not autonomous:
		combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
	var health := enemy.get_component(HealthComponent) as HealthComponent
	if health != null:
		health.died.connect(_on_enemy_died.bind(enemy))
	_active_enemies.append(enemy)
	if _training_rally_position is Vector2 and not rally_is_ore:
		var rally_movement := enemy.get_component(MovementComponent) as MovementComponent
		if rally_movement != null:
			rally_movement.move_to(_training_rally_position as Vector2)
	enemy_spawned.emit(enemy)
	return true

func _find_spawn_position(unit: Entity) -> Variant:
	# Try the authored points first, then expand in a small ring around the
	# building. The search is intentionally capped so a blocked spawner never
	# teleports a new unit to a distant part of the map.
	var candidates: Array[Vector2] = []
	for offset_value in spawn_positions:
		if offset_value is Vector2:
			candidates.append(global_position + (offset_value as Vector2))
	for distance in [64.0, 80.0, 96.0, 112.0]:
		for direction_index in range(8):
			var angle := float(direction_index) * TAU / 8.0
			candidates.append(global_position + Vector2.RIGHT.rotated(angle) * distance)

	var terrain_map := _find_terrain_map()
	for candidate in candidates:
		if terrain_map != null:
			var candidate_cell := terrain_map.world_to_cell(candidate)
			if not terrain_map.is_inside(candidate_cell) or not terrain_map.is_traversable(terrain_map.get_tile(candidate_cell)):
				continue
		if _is_spawn_position_clear(candidate, unit.collision_radius + unit.collision_leeway):
			return candidate
	return null

func _is_spawn_position_clear(candidate: Vector2, clearance: float) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = clearance
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = 1 | (1 << 3) # Terrain plus solid structures.
	if not DeepProfiler.is_enabled():
		return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
	var started_usec := Time.get_ticks_usec()
	var is_clear := get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
	DeepProfiler.record_timing("physics_query.spawn_clearance", Time.get_ticks_usec() - started_usec, self)
	DeepProfiler.increment("physics_query.spawn_clearance_calls")
	return is_clear

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	return null if maps.is_empty() else maps[0] as TerrainMap

func _choose_training_role() -> int:
	if building_type == BuildingType.MAIN:
		return AlertComponent.Role.BUILDER
	if building_type == BuildingType.BARRACKS:
		return [AlertComponent.Role.GUARD, AlertComponent.Role.PURSUER, AlertComponent.Role.FLANKER][_next_spawn_index % 3]
	return -1

func _on_enemy_died(enemy: Entity) -> void:
	_active_enemies.erase(enemy)
	if guarantee_builder:
		var alert := enemy.get_component(AlertComponent) as AlertComponent
		if alert != null and alert.role == AlertComponent.Role.BUILDER:
			_builder_spawned = false
	if _destroyed:
		return
	var delay := maxf(0.1, respawn_delay + _random.randf_range(-respawn_jitter, respawn_jitter))
	if not _training_waiting:
		_training_remaining = minf(_training_remaining, delay) if _training_remaining > 0.0 else delay
	_training_retry_remaining = 0.0
	# Leave an empty queue for the next physics tick to reserve ore before
	# selecting and displaying the next unit.
	if _training_role < 0:
		_training_waiting = false

func _on_building_died() -> void:
	_destroyed = true
	_refund_training_reservations()
	_training_role = -1
	_training_queue.clear()
	_training_remaining = 0.0
	_training_waiting = false
	_active_enemies.clear()
	building_destroyed.emit()

func _on_building_attacked(attacker: Entity) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	if _defense_alert_remaining > 0.0:
		return
	_defense_alert_remaining = defense_alert_cooldown
	for candidate in get_nearby_entities(defense_alert_radius):
		if candidate == self or not candidate is Entity:
			continue
		var defender := candidate as Entity
		if shared_territory_owner != null and shared_territory_owner.has_method("contains_position"):
			if not shared_territory_owner.contains_position(defender.global_position):
				continue
		elif global_position.distance_to(defender.global_position) > defense_alert_radius:
			continue
		if not is_teammate(defender):
			continue
		var alert := defender.get_component(AlertComponent) as AlertComponent
		if alert != null:
			# This is an audible/territorial alert; LOS to the building is not
			# required for defenders to react. Send them to a safe perimeter point
			# so a hidden attacker does not make them path into the structure.
			alert._respond_to_alert(attacker, get_defense_position(defender.global_position))

func can_wander_to(from_position: Vector2, destination: Vector2, clearance: float) -> bool:
	# TerrainMap navigation does not include this dynamic structure. Reject a
	# direct wander route that would cut through the spawner's collision body.
	var query := PhysicsRayQueryParameters2D.create(from_position, destination)
	query.collision_mask = 1 << 3 # Structures (layer 4)
	if not DeepProfiler.is_enabled():
		return get_world_2d().direct_space_state.intersect_ray(query).is_empty()
	var started_usec := Time.get_ticks_usec()
	var is_clear := get_world_2d().direct_space_state.intersect_ray(query).is_empty()
	DeepProfiler.record_timing("physics_query.structure_ray", Time.get_ticks_usec() - started_usec, self)
	DeepProfiler.increment("physics_query.structure_ray_calls")
	return is_clear

func get_wander_return_position(from_position: Vector2) -> Vector2:
	# The building center is inside its collision rectangle. Use the nearest
	# spawn point so returning enemies have a reachable home position. Prefer
	# points whose direct approach does not cross the building itself.
	var best_position := global_position + Vector2(0.0, 48.0)
	var best_distance := INF
	for spawn_position in spawn_positions:
		var candidate: Vector2 = global_position + (spawn_position as Vector2)
		if not can_wander_to(from_position, candidate, 12.0):
			continue
		var distance := from_position.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best_position = candidate
	if best_distance == INF:
		# A defender may already be inside the structure's broad alert radius.
		# Fall back to the closest spawn point rather than returning its center.
		for spawn_position in spawn_positions:
			var candidate: Vector2 = global_position + (spawn_position as Vector2)
			var distance := from_position.distance_squared_to(candidate)
			if distance < best_distance:
				best_distance = distance
				best_position = candidate
	return best_position

func get_building_approach_position(from_position: Vector2) -> Vector2:
	# The building center is inside its solid body. Prefer a reachable perimeter
	# point, especially when a rock or wall makes the nearest side unreachable.
	var profiling := DeepProfiler.is_enabled()
	var started_usec := Time.get_ticks_usec() if profiling else 0
	var candidates: Array[Vector2] = []
	for offset in [
		Vector2(-52.0, -44.0), Vector2(0.0, -48.0), Vector2(52.0, -44.0),
		Vector2(-56.0, 0.0), Vector2(56.0, 0.0),
		Vector2(-52.0, 44.0), Vector2(0.0, 48.0), Vector2(52.0, 44.0)
	]:
		candidates.append(global_position + offset)
	var terrain_map := _find_terrain_map()
	var best_position := get_wander_return_position(from_position)
	var best_distance := INF
	for candidate in candidates:
		if terrain_map != null:
			var path := terrain_map.find_path(from_position, candidate, 14.0, null, &"building_approach")
			if path.is_empty():
				continue
		if not _is_spawn_position_clear(candidate, 14.0):
			continue
		var distance := from_position.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best_position = candidate
	if profiling:
		DeepProfiler.record_timing("navigation.building_approach", Time.get_ticks_usec() - started_usec, self)
		DeepProfiler.increment("navigation.building_approach_calls")
	return best_position

func get_defense_position(from_position: Vector2) -> Vector2:
	# Attackers can damage the building from outside its collision body. Give
	# defenders a perimeter position to move toward, never the building center.
	return get_wander_return_position(from_position)

func get_active_enemies() -> Array[Entity]:
	var active: Array[Entity] = []
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			active.append(enemy)
	return active

func set_shared_territory_owner(owner: Node2D) -> void:
	shared_territory_owner = owner

func contains_territory_position(position: Vector2) -> bool:
	if is_instance_valid(shared_territory_owner) and shared_territory_owner.has_method("contains_position"):
		return bool(shared_territory_owner.call("contains_position", position))
	return global_position.distance_to(position) <= territory_radius

func set_construction_progress(value: float) -> void:
	construction_progress = clampf(value, 0.0, 1.0)
	var health := get_component(HealthComponent) as HealthComponent
	if health != null and under_construction:
		var damage_taken := maxf(health.maximum_health - health.current_health, 0.0)
		var next_maximum := lerpf(1.0, construction_max_health, construction_progress)
		health.maximum_health = next_maximum
		health.current_health = maxf(next_maximum - damage_taken, 0.0)
		health.health_changed.emit(health.current_health, health.maximum_health)
	queue_redraw()

func complete_construction(unit_count: int) -> void:
	if not under_construction or _destroyed:
		return
	set_construction_progress(1.0)
	under_construction = false
	max_active_enemies = 0 if is_supply_building() else maxi(unit_count, 1)
	_initial_spawn_complete = true
	_training_remaining = 0.0
	_training_retry_remaining = 0.0
	_training_start_retry_remaining = 0.0
	_training_waiting = false
	_training_role = -1
	queue_redraw()

func cancel_training() -> bool:
	if not is_simulation_authority() or not _training_reserved:
		return false
	_refund_training_reservations()
	_training_role = -1
	_training_queue.clear()
	_training_remaining = 0.0
	_training_retry_remaining = 0.0
	_training_start_retry_remaining = 0.0
	_training_waiting = false
	queue_redraw()
	return true

func _refund_training_reservation() -> void:
	if not _training_reserved:
		return
	ResourceLedger.add_ore(faction_team, training_cost)
	_training_reserved = false

func _refund_training_reservations() -> void:
	var reserved_count := _training_queue.size() + (1 if _training_reserved else 0)
	if reserved_count > 0:
		ResourceLedger.add_ore(faction_team, reserved_count * training_cost)
	_training_queue.clear()
	_training_reserved = false

func is_training() -> bool:
	return _initial_spawn_complete and not under_construction and _active_enemies.size() < max_active_enemies and _training_role >= 0 and _training_reserved

func is_supply_building() -> bool:
	return building_type == BuildingType.SUPPLY

func is_main_building() -> bool:
	return building_type == BuildingType.MAIN

func set_training_rally_point(position: Vector2) -> void:
	if not is_simulation_authority():
		return
	_training_rally_position = position
	queue_redraw()

func get_training_rally_position() -> Variant:
	return _training_rally_position

func can_train_role(role: int) -> bool:
	if building_type == BuildingType.BARRACKS:
		return role == AlertComponent.Role.GUARD or role == AlertComponent.Role.PURSUER or role == AlertComponent.Role.FLANKER
	if building_type == BuildingType.MAIN:
		return role == AlertComponent.Role.BUILDER
	return false

func _rally_ore_vein() -> OreVein:
	if not _training_rally_position is Vector2:
		return null
	var closest: OreVein
	var closest_distance := 40.0
	for candidate in get_tree().get_nodes_in_group("ore_veins"):
		if not candidate is OreVein or not is_instance_valid(candidate):
			continue
		var vein := candidate as OreVein
		if vein.ore <= 1.0:
			continue
		var distance := vein.global_position.distance_to(_training_rally_position as Vector2)
		if distance <= closest_distance:
			closest_distance = distance
			closest = vein
	return closest

func get_training_progress() -> float:
	if not is_training():
		return 0.0
	if _training_waiting:
		return 1.0
	return clampf(1.0 - _training_remaining / maxf(training_interval, 0.1), 0.0, 1.0)

func is_training_supply_blocked() -> bool:
	return is_training() and not _can_advance_training()

func get_training_role_name() -> String:
	return "None" if _training_role < 0 else AlertComponent.get_role_name(_training_role)

func get_training_queue_count() -> int:
	return _training_queue.size() + (1 if _training_role >= 0 else 0)

func get_training_queue_limit() -> int:
	return training_queue_limit

func _draw() -> void:
	var faction_color := _faction_color()
	if is_supply_building():
		faction_color = faction_color.lightened(0.12)
	elif building_type == BuildingType.BARRACKS:
		faction_color = faction_color.darkened(0.08)
	if under_construction:
		faction_color = Color("e5b85b")
	draw_arc(Vector2.ZERO, territory_radius, 0.0, TAU, 64, Color(faction_color, 0.22), 2.0)
	draw_selection_ring(40.0, 3.0)
	draw_rect(Rect2(-30, -24, 60, 48), Color("293b46"), true)
	draw_rect(Rect2(-30, -24, 60, 48), faction_color, false, 3.0)
	draw_circle(Vector2.ZERO, 13.0, faction_color.darkened(0.35))
	draw_circle(Vector2.ZERO, 6.0, faction_color.lightened(0.3))
	if is_supply_building():
		# Compact crate-like mark distinguishes capacity buildings from production
		# structures even when the world label is not readable.
		draw_rect(Rect2(-12.0, -8.0, 24.0, 16.0), faction_color.darkened(0.35), true)
		draw_line(Vector2(-12.0, 0.0), Vector2(12.0, 0.0), faction_color.lightened(0.25), 2.0)
		draw_line(Vector2.ZERO, Vector2(0.0, 8.0), faction_color.lightened(0.25), 2.0)
	elif building_type == BuildingType.BARRACKS:
		# Simple doorway mark for combat production buildings.
		draw_rect(Rect2(-7.0, -10.0, 14.0, 20.0), faction_color.darkened(0.35), true)
	if under_construction:
		var progress_bar := Rect2(-30.0, -38.0, 60.0, 6.0)
		draw_rect(progress_bar, Color("17242b"), true)
		draw_rect(Rect2(progress_bar.position, Vector2(progress_bar.size.x * construction_progress, progress_bar.size.y)), Color("f4d58b"), true)
		draw_rect(progress_bar, Color("f4d58b"), false, 1.0)
	elif is_training():
		var training_bar := Rect2(-30.0, -38.0, 60.0, 6.0)
		draw_rect(training_bar, Color("17242b"), true)
		draw_rect(Rect2(training_bar.position, Vector2(training_bar.size.x * get_training_progress(), training_bar.size.y)), Color("7fb6df"), true)
		draw_rect(training_bar, Color("7fb6df"), false, 1.0)
	if is_selected and _training_rally_position is Vector2:
		var rally_local := to_local(_training_rally_position as Vector2)
		draw_line(Vector2.ZERO, rally_local, Color("f4d58b", 0.35), 1.0)
		draw_line(rally_local, rally_local + Vector2(0.0, -16.0), Color("f4d58b"), 2.0)
		var flag_points := PackedVector2Array([
			rally_local + Vector2(0.0, -16.0),
			rally_local + Vector2(15.0, -11.0),
			rally_local + Vector2(0.0, -7.0),
		])
		draw_colored_polygon(flag_points, Color("f4d58b", 0.9))
	var label := "Constructing" if under_construction else ("Supply Depot" if is_supply_building() else ("Barracks" if building_type == BuildingType.BARRACKS else "Command Center"))
	draw_string(ThemeDB.fallback_font, Vector2(-70, 48), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, faction_color.lightened(0.25))

func _faction_color() -> Color:
	match faction_team:
		TeamComponent.Team.ENEMY:
			return Color("e45b61")
		TeamComponent.Team.PLAYER:
			return Color("5ee27a")
		_:
			return Color("63d8e2")
