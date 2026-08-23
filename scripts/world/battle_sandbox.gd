class_name BattleSandbox
extends Node2D

const FACTION_TERRITORY_SCRIPT = preload("res://scripts/world/faction_territory.gd")

## Autonomous two-faction combat harness. This is intentionally a sandbox
## coordinator, not a replacement for mission logic: it periodically issues
## attack-move orders while each building's AlertComponent remains responsible
## for local defense and returning units home.

@export var building_scene: PackedScene
@export var units_per_building := [3, 4, 5]
@export_range(2.0, 30.0, 0.5) var wave_interval := 8.0
@export_range(32.0, 300.0, 1.0) var attack_standoff := 160.0
@export_range(100.0, 10000.0, 100.0) var building_health := 5000.0
@export_range(0.0, 300.0, 5.0) var building_repair_per_second := 100.0
@export_range(8.0, 60.0, 1.0) var expansion_check_interval := 18.0
@export_range(0.0, 1.0, 0.05) var expansion_chance := 0.5
@export_range(4.0, 30.0, 1.0) var construction_duration := 10.0
@export_range(7.0, 16.0, 1.0) var expansion_min_distance_tiles := 8.0
@export_range(2.0, 10.0, 1.0) var expansion_spacing_tiles := 4.0
@export_range(5.0, 120.0, 5.0) var builder_expansion_cooldown := 45.0

var _factions: Array[Dictionary] = []
var _wave_remaining: Array[float] = []
var _random := RandomNumberGenerator.new()
var _expansions: Array[Dictionary] = []
var _builder_cooldowns: Dictionary = {}
var _attack_targets: Dictionary = {}

func _ready() -> void:
	if not NetworkSession.is_simulation_authority():
		return
	_random.randomize()
	_create_faction(
		"Red Faction",
		TeamComponent.Team.ENEMY,
		[Vector2(-650.0, -220.0), Vector2(-650.0, 0.0), Vector2(-650.0, 220.0)]
	)
	_create_faction(
		"Blue Faction",
		TeamComponent.Team.ALLY,
		[Vector2(650.0, -220.0), Vector2(650.0, 0.0), Vector2(650.0, 220.0)]
	)

func _physics_process(delta: float) -> void:
	if not NetworkSession.is_simulation_authority() or _factions.size() < 2:
		return
	for builder_id in _builder_cooldowns.keys():
		_builder_cooldowns[builder_id] = maxf(float(_builder_cooldowns[builder_id]) - delta, 0.0)
	for faction in _factions:
		for building_value in faction["buildings"]:
			var building := building_value as EnemySpawnerBuilding
			if not is_instance_valid(building):
				continue
			var health := building.get_component(HealthComponent) as HealthComponent
			if health != null:
				health.heal(building_repair_per_second * delta)
	for faction_index in range(_factions.size()):
		_wave_remaining[faction_index] -= delta
		if _wave_remaining[faction_index] <= 0.0:
			_launch_wave(faction_index)
			_wave_remaining[faction_index] = _random_wave_delay()
		var faction: Dictionary = _factions[faction_index]
		faction["expansion_remaining"] -= delta
		if faction["expansion_remaining"] <= 0.0:
			faction["expansion_remaining"] = _random_expansion_delay()
			if _random.randf() <= expansion_chance:
				_try_start_expansion(faction_index)
	_update_war_states()
	_update_expansions(delta)
	_maintain_attack_parties()

func _create_faction(label: String, team: TeamComponent.Team, positions: Array[Vector2]) -> void:
	var faction_buildings: Array[EnemySpawnerBuilding] = []
	var territory: Node2D = FACTION_TERRITORY_SCRIPT.new()
	territory.set("faction_team", team)
	add_child(territory)
	for index in range(positions.size()):
		var building := building_scene.instantiate() as EnemySpawnerBuilding
		if building == null:
			continue
		building.faction_name = label
		building.faction_team = team
		building.max_active_enemies = units_per_building[index % units_per_building.size()]
		building.territory_radius = 180.0
		building.defense_alert_radius = 300.0
		building.respawn_delay = 5.0
		building.respawn_jitter = 2.0
		building.initial_spawn_jitter = 2.5
		building.builder_chance = 0.08
		building.guarantee_builder = index == 0
		add_child(building)
		building.global_position = positions[index]
		building.set_shared_territory_owner(territory)
		territory.call("add_building", building)
		var health := building.get_component(HealthComponent) as HealthComponent
		if health != null:
			health.maximum_health = building_health
			health.current_health = building_health
		building.enemy_spawned.connect(_on_enemy_spawned.bind(building))
		faction_buildings.append(building)
	_factions.append({
		"label": label,
		"team": team,
		"buildings": faction_buildings,
		"territory": territory,
		"origin": positions[0],
		"at_war": false,
		"expansion_remaining": _random_expansion_delay(),
	})
	_wave_remaining.append(_random_wave_delay())

func _launch_waves() -> void:
	for faction_index in range(_factions.size()):
		_launch_wave(faction_index)

func _launch_wave(faction_index: int) -> void:
	if faction_index < 0 or faction_index >= _factions.size() or _factions.size() < 2:
		return
	var faction: Dictionary = _factions[faction_index]
	if not faction["at_war"]:
		return
	var enemy_index := (faction_index + 1) % _factions.size()
	var enemy_faction: Dictionary = _factions[enemy_index]
	var enemy_buildings: Array = enemy_faction["buildings"]
	if enemy_buildings.is_empty():
		return
	var target := enemy_buildings[_random.randi_range(0, enemy_buildings.size() - 1)] as EnemySpawnerBuilding
	if not is_instance_valid(target):
		return
	for building_value in faction["buildings"]:
		var building := building_value as EnemySpawnerBuilding
		if not is_instance_valid(building):
			continue
		for unit in building.get_active_enemies():
			# A few units may stay home, creating uneven pushes and leaving
			# believable defenders behind without a second AI implementation.
			if _is_reserved_for_expansion(unit):
				continue
			if _random.randf() <= 0.82:
				_issue_attack_order(unit, target)

func _issue_attack_order(unit: Entity, target: EnemySpawnerBuilding) -> void:
	if not is_instance_valid(unit) or not is_instance_valid(target):
		return
	var alert := unit.get_component(AlertComponent) as AlertComponent
	if alert != null and alert.state != AlertComponent.State.IDLE:
		return
	var movement := unit.get_component(MovementComponent) as MovementComponent
	var combat := unit.get_component(CombatComponent) as CombatComponent
	if movement == null or combat == null:
		return
	combat.set_auto_target_mode(CombatComponent.AUTO_ATTACK_MOVE)
	var approach := target.global_position - unit.global_position
	if approach.length_squared() <= 1.0:
		approach = Vector2.RIGHT
	var destination := target.global_position - approach.normalized() * _randomize_standoff()
	movement.move_to(destination)
	# Keep the building as the attack target while the unit advances. The
	# previous behavior let auto-targeting choose nearby defenders first.
	combat.set_target(target, false)
	_attack_targets[unit.get_instance_id()] = target

func _maintain_attack_parties() -> void:
	for unit_id in _attack_targets.keys():
		var unit := NetworkSession.get_entity(unit_id) as Entity
		var target := _attack_targets[unit_id] as EnemySpawnerBuilding
		if not is_instance_valid(unit) or not is_instance_valid(target):
			_attack_targets.erase(unit_id)
			continue
		var alert := unit.get_component(AlertComponent) as AlertComponent
		var combat := unit.get_component(CombatComponent) as CombatComponent
		var movement := unit.get_component(MovementComponent) as MovementComponent
		if alert == null or combat == null or movement == null or alert.state != AlertComponent.State.IDLE:
			continue
		# If an interception killed or invalidated the temporary unit target,
		# resume the strategic building objective once the unit is idle again.
		if combat.target == null and not movement.is_moving():
			_issue_attack_order(unit, target)

func _random_wave_delay() -> float:
	return wave_interval * _random.randf_range(0.65, 1.4)

func _randomize_standoff() -> float:
	return attack_standoff * _random.randf_range(0.85, 1.15)

func _random_expansion_delay() -> float:
	return expansion_check_interval * _random.randf_range(0.7, 1.5)

func _try_start_expansion(faction_index: int) -> void:
	if faction_index < 0 or faction_index >= _factions.size():
		return
	for expansion in _expansions:
		if expansion["faction_index"] == faction_index:
			return
	var faction: Dictionary = _factions[faction_index]
	var builders := _find_available_builders(faction)
	if builders.is_empty():
		return
	var builder := builders[_random.randi_range(0, builders.size() - 1)] as Entity
	var position: Variant = _find_expansion_position(faction, builder)
	if position == null:
		return
	var escorts := _find_expansion_escorts(faction, builder)
	var expansion := {
		"faction_index": faction_index,
		"builder": builder,
		"escorts": escorts,
		"position": position,
		"site": null,
		"remaining": -1.0,
	}
	_expansions.append(expansion)
	_issue_move_to_position(builder, position as Vector2)
	for escort in escorts:
		_issue_move_to_position(escort, position as Vector2)

func _find_available_builders(faction: Dictionary) -> Array[Entity]:
	var builders: Array[Entity] = []
	for building_value in faction["buildings"]:
		var building := building_value as EnemySpawnerBuilding
		if not is_instance_valid(building) or building.under_construction:
			continue
		for unit in building.get_active_enemies():
			var alert := unit.get_component(AlertComponent) as AlertComponent
			var cooldown := float(_builder_cooldowns.get(unit.get_instance_id(), 0.0))
			if alert != null and alert.role == AlertComponent.Role.BUILDER and alert.state == AlertComponent.State.IDLE and cooldown <= 0.0 and not _is_reserved_for_expansion(unit):
				builders.append(unit)
	return builders

func _find_expansion_escorts(faction: Dictionary, builder: Entity) -> Array[Entity]:
	var candidates: Array[Entity] = []
	for building_value in faction["buildings"]:
		var building := building_value as EnemySpawnerBuilding
		if not is_instance_valid(building):
			continue
		for unit in building.get_active_enemies():
			if unit == builder or _is_reserved_for_expansion(unit):
				continue
			var alert := unit.get_component(AlertComponent) as AlertComponent
			if alert == null or alert.state != AlertComponent.State.IDLE:
				continue
			candidates.append(unit)
	var escorts: Array[Entity] = []
	for index in range(mini(2, candidates.size())):
		escorts.append(candidates[index])
	return escorts

func _find_expansion_position(faction: Dictionary, builder: Entity) -> Variant:
	var team: TeamComponent.Team = faction["team"]
	var direction := Vector2.RIGHT if team == TeamComponent.Team.ENEMY else Vector2.LEFT
	var terrain_map := _find_terrain_map()
	var tile_size := terrain_map.tile_size if terrain_map != null else 64.0
	var minimum_distance := expansion_min_distance_tiles * tile_size
	var spacing_distance := expansion_spacing_tiles * tile_size
	var origin: Vector2 = faction["origin"]
	for attempt in range(10):
		var distance := _random.randf_range(minimum_distance + 24.0, minimum_distance + 220.0)
		var candidate := builder.global_position + direction * distance + Vector2(0.0, _random.randf_range(-220.0, 220.0))
		if candidate.distance_to(origin) < minimum_distance:
			continue
		if terrain_map != null:
			var candidate_cell := terrain_map.world_to_cell(candidate)
			if not terrain_map.is_inside(candidate_cell) or not terrain_map.is_traversable(terrain_map.get_tile(candidate_cell)):
				continue
			if terrain_map.find_path(builder.global_position, candidate, 20.0).is_empty() or not _is_clear_spawner_site(terrain_map, candidate):
				continue
		var too_close := false
		for building_value in faction["buildings"]:
			var building := building_value as EnemySpawnerBuilding
			if is_instance_valid(building) and building.global_position.distance_to(candidate) < spacing_distance:
				too_close = true
				break
		if not too_close:
			return candidate
	return null

func _is_clear_spawner_site(terrain_map: TerrainMap, center: Vector2) -> bool:
	# A spawner is wider than one navigation cell. Check its footprint corners
	# so a valid path point cannot place the building partly inside stone.
	for offset in [Vector2(-30.0, -24.0), Vector2(30.0, -24.0), Vector2(-30.0, 24.0), Vector2(30.0, 24.0)]:
		var cell := terrain_map.world_to_cell(center + offset)
		if not terrain_map.is_inside(cell) or not terrain_map.is_traversable(terrain_map.get_tile(cell)):
			return false
	return true

func _issue_move_to_position(unit: Entity, position: Vector2) -> void:
	var movement := unit.get_component(MovementComponent) as MovementComponent
	var combat := unit.get_component(CombatComponent) as CombatComponent
	if movement == null or combat == null:
		return
	combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
	movement.move_to(position)

func _update_expansions(delta: float) -> void:
	for index in range(_expansions.size() - 1, -1, -1):
		var expansion: Dictionary = _expansions[index]
		var builder := expansion["builder"] as Entity
		if not is_instance_valid(builder):
			_cancel_expansion(index)
			continue
		var alert := builder.get_component(AlertComponent) as AlertComponent
		if alert != null and alert.state != AlertComponent.State.IDLE:
			_cancel_expansion(index)
			continue
		var site_value: Variant = expansion["site"]
		if site_value == null:
			var position: Vector2 = expansion["position"]
			var movement := builder.get_component(MovementComponent) as MovementComponent
			if movement != null and not movement.is_moving() and builder.global_position.distance_to(position) <= 48.0:
				expansion["site"] = _create_construction_site(expansion["faction_index"], position)
				expansion["remaining"] = construction_duration
				_builder_cooldowns[builder.get_instance_id()] = builder_expansion_cooldown
				var combat := builder.get_component(CombatComponent) as CombatComponent
				if combat != null:
					combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
		else:
			var site := site_value as EnemySpawnerBuilding
			if not is_instance_valid(site):
				_expansions.remove_at(index)
				continue
			expansion["remaining"] -= delta
			if expansion["remaining"] <= 0.0:
				site.complete_construction(_random.randi_range(2, 5))
				_expansions.remove_at(index)

func _create_construction_site(faction_index: int, position: Vector2) -> EnemySpawnerBuilding:
	var faction: Dictionary = _factions[faction_index]
	var site := building_scene.instantiate() as EnemySpawnerBuilding
	if site == null:
		return null
	site.faction_name = faction["label"]
	site.faction_team = faction["team"]
	site.max_active_enemies = 0
	site.builder_chance = 0.08
	site.under_construction = true
	var territory := faction["territory"] as Node2D
	site.set_shared_territory_owner(territory)
	site.respawn_delay = 5.0
	site.respawn_jitter = 2.0
	add_child(site)
	site.global_position = position
	var health := site.get_component(HealthComponent) as HealthComponent
	if health != null:
		health.maximum_health = building_health * 0.35
		health.current_health = health.maximum_health
	site.enemy_spawned.connect(_on_enemy_spawned.bind(site))
	var buildings: Array = faction["buildings"]
	buildings.append(site)
	territory.call("add_building", site)
	return site

func _cancel_expansion(index: int) -> void:
	var site_value: Variant = _expansions[index]["site"]
	if site_value is EnemySpawnerBuilding and is_instance_valid(site_value):
		(site_value as EnemySpawnerBuilding).queue_free()
	_expansions.remove_at(index)

func _is_reserved_for_expansion(unit: Entity) -> bool:
	for expansion in _expansions:
		if expansion["builder"] == unit:
			return true
		for escort in expansion["escorts"]:
			if escort == unit:
				return true
	return false

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	return null if maps.is_empty() else maps[0] as TerrainMap

func _update_war_states() -> void:
	for faction_index in range(_factions.size()):
		var faction: Dictionary = _factions[faction_index]
		if faction["at_war"] or not _faction_has_enemy_building_in_territory(faction_index):
			continue
		faction["at_war"] = true
		print("Battle sandbox: %s declares war" % faction["label"])

func _faction_has_enemy_building_in_territory(faction_index: int) -> bool:
		if faction_index < 0 or faction_index >= _factions.size():
			return false
		var faction: Dictionary = _factions[faction_index]
		for own_value in faction["buildings"]:
			var own_building := own_value as EnemySpawnerBuilding
			if not is_instance_valid(own_building):
				continue
			for other_index in range(_factions.size()):
				if other_index == faction_index:
					continue
				var other_faction: Dictionary = _factions[other_index]
				for other_value in other_faction["buildings"]:
					var other_building := other_value as EnemySpawnerBuilding
					if is_instance_valid(other_building) and own_building.global_position.distance_to(other_building.global_position) <= own_building.territory_radius:
						return true
		return false

func _on_enemy_spawned(unit: Entity, _building: EnemySpawnerBuilding) -> void:
	# Newly respawned units join the next scheduled wave. This keeps spawning
	# deterministic and avoids every death causing an immediate dogpile order.
	if unit != null:
		unit.queue_redraw()
