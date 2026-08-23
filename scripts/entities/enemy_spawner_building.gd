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
@export_range(32.0, 600.0, 1.0) var territory_radius := 180.0
@export_range(32.0, 800.0, 1.0) var defense_alert_radius := 320.0

var _active_enemies: Array[Entity] = []
var _next_spawn_index := 0
var _destroyed := false
var _random := RandomNumberGenerator.new()
var _builder_spawned := false
var shared_territory_owner: Node2D

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

func _spawn_enemy() -> void:
	if not is_simulation_authority():
		return
	if _destroyed or enemy_scene == null or _active_enemies.size() >= max_active_enemies:
		return
	var enemy := enemy_scene.instantiate() as Entity
	if enemy == null:
		return
	var spawn_index := _next_spawn_index
	var assigned_role := spawn_index % 3
	if guarantee_builder and not _builder_spawned:
		assigned_role = AlertComponent.Role.BUILDER
		_builder_spawned = true
	elif _random.randf() < builder_chance:
		assigned_role = AlertComponent.Role.BUILDER
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = global_position + spawn_positions[_next_spawn_index % spawn_positions.size()]
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

func _on_enemy_died(enemy: Entity) -> void:
	_active_enemies.erase(enemy)
	if guarantee_builder:
		var alert := enemy.get_component(AlertComponent) as AlertComponent
		if alert != null and alert.role == AlertComponent.Role.BUILDER:
			_builder_spawned = false
	if _destroyed:
		return
	var delay := maxf(0.1, respawn_delay + _random.randf_range(-respawn_jitter, respawn_jitter))
	var timer := get_tree().create_timer(delay, false)
	timer.timeout.connect(_spawn_enemy)

func _on_building_died() -> void:
	_destroyed = true
	_active_enemies.clear()
	building_destroyed.emit()

func _on_building_attacked(attacker: Entity) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	for candidate in get_tree().get_nodes_in_group("entities"):
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

func complete_construction(unit_count: int) -> void:
	if not under_construction or _destroyed:
		return
	under_construction = false
	max_active_enemies = maxi(unit_count, 1)
	call_deferred("_spawn_initial_enemies")

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
	var label := "Constructing" if under_construction else faction_name
	draw_string(ThemeDB.fallback_font, Vector2(-70, 48), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, faction_color.lightened(0.25))
