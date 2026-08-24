class_name EnemySpawnerBuilding
extends Entity

## Enemy structure that maintains a small, bounded group of attackers.

signal enemy_spawned(enemy: Entity)
signal building_destroyed

@export var enemy_scene: PackedScene
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
@export var under_construction := false
@export_range(16.0, 160.0, 1.0) var construction_presence_radius := 72.0
@export_range(0.0, 1.0, 0.01) var construction_progress := 0.0
@export_range(1.0, 10000.0, 1.0) var construction_max_health := 250.0
@export_range(32.0, 600.0, 1.0) var territory_radius := 180.0
@export_range(32.0, 800.0, 1.0) var defense_alert_radius := 320.0
@export_range(0.05, 1.0, 0.05) var defense_alert_cooldown := 0.25
@export var training_cost := 25
@export_range(1.0, 30.0, 0.5) var training_interval := 8.0

var _active_enemies: Array[Entity] = []
var _next_spawn_index := 0
var _destroyed := false
var _random := RandomNumberGenerator.new()
var _builder_spawned := false
var shared_territory_owner: Node2D
var _defense_alert_remaining := 0.0
var _training_remaining := 0.0
var _initial_spawn_complete := false
var _training_role := -1

func _ready() -> void:
	super._ready()
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
	if _active_enemies.size() >= max_active_enemies:
		_training_remaining = 0.0
		_training_role = -1
		return
	if _training_role < 0:
		_training_role = _choose_training_role()
		_training_remaining = training_interval
		queue_redraw()
	else:
		_training_remaining = maxf(_training_remaining - delta, 0.0)
		queue_redraw()
		if _training_remaining <= 0.0:
			if _spawn_enemy(_training_role):
				_training_role = -1
			else:
				# Keep the queued unit type visible, but avoid retrying every physics
				# frame while the faction is short on ore.
				_training_remaining = 1.0

func _spawn_initial_enemies() -> void:
	if not is_simulation_authority():
		return
	if under_construction:
		return
	for index in range(max_active_enemies):
		if initial_spawn_jitter <= 0.0:
			_spawn_enemy()
		else:
			var timer := get_tree().create_timer(_random.randf_range(0.0, initial_spawn_jitter), false)
			timer.timeout.connect(_spawn_enemy)
	_initial_spawn_complete = true

func _spawn_enemy(role_override: int = -1) -> bool:
	if not is_simulation_authority():
		return false
	if _destroyed or enemy_scene == null or _active_enemies.size() >= max_active_enemies:
		return false
	if not ResourceLedger.spend_ore(faction_team, training_cost):
		return false
	var enemy := enemy_scene.instantiate() as Entity
	if enemy == null:
		ResourceLedger.add_ore(faction_team, training_cost)
		return false
	var spawn_position: Variant = _find_spawn_position(enemy)
	if not spawn_position is Vector2:
		# Keep the ore reserved for the queued unit. The next training tick will
		# try again after the local area has become available.
		ResourceLedger.add_ore(faction_team, training_cost)
		enemy.queue_free()
		return false
	var spawn_index := _next_spawn_index
	var assigned_role := role_override if role_override >= 0 else _choose_training_role()
	if guarantee_builder and assigned_role == AlertComponent.Role.BUILDER:
		_builder_spawned = true
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = spawn_position as Vector2
	_next_spawn_index += 1
	enemy.set("display_name", AlertComponent.get_role_name(assigned_role))
	var faction_color := Color("e45b61") if faction_team == TeamComponent.Team.ENEMY else Color("63d8e2")
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
		wander.enabled = true
		var territory_owner: Node2D = shared_territory_owner if is_instance_valid(shared_territory_owner) else self
		wander.set_territory_owner(territory_owner, territory_radius)
	var alert := enemy.get_component(AlertComponent) as AlertComponent
	if alert != null:
		alert.enabled = true
		alert.set_role(assigned_role)
		enemy.queue_redraw()
	var health := enemy.get_component(HealthComponent) as HealthComponent
	if health != null:
		health.died.connect(_on_enemy_died.bind(enemy))
	_active_enemies.append(enemy)
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
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	return null if maps.is_empty() else maps[0] as TerrainMap

func _choose_training_role() -> int:
	var role := _next_spawn_index % 3
	if guarantee_builder and not _builder_spawned:
		return AlertComponent.Role.BUILDER
	if _random.randf() < builder_chance:
		return AlertComponent.Role.BUILDER
	return role

func _on_enemy_died(enemy: Entity) -> void:
	_active_enemies.erase(enemy)
	if guarantee_builder:
		var alert := enemy.get_component(AlertComponent) as AlertComponent
		if alert != null and alert.role == AlertComponent.Role.BUILDER:
			_builder_spawned = false
	if _destroyed:
		return
	var delay := maxf(0.1, respawn_delay + _random.randf_range(-respawn_jitter, respawn_jitter))
	_training_remaining = minf(_training_remaining, delay) if _training_remaining > 0.0 else delay
	if _training_role < 0:
		_training_role = _choose_training_role()

func _on_building_died() -> void:
	_destroyed = true
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
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

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
	max_active_enemies = maxi(unit_count, 1)
	_initial_spawn_complete = true
	_training_remaining = training_interval
	_training_role = _choose_training_role()
	queue_redraw()

func is_training() -> bool:
	return _initial_spawn_complete and not under_construction and _active_enemies.size() < max_active_enemies and _training_role >= 0

func get_training_progress() -> float:
	if not is_training():
		return 0.0
	return clampf(1.0 - _training_remaining / maxf(training_interval, 0.1), 0.0, 1.0)

func get_training_role_name() -> String:
	return "None" if _training_role < 0 else AlertComponent.get_role_name(_training_role)

func _draw() -> void:
	var faction_color := Color("e45b61") if faction_team == TeamComponent.Team.ENEMY else Color("63d8e2")
	if under_construction:
		faction_color = Color("e5b85b")
	draw_arc(Vector2.ZERO, territory_radius, 0.0, TAU, 64, Color(faction_color, 0.22), 2.0)
	draw_selection_ring(40.0, 3.0)
	draw_rect(Rect2(-30, -24, 60, 48), Color("293b46"), true)
	draw_rect(Rect2(-30, -24, 60, 48), faction_color, false, 3.0)
	draw_circle(Vector2.ZERO, 13.0, faction_color.darkened(0.35))
	draw_circle(Vector2.ZERO, 6.0, faction_color.lightened(0.3))
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
	var label := "Constructing" if under_construction else faction_name
	draw_string(ThemeDB.fallback_font, Vector2(-70, 48), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, faction_color.lightened(0.25))
