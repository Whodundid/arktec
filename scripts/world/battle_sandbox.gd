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
@export_range(100.0, 10000.0, 25.0) var building_health := 250.0
@export_range(0.0, 300.0, 5.0) var building_repair_per_second := 10.0
@export_range(8.0, 120.0, 1.0) var expansion_check_interval := 18.0
@export_range(0.0, 1.0, 0.05) var expansion_chance := 0.8
@export_range(0.1, 1.0, 0.05) var expansion_min_delay_factor := 0.35
@export_range(1.0, 5.0, 0.05) var expansion_max_delay_factor := 2.75
@export_range(0.0, 60.0, 1.0) var expansion_min_faction_spacing := 8.0
@export_range(4.0, 30.0, 1.0) var construction_duration := 10.0
@export_range(7.0, 16.0, 1.0) var expansion_min_distance_tiles := 8.0
@export_range(2.0, 10.0, 1.0) var expansion_spacing_tiles := 4.0
@export_range(5.0, 120.0, 5.0) var builder_expansion_cooldown := 45.0
@export_range(0, 8, 1) var max_builders_per_faction := 2

var _factions: Array[Dictionary] = []
var _wave_remaining: Array[float] = []
var _random := RandomNumberGenerator.new()
var _expansions: Array[Dictionary] = []
var _builder_cooldowns: Dictionary = {}
var _attack_targets: Dictionary = {}
var _expansion_spacing_remaining := 0.0

func _ready() -> void:
	if not NetworkSession.is_simulation_authority():
		return
	_random.randomize()
	_create_faction(
		"Red Faction",
		TeamComponent.Team.ENEMY,
		[Vector2(-650.0, -220.0), Vector2(-750.0, 0.0), Vector2(-650.0, 220.0)]
	)
	_create_faction(
		"Blue Faction",
		TeamComponent.Team.ALLY,
		[Vector2(650.0, -220.0), Vector2(750.0, 0.0), Vector2(650.0, 220.0)]
	)

func _physics_process(delta: float) -> void:
	if not NetworkSession.is_simulation_authority() or _factions.size() < 2:
		return
	_prune_faction_buildings()
	_enforce_all_builder_caps()
	for builder_id in _builder_cooldowns.keys():
		_builder_cooldowns[builder_id] = maxf(float(_builder_cooldowns[builder_id]) - delta, 0.0)
	_expansion_spacing_remaining = maxf(_expansion_spacing_remaining - delta, 0.0)
	for faction in _factions:
		for building_value in faction["buildings"]:
			if building_value == null or not is_instance_valid(building_value) or not building_value is EnemySpawnerBuilding:
				continue
			var building := building_value as EnemySpawnerBuilding
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
	var faction_buildings: Array = []
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

func _prune_faction_buildings() -> void:
	for faction in _factions:
		var live_buildings: Array = []
		for building_value in faction["buildings"]:
			if is_instance_valid(building_value):
				live_buildings.append(building_value)
		faction["buildings"] = live_buildings

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
	return expansion_check_interval * _random.randf_range(expansion_min_delay_factor, expansion_max_delay_factor)

func _try_start_expansion(faction_index: int) -> void:
	if faction_index < 0 or faction_index >= _factions.size():
		return
	if _expansion_spacing_remaining > 0.0:
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
	_expansion_spacing_remaining = _random.randf_range(expansion_min_faction_spacing, expansion_min_faction_spacing * 2.0)
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
	var outward_direction := Vector2.LEFT if team == TeamComponent.Team.ENEMY else Vector2.RIGHT
	var terrain_map := _find_terrain_map()
	var tile_size := terrain_map.tile_size if terrain_map != null else 64.0
	var minimum_distance := expansion_min_distance_tiles * tile_size
	var spacing_distance := expansion_spacing_tiles * tile_size
	var origin: Vector2 = faction["origin"]
	var best_candidate: Variant = null
	var best_score := INF
	for attempt in range(48):
		var distance := _random.randf_range(minimum_distance + 24.0, minimum_distance + 220.0)
		# Prefer expanding away from the opposing faction, while allowing a
		# broad lateral spread so every expansion does not form one straight line.
		var direction := outward_direction.rotated(_random.randf_range(-0.75, 0.75))
		var candidate := origin + direction * distance
		if candidate.distance_to(origin) < minimum_distance:
			continue
		var navigation_path: Array[Vector2] = []
		if terrain_map != null:
			var candidate_cell := terrain_map.world_to_cell(candidate)
			if not terrain_map.is_inside(candidate_cell) or not terrain_map.is_traversable(terrain_map.get_tile(candidate_cell)):
				continue
			navigation_path = terrain_map.find_path(builder.global_position, candidate, 20.0, builder)
			if navigation_path.is_empty() or not _is_clear_spawner_site(terrain_map, candidate):
				continue
		else:
			navigation_path.append(candidate)
		var too_close := false
		for building_value in faction["buildings"]:
			if not is_instance_valid(building_value) or not building_value is EnemySpawnerBuilding:
				continue
			var building := building_value as EnemySpawnerBuilding
			if building.global_position.distance_to(candidate) < spacing_distance:
				too_close = true
				break
		if too_close:
			continue
		var score := navigation_path.size() * 2.0
		score += _expansion_site_danger_score(faction, candidate, navigation_path)
		if score < best_score:
			best_score = score
			best_candidate = candidate
	return best_candidate

func _expansion_site_danger_score(faction: Dictionary, candidate: Vector2, navigation_path: Array[Vector2]) -> float:
	var own_team: TeamComponent.Team = faction["team"]
	var score := 0.0
	var enemy_buildings: Array[EnemySpawnerBuilding] = []
	for other_faction in _factions:
		if other_faction["team"] == own_team:
			continue
		for building_value in other_faction["buildings"]:
			if is_instance_valid(building_value) and building_value is EnemySpawnerBuilding:
				enemy_buildings.append(building_value as EnemySpawnerBuilding)

	for enemy_building in enemy_buildings:
		var distance_to_site := candidate.distance_to(enemy_building.global_position)
		var danger_radius := maxf(enemy_building.territory_radius, 120.0)
		if distance_to_site < danger_radius:
			# Building inside enemy territory is a last-resort location.
			score += 20000.0 + (danger_radius - distance_to_site) * 100.0
		elif distance_to_site < danger_radius * 2.0:
			score += (danger_radius * 2.0 - distance_to_site) * 12.0

		for path_point in navigation_path:
			var distance_to_route := path_point.distance_to(enemy_building.global_position)
			if distance_to_route < danger_radius:
				score += 10000.0
				break

	var nearby_enemy_ids: Dictionary = {}
	for path_point in navigation_path:
		for nearby_value in _query_entities_near(path_point, 112.0):
			if nearby_value == null or not is_instance_valid(nearby_value) or not nearby_value is Entity:
				continue
			var nearby_entity := nearby_value as Entity
			var nearby_team := nearby_entity.get_component(TeamComponent) as TeamComponent
			if nearby_team == null or nearby_team.team == own_team or nearby_entity.grounded:
				continue
			nearby_enemy_ids[nearby_entity.get_instance_id()] = true
	score += float(nearby_enemy_ids.size()) * 900.0
	return score

func _query_entities_near(center: Vector2, radius: float) -> Array[Entity]:
	var indexes := get_tree().get_nodes_in_group("entity_spatial_indexes")
	if not indexes.is_empty():
		return (indexes[0] as Node).query_radius(center, radius)
	var results: Array[Entity] = []
	for candidate in get_tree().get_nodes_in_group("entities"):
		if candidate is Entity and (candidate as Entity).global_position.distance_to(center) <= radius:
			results.append(candidate as Entity)
	return results

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
		var builder_value: Variant = expansion.get("builder")
		if builder_value == null or not is_instance_valid(builder_value) or not builder_value is Entity:
			_cancel_expansion(index)
			continue
		var builder := builder_value as Entity
		var alert := builder.get_component(AlertComponent) as AlertComponent
		if alert != null and alert.state != AlertComponent.State.IDLE:
			# Combat can temporarily interrupt construction. Keep the expansion
			# reservation alive and resume the approach when the builder returns.
			continue
		var site_value: Variant = expansion["site"]
		if site_value == null:
			var position: Vector2 = expansion["position"]
			var movement := builder.get_component(MovementComponent) as MovementComponent
			if movement == null:
				_cancel_expansion(index)
				continue
			if movement.is_moving():
				continue
			if builder.global_position.distance_to(position) <= 48.0:
				expansion["site"] = _create_construction_site(expansion["faction_index"], position)
				expansion["remaining"] = construction_duration
				if alert != null:
					alert.set_construction_active(true)
				_builder_cooldowns[builder.get_instance_id()] = builder_expansion_cooldown
				var combat := builder.get_component(CombatComponent) as CombatComponent
				if combat != null:
					combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
			else:
				# A dynamic collision or a failed path can leave an idle builder short
				# of the site. Reissue the construction approach instead of leaving
				# the expansion permanently suspended.
				_issue_move_to_position(builder, position)
		else:
			var site := site_value as EnemySpawnerBuilding
			if not is_instance_valid(site):
				_expansions.remove_at(index)
				continue
			if alert == null or not alert.construction_active:
				continue
			var construction_movement := builder.get_component(MovementComponent) as MovementComponent
			if construction_movement == null:
				_cancel_expansion(index)
				continue
			var presence_distance := builder.global_position.distance_to(site.global_position)
			if presence_distance > site.construction_presence_radius:
				# Construction pauses while the builder is displaced. Once it is
				# safe to do so, bring the builder back to the site's perimeter.
				if not construction_movement.is_moving():
					_issue_move_to_position(builder, site.get_wander_return_position(builder.global_position))
				continue
			if construction_movement.is_moving():
				construction_movement.stop()
			expansion["remaining"] -= delta
			site.set_construction_progress(1.0 - float(expansion["remaining"]) / construction_duration)
			if expansion["remaining"] <= 0.0:
				alert.set_construction_active(false)
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
	site.construction_max_health = building_health
	var territory := faction["territory"] as Node2D
	site.set_shared_territory_owner(territory)
	site.respawn_delay = 5.0
	site.respawn_jitter = 2.0
	add_child(site)
	site.global_position = position
	var health := site.get_component(HealthComponent) as HealthComponent
	if health != null:
		health.maximum_health = 1.0
		health.current_health = 1.0
	site.set_construction_progress(0.0)
	site.enemy_spawned.connect(_on_enemy_spawned.bind(site))
	var buildings: Array = faction["buildings"]
	buildings.append(site)
	territory.call("add_building", site)
	return site

func _cancel_expansion(index: int) -> void:
	var builder_value: Variant = _expansions[index].get("builder")
	if builder_value != null and is_instance_valid(builder_value) and builder_value is Entity:
		var builder_alert := (builder_value as Entity).get_component(AlertComponent) as AlertComponent
		if builder_alert != null:
			builder_alert.set_construction_active(false)
	var site_value: Variant = _expansions[index]["site"]
	if site_value != null and is_instance_valid(site_value) and site_value is EnemySpawnerBuilding:
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
			if own_value == null or not is_instance_valid(own_value) or not own_value is EnemySpawnerBuilding:
				continue
			var own_building := own_value as EnemySpawnerBuilding
			for other_index in range(_factions.size()):
				if other_index == faction_index:
					continue
				var other_faction: Dictionary = _factions[other_index]
				for other_value in other_faction["buildings"]:
					if other_value == null or not is_instance_valid(other_value) or not other_value is EnemySpawnerBuilding:
						continue
					var other_building := other_value as EnemySpawnerBuilding
					if own_building.global_position.distance_to(other_building.global_position) <= own_building.territory_radius:
						return true
		return false

func _on_enemy_spawned(unit: Entity, _building: EnemySpawnerBuilding) -> void:
	# Newly respawned units join the next scheduled wave. This keeps spawning
	# deterministic and avoids every death causing an immediate dogpile order.
	if unit != null:
		_enforce_builder_cap(_building)
		unit.queue_redraw()

func _enforce_builder_cap(source_building: EnemySpawnerBuilding) -> void:
	if not is_instance_valid(source_building):
		return
	for faction in _factions:
		if not faction["buildings"].has(source_building):
			continue
		var builders: Array[Entity] = []
		for building_value in faction["buildings"]:
			if not is_instance_valid(building_value) or not building_value is EnemySpawnerBuilding:
				continue
			var building := building_value as EnemySpawnerBuilding
			for unit in building.get_active_enemies():
				if not is_instance_valid(unit):
					continue
				var alert := unit.get_component(AlertComponent) as AlertComponent
				if alert != null and alert.role == AlertComponent.Role.BUILDER:
					builders.append(unit)
		for index in range(max_builders_per_faction, builders.size()):
			var excess_builder := builders[index]
			var alert := excess_builder.get_component(AlertComponent) as AlertComponent
			if alert != null and alert.construction_active:
				continue
			if alert != null:
				alert.set_role(AlertComponent.Role.PURSUER)
				excess_builder.set("display_name", AlertComponent.get_role_name(alert.role))
				excess_builder.queue_redraw()
		return

func _enforce_all_builder_caps() -> void:
	for faction in _factions:
		for building_value in faction["buildings"]:
			if is_instance_valid(building_value) and building_value is EnemySpawnerBuilding:
				_enforce_builder_cap(building_value as EnemySpawnerBuilding)
				break
