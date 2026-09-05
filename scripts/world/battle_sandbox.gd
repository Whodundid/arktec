class_name BattleSandbox
extends Node2D

const FACTION_TERRITORY_SCRIPT = preload("res://scripts/world/faction_territory.gd")

## Autonomous two-faction combat harness with a third player faction. This is intentionally a sandbox
## coordinator, not a replacement for mission logic: it periodically issues
## attack-move orders while each building's AlertComponent remains responsible
## for local defense and returning units home.

@export var building_scene: PackedScene
@export var units_per_building := [3, 4, 5]
@export_range(1, 20, 1) var starting_units_per_faction := 2
@export_range(2.0, 30.0, 0.5) var wave_interval := 8.0
@export_range(0.1, 1.0, 0.05) var strategic_tick_interval := 0.25
@export_range(32.0, 300.0, 1.0) var attack_standoff := 160.0
@export_range(100.0, 10000.0, 25.0) var building_health := 250.0
@export_range(8.0, 120.0, 1.0) var expansion_check_interval := 18.0
@export_range(0.0, 1.0, 0.05) var expansion_chance := 0.8
@export_range(0.1, 1.0, 0.05) var expansion_min_delay_factor := 0.35
@export_range(1.0, 5.0, 0.05) var expansion_max_delay_factor := 2.75
@export_range(0.0, 60.0, 1.0) var expansion_min_faction_spacing := 8.0
@export_range(4.0, 30.0, 1.0) var construction_duration := 10.0
@export_range(7.0, 16.0, 1.0) var expansion_min_distance_tiles := 8.0
@export_range(2.0, 10.0, 1.0) var expansion_spacing_tiles := 4.0
@export_range(5.0, 120.0, 5.0) var builder_expansion_cooldown := 45.0
@export_range(0, 8, 1) var max_builders_per_faction := 4
@export_range(50, 150, 5) var supply_building_cost := 90
@export_range(1, 10, 1) var supply_building_bonus := 3
@export_range(40.0, 160.0, 8.0) var supply_building_health := 90.0
@export_range(0.4, 1.0, 0.05) var supply_building_footprint_scale := 0.7
@export_range(100, 300, 10) var barracks_building_cost := 180
@export_range(0, 300, 10) var player_starting_ore_bonus := 90
@export_range(100.0, 300.0, 10.0) var barracks_building_health := 180.0
@export_range(0.7, 1.1, 0.05) var barracks_building_footprint_scale := 0.9
@export_range(0.0, 1.0, 0.05) var barracks_building_chance := 0.35
@export_range(1.0, 1.5, 0.05) var main_building_footprint_scale := 1.15
@export_range(0.0, 1.0, 0.05) var supply_building_chance := 0.45
@export_range(4.0, 12.0, 1.0) var expansion_min_supply_distance_tiles := 5.0
@export_range(64.0, 800.0, 16.0) var expansion_resource_attraction_radius := 480.0
@export_range(64.0, 640.0, 8.0) var expansion_min_resource_distance := 256.0
@export_range(0.0, 10000.0, 100.0) var expansion_resource_attraction_weight := 2600.0
@export_range(0.0, 10000.0, 100.0) var expansion_enemy_risk_weight := 1.0
@export var expansion_cost := 300

var _factions: Array[Dictionary] = []
var _wave_remaining: Array[float] = []
var _random := RandomNumberGenerator.new()
var _expansions: Array[Dictionary] = []
var _builder_cooldowns: Dictionary = {}
var _attack_targets: Dictionary = {}
var _ore_security_requests: Dictionary = {}
var _expansion_spacing_remaining := 0.0
var _strategic_tick_remaining := 0.0

func _ready() -> void:
	if not NetworkSession.is_simulation_authority():
		RuntimeLogger.debug("Battle sandbox skipped: this peer is not simulation authority")
		return
	RuntimeLogger.info("Battle sandbox initializing")
	add_to_group("battle_sandboxes")
	_random.seed = _get_active_world_seed() ^ 0x464143
	var starting_positions := _randomize_starting_positions()
	_create_faction(
		"Red Faction",
		TeamComponent.Team.ENEMY,
		[starting_positions[0]]
	)
	_create_faction(
		"Blue Faction",
		TeamComponent.Team.ALLY,
		[starting_positions[1]]
	)
	_create_faction(
		"Player Faction",
		TeamComponent.Team.PLAYER,
		[starting_positions[2]],
		false
	)
	# Player units do not auto-harvest: reserve enough opening ore for the build
	# menu to be useful while leaving the economy under explicit player control.
	ResourceLedger.add_ore(TeamComponent.Team.PLAYER, player_starting_ore_bonus)
	RuntimeLogger.info("Battle sandbox ready: factions=%d" % _factions.size())

func _randomize_starting_positions() -> Array[Vector2]:
	var terrain_map := _find_terrain_map()
	if terrain_map != null and terrain_map.has_method("get_faction_spawn_positions"):
		var generated_positions: Array[Vector2] = terrain_map.call("get_faction_spawn_positions", 2)
		if generated_positions.size() >= 2:
			var generated_sites_are_clear := true
			for position in generated_positions:
				if not _is_clear_spawner_site(terrain_map, position):
					generated_sites_are_clear = false
					break
			if generated_sites_are_clear:
				var third_position: Variant = _find_third_starting_position(terrain_map, generated_positions)
				if third_position != null:
					generated_positions.append(third_position as Vector2)
					return generated_positions
	var positions: Array[Vector2] = []
	for side in [-1, 1]:
		var chosen := Vector2(650.0 * float(side), -220.0)
		for attempt in range(20):
			var candidate := Vector2(
				_random.randf_range(560.0, 760.0) * float(side),
				_random.randf_range(-420.0, 180.0)
			)
			if terrain_map == null or _is_clear_spawner_site(terrain_map, candidate):
				chosen = candidate
				break
		positions.append(chosen)
	var third_position: Variant = _find_third_starting_position(terrain_map, positions) if terrain_map != null else null
	positions.append(third_position as Vector2 if third_position is Vector2 else Vector2(0.0, 620.0))
	return positions

func _find_third_starting_position(terrain_map: TerrainMap, occupied: Array[Vector2]) -> Variant:
	if terrain_map == null:
		return null
	var map_bounds := Rect2(terrain_map.map_origin, Vector2(terrain_map.columns, terrain_map.rows) * terrain_map.tile_size)
	var inset := terrain_map.tile_size * 4.0
	var preferred_positions: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(0.0, 640.0),
		Vector2(0.0, -640.0),
		Vector2(640.0, 0.0),
		Vector2(-640.0, 0.0),
	]
	for preferred in preferred_positions:
		if _is_valid_third_start(preferred, terrain_map, occupied, map_bounds, inset):
			return preferred
	for attempt in range(80):
		var candidate := Vector2(
			_random.randf_range(map_bounds.position.x + inset, map_bounds.end.x - inset),
			_random.randf_range(map_bounds.position.y + inset, map_bounds.end.y - inset)
		)
		if _is_valid_third_start(candidate, terrain_map, occupied, map_bounds, inset):
			return candidate
	return null

func _is_valid_third_start(candidate: Vector2, terrain_map: TerrainMap, occupied: Array[Vector2], map_bounds: Rect2, inset: float) -> bool:
	if not map_bounds.grow(-inset).has_point(candidate):
		return false
	for other in occupied:
		if candidate.distance_to(other) < terrain_map.tile_size * 8.0:
			return false
	return _is_clear_spawner_site(terrain_map, candidate)

func _physics_process(delta: float) -> void:
	if not NetworkSession.is_simulation_authority() or _factions.size() < 2:
		return

	_strategic_tick_remaining = maxf(_strategic_tick_remaining - delta, 0.0)
	for builder_id in _builder_cooldowns.keys():
		_builder_cooldowns[builder_id] = maxf(float(_builder_cooldowns[builder_id]) - delta, 0.0)
	_expansion_spacing_remaining = maxf(_expansion_spacing_remaining - delta, 0.0)

	for faction_index in range(_factions.size()):
		var faction: Dictionary = _factions[faction_index]
		if not bool(faction.get("autonomous", true)):
			continue
		_wave_remaining[faction_index] -= delta
		if _wave_remaining[faction_index] <= 0.0:
			_launch_wave(faction_index)
			_wave_remaining[faction_index] = _random_wave_delay()

		# 1. Access the dictionary directly inside the array loop
		# 2. Safety check: Ensure key exists and force float type conversion
		if not faction.has("expansion_remaining"):
			faction["expansion_remaining"] = _random_expansion_delay()

		# 3. Explicitly cast to float before subtracting to prevent truncation issues
		faction["expansion_remaining"] = float(faction["expansion_remaining"]) - delta

		if faction["expansion_remaining"] <= 0.0:
			faction["expansion_remaining"] = _random_expansion_delay()
			if _random.randf() <= expansion_chance:
				_try_start_expansion(faction_index)

		# 4. Explicitly re-assign back to the array to guarantee the state changes persist
		_factions[faction_index] = faction

	_update_expansions(delta)

	if _strategic_tick_remaining <= 0.0:
		_strategic_tick_remaining = strategic_tick_interval
		_prune_faction_buildings()
		_enforce_all_builder_caps()
		_update_war_states()
		_prune_ore_security_requests()
		_maintain_attack_parties()


func _create_faction(label: String, team: TeamComponent.Team, positions: Array[Vector2], autonomous: bool = true) -> void:
	var faction_buildings: Array = []
	var territory: Node2D = FACTION_TERRITORY_SCRIPT.new()
	territory.set("faction_team", team)
	add_child(territory)
	# A faction begins with one headquarters. Its capacity preserves the old
	# sandbox's approximate starting force, but only a small garrison is present
	# immediately; the rest must be trained over time. The opening garrison is
	# deliberately one builder and one combat unit so expansion is possible
	# without giving either faction a full army for free.
	for index in range(1):
		var building := building_scene.instantiate() as EnemySpawnerBuilding
		if building == null:
			continue
		building.faction_name = label
		building.faction_team = team
		building.max_active_enemies = maxi(starting_units_per_faction, _starting_force_capacity())
		building.initial_spawn_count = starting_units_per_faction
		building.initial_spawn_role = AlertComponent.Role.GUARD
		building.initial_spawn_roles = [AlertComponent.Role.BUILDER, AlertComponent.Role.GUARD]
		building.counts_as_starting_building = true
		building.footprint_scale = main_building_footprint_scale
		building.territory_radius = 180.0
		building.defense_alert_radius = 300.0
		building.respawn_delay = 5.0
		building.respawn_jitter = 2.0
		building.initial_spawn_jitter = 2.5
		building.builder_chance = 0.08
		building.guarantee_builder = index == 0
		building.autonomous = autonomous
		building.auto_train = autonomous
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
		"autonomous": autonomous,
		"at_war": false,
		"expansion_remaining": _random_expansion_delay(),
	})
	_wave_remaining.append(_random_wave_delay())

func can_start_unit_training(building: EnemySpawnerBuilding) -> bool:
	if not is_instance_valid(building):
		return false
	var faction := _find_faction_for_team(building.faction_team)
	if faction.is_empty():
		return true
	return _get_faction_supply_used(faction) < _get_faction_supply_limit(faction)

func can_advance_unit_training(building: EnemySpawnerBuilding) -> bool:
	if not is_instance_valid(building):
		return false
	var faction := _find_faction_for_team(building.faction_team)
	if faction.is_empty():
		return true
	# The unit currently being trained is already included in supply usage. It
	# must be excluded for its own progress check, otherwise reaching the cap
	# would freeze that unit permanently.
	var used := _get_faction_supply_used(faction)
	if building.is_training():
		used -= 1
	return used < _get_faction_supply_limit(faction)

func get_faction_supply(team: TeamComponent.Team) -> Dictionary:
	var faction := _find_faction_for_team(team)
	if faction.is_empty():
		return {}
	return {
		"current": _get_faction_supply_used(faction),
		"maximum": _get_faction_supply_limit(faction),
	}

func _get_faction_supply_used(faction: Dictionary) -> int:
	var used := 0
	for building_value in faction["buildings"]:
		if not is_instance_valid(building_value) or not building_value is EnemySpawnerBuilding:
			continue
		var building := building_value as EnemySpawnerBuilding
		used += building.get_active_enemies().size()
		if building.is_training():
			used += 1
	return used

func _get_faction_supply_limit(faction: Dictionary) -> int:
	var limit := starting_units_per_faction
	for building_value in faction["buildings"]:
		if not is_instance_valid(building_value) or not building_value is EnemySpawnerBuilding:
			continue
		var building := building_value as EnemySpawnerBuilding
		if building.under_construction:
			continue
		if building.is_supply_building():
			limit += supply_building_bonus
		elif not building.counts_as_starting_building:
			limit += building.max_active_enemies
	return limit

func _starting_force_capacity() -> int:
	var capacity := 0
	for value in units_per_building:
		capacity += maxi(int(value), 0)
	return maxi(capacity, starting_units_per_faction)

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

func request_ore_security(worker: Entity, vein: Node2D) -> bool:
	if not NetworkSession.is_simulation_authority() or not is_instance_valid(worker) or not is_instance_valid(vein):
		return false
	var worker_team := worker.get_component(TeamComponent) as TeamComponent
	if worker_team == null:
		return false
	var enemy_target := _find_enemy_claiming_building(worker_team.team, vein.global_position)
	if enemy_target == null:
		return false
	var request_key := enemy_target.get_instance_id()
	if _ore_security_requests.has(request_key):
		return true
	_ore_security_requests[request_key] = {
		"target_id": enemy_target.get_instance_id(),
		"vein_id": vein.get_instance_id(),
		"team": worker_team.team,
	}
	var faction := _find_faction_for_team(worker_team.team)
	if faction.is_empty():
		return true
	var candidates: Array[Entity] = []
	for building_value in faction["buildings"]:
		var building := building_value as EnemySpawnerBuilding
		if not is_instance_valid(building):
			continue
		for unit in building.get_active_enemies():
			var alert := unit.get_component(AlertComponent) as AlertComponent
			var combat := unit.get_component(CombatComponent) as CombatComponent
			if alert == null or combat == null or alert.state != AlertComponent.State.IDLE:
				continue
			if alert.role == AlertComponent.Role.BUILDER or _is_reserved_for_expansion(unit) or combat.target != null:
				continue
			candidates.append(unit)
	var target_position := enemy_target.global_position
	candidates.sort_custom(func(first: Entity, second: Entity) -> bool:
		return first.global_position.distance_squared_to(target_position) < second.global_position.distance_squared_to(target_position)
	)
	for index in range(mini(3, candidates.size())):
		_issue_attack_order(candidates[index], enemy_target)
	if candidates.is_empty():
		_ore_security_requests.erase(request_key)
	return true

func request_worker_defense(worker: Entity, attacker: Entity) -> void:
	if not NetworkSession.is_simulation_authority() or not is_instance_valid(worker) or not is_instance_valid(attacker):
		return
	var worker_team := worker.get_component(TeamComponent) as TeamComponent
	if worker_team == null:
		return
	var faction := _find_faction_for_team(worker_team.team)
	if faction.is_empty():
		return
	var candidates: Array[Entity] = []
	for building_value in faction["buildings"]:
		var building := building_value as EnemySpawnerBuilding
		if not is_instance_valid(building):
			continue
		for unit in building.get_active_enemies():
			var alert := unit.get_component(AlertComponent) as AlertComponent
			var combat := unit.get_component(CombatComponent) as CombatComponent
			if alert == null or combat == null or alert.role == AlertComponent.Role.BUILDER:
				continue
			if alert.state != AlertComponent.State.IDLE or combat.target != null or _is_reserved_for_expansion(unit):
				continue
			candidates.append(unit)
	candidates.sort_custom(func(first: Entity, second: Entity) -> bool:
		return first.global_position.distance_squared_to(worker.global_position) < second.global_position.distance_squared_to(worker.global_position)
	)
	for index in range(mini(3, candidates.size())):
		_issue_defense_order(candidates[index], attacker)

func has_available_combat_defender(team: TeamComponent.Team) -> bool:
	var faction := _find_faction_for_team(team)
	if faction.is_empty():
		return false
	for building_value in faction["buildings"]:
		var building := building_value as EnemySpawnerBuilding
		if not is_instance_valid(building):
			continue
		for unit in building.get_active_enemies():
			var alert := unit.get_component(AlertComponent) as AlertComponent
			var combat := unit.get_component(CombatComponent) as CombatComponent
			if alert == null or combat == null or alert.role == AlertComponent.Role.BUILDER:
				continue
			if alert.state == AlertComponent.State.IDLE and combat.target == null and not _is_reserved_for_expansion(unit):
				return true
	return false

func _issue_defense_order(unit: Entity, attacker: Entity) -> void:
	if not is_instance_valid(unit) or not is_instance_valid(attacker):
		return
	var movement := unit.get_component(MovementComponent) as MovementComponent
	var combat := unit.get_component(CombatComponent) as CombatComponent
	if movement == null or combat == null:
		return
	combat.set_auto_target_mode(CombatComponent.AUTO_ATTACK_MOVE)
	movement.move_to(attacker.global_position)
	combat.set_target(attacker, false)

func _find_enemy_claiming_building(own_team: TeamComponent.Team, position: Vector2) -> EnemySpawnerBuilding:
	var closest: EnemySpawnerBuilding
	var closest_distance := INF
	for candidate in get_tree().get_nodes_in_group("territory_owners"):
		if not candidate is EnemySpawnerBuilding or not is_instance_valid(candidate):
			continue
		var building := candidate as EnemySpawnerBuilding
		if building.faction_team == own_team or not building.contains_territory_position(position):
			continue
		var distance := building.global_position.distance_squared_to(position)
		if distance < closest_distance:
			closest_distance = distance
			closest = building
	return closest

func _find_faction_for_team(team: TeamComponent.Team) -> Dictionary:
	for faction in _factions:
		if faction["team"] == team:
			return faction
	return {}

func _prune_ore_security_requests() -> void:
	for request_key in _ore_security_requests.keys():
		var request: Dictionary = _ore_security_requests[request_key]
		var target_value: Variant = instance_from_id(int(request.get("target_id", 0)))
		var vein_value: Variant = instance_from_id(int(request.get("vein_id", 0)))
		if target_value == null or not is_instance_valid(target_value) or not target_value is EnemySpawnerBuilding or vein_value == null or not is_instance_valid(vein_value) or not vein_value is Node2D:
			_ore_security_requests.erase(request_key)
			continue
		var target := target_value as EnemySpawnerBuilding
		var vein := vein_value as Node2D
		var worker_team: TeamComponent.Team = request.get("team", TeamComponent.Team.NEUTRAL)
		if worker_team != TeamComponent.Team.NEUTRAL and not target.contains_territory_position(vein.global_position):
			_ore_security_requests.erase(request_key)

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
	var building_type := _choose_expansion_building_type(faction)
	var is_supply := building_type == EnemySpawnerBuilding.BuildingType.SUPPLY
	var build_cost := supply_building_cost if is_supply else (barracks_building_cost if building_type == EnemySpawnerBuilding.BuildingType.BARRACKS else expansion_cost)
	# Check the selected building's actual cost. Supply depots are intentionally
	# allowed to pass through this decision before the expensive main-expansion
	# budget gate, so they can support the early economy at the first supply cap.
	if not ResourceLedger.can_afford(faction["team"], build_cost):
		return
	var position: Variant = _find_expansion_position(faction, builder, is_supply)
	if position == null:
		return
	if not ResourceLedger.spend_ore(faction["team"], build_cost):
		return
	var builder_harvest := builder.get_component(HarvestComponent) as HarvestComponent
	if builder_harvest != null and not builder_harvest.can_start_construction():
		ResourceLedger.add_ore(faction["team"], build_cost)
		return
	if builder_harvest != null:
		builder_harvest.cancel_harvest_action()
	var builder_alert := builder.get_component(AlertComponent) as AlertComponent
	if builder_alert != null:
		builder_alert.set_construction_active(true)
	var is_main_expansion := building_type == EnemySpawnerBuilding.BuildingType.MAIN
	var escorts = []
	if is_main_expansion:
		escorts = _find_expansion_escorts(faction, builder)
	var expansion := {
		"faction_index": faction_index,
		"building_type": building_type,
		"cost": build_cost,
		"builder": builder,
		"escorts": escorts,
		"position": position,
		"site": null,
		"remaining": -1.0,
	}
	_expansions.append(expansion)
	_expansion_spacing_remaining = _random.randf_range(expansion_min_faction_spacing, expansion_min_faction_spacing * 2.0)
	_issue_move_to_position(builder, position as Vector2)
	if is_main_expansion:
		for escort in escorts:
			_issue_move_to_position(escort, position as Vector2)

func request_player_construction(builder: Entity, position: Vector2, building_type: int) -> bool:
	if not NetworkSession.is_simulation_authority() or not is_instance_valid(builder):
		return false
	var team := builder.get_component(TeamComponent) as TeamComponent
	var alert := builder.get_component(AlertComponent) as AlertComponent
	if team == null or team.team != TeamComponent.Team.PLAYER or alert == null or alert.role != AlertComponent.Role.BUILDER or alert.state != AlertComponent.State.IDLE:
		return false
	var faction := _find_faction_for_team(TeamComponent.Team.PLAYER)
	if faction.is_empty() or not _find_available_builders(faction, false).has(builder):
		return false
	if building_type < EnemySpawnerBuilding.BuildingType.MAIN or building_type > EnemySpawnerBuilding.BuildingType.SUPPLY:
		return false
	var is_supply := building_type == EnemySpawnerBuilding.BuildingType.SUPPLY
	var build_cost := supply_building_cost if is_supply else (barracks_building_cost if building_type == EnemySpawnerBuilding.BuildingType.BARRACKS else expansion_cost)
	if not ResourceLedger.can_afford(TeamComponent.Team.PLAYER, build_cost):
		return false
	if not can_place_player_construction(position, building_type):
		return false
	if not ResourceLedger.spend_ore(TeamComponent.Team.PLAYER, build_cost):
		return false
	var builder_harvest := builder.get_component(HarvestComponent) as HarvestComponent
	if builder_harvest != null:
		builder_harvest.cancel_harvest_action()
	alert.set_construction_active(true)
	_expansions.append({
		"faction_index": _factions.find(faction),
		"building_type": building_type,
		"cost": build_cost,
		"builder": builder,
		"escorts": [],
		"position": position,
		"site": null,
		"remaining": -1.0,
	})
	_issue_move_to_position(builder, position)
	return true

func has_player_construction_started(builder: Entity) -> bool:
	# The HUD uses this to keep the placement ghost visible while the builder is
	# still walking to the confirmed location. A missing expansion means the
	# order was canceled or has already completed, so the ghost can be cleared.
	for expansion in _expansions:
		if expansion.get("builder") == builder:
			return expansion.get("site") != null
	return true

func can_place_player_construction(position: Vector2, building_type: int) -> bool:
	if building_type < EnemySpawnerBuilding.BuildingType.MAIN or building_type > EnemySpawnerBuilding.BuildingType.SUPPLY:
		return false
	var footprint_scale := supply_building_footprint_scale if building_type == EnemySpawnerBuilding.BuildingType.SUPPLY else (barracks_building_footprint_scale if building_type == EnemySpawnerBuilding.BuildingType.BARRACKS else main_building_footprint_scale)
	var terrain_map := _find_terrain_map()
	if terrain_map == null or not _is_clear_spawner_site(terrain_map, position, footprint_scale):
		return false
	for other_faction in _factions:
		for building_value in other_faction["buildings"]:
			if is_instance_valid(building_value) and position.distance_to((building_value as EnemySpawnerBuilding).global_position) < 96.0:
				return false
	for expansion in _expansions:
		if position.distance_to(expansion["position"]) < 96.0:
			return false
	return true

func _find_available_builders(faction: Dictionary, apply_ai_restrictions: bool = true) -> Array[Entity]:
	var builders: Array[Entity] = []
	for building_value in faction["buildings"]:
		var building := building_value as EnemySpawnerBuilding
		if not is_instance_valid(building) or building.under_construction:
			continue
		for unit in building.get_active_enemies():
			var alert := unit.get_component(AlertComponent) as AlertComponent
			var cooldown := float(_builder_cooldowns.get(unit.get_instance_id(), 0.0)) if apply_ai_restrictions else 0.0
			var harvest := unit.get_component(HarvestComponent) as HarvestComponent
			if alert != null and alert.role == AlertComponent.Role.BUILDER and alert.state == AlertComponent.State.IDLE and cooldown <= 0.0 and not _is_reserved_for_expansion(unit) and (harvest == null or harvest.can_start_construction()):
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

func _should_build_supply(faction: Dictionary) -> bool:
	var supply_count := 0
	var used := 0
	for building_value in faction["buildings"]:
		if not is_instance_valid(building_value) or not building_value is EnemySpawnerBuilding:
			continue
		var building := building_value as EnemySpawnerBuilding
		if building.is_supply_building() and not building.under_construction:
			supply_count += 1
		used += building.get_active_enemies().size()
		if building.is_training():
			used += 1
	var at_supply_limit := used >= _get_faction_supply_limit(faction)
	return at_supply_limit and (supply_count == 0 or _random.randf() < supply_building_chance)

func _choose_expansion_building_type(faction: Dictionary) -> int:
	if _should_build_supply(faction):
		return EnemySpawnerBuilding.BuildingType.SUPPLY
	var has_barracks := false
	for building_value in faction["buildings"]:
		if is_instance_valid(building_value) and building_value is EnemySpawnerBuilding and (building_value as EnemySpawnerBuilding).building_type == EnemySpawnerBuilding.BuildingType.BARRACKS:
			has_barracks = true
			break
	# Once the first supply support exists, establish a combat production site
	# before spending the faction's next expansion on another main outpost.
	if not has_barracks:
		return EnemySpawnerBuilding.BuildingType.BARRACKS
	return EnemySpawnerBuilding.BuildingType.BARRACKS if _random.randf() < barracks_building_chance else EnemySpawnerBuilding.BuildingType.MAIN

func _find_expansion_position(faction: Dictionary, builder: Entity, for_supply: bool = false) -> Variant:
	var team: TeamComponent.Team = faction["team"]
	var terrain_map := _find_terrain_map()
	var origin: Vector2 = faction["origin"]

	var outward_direction := Vector2.RIGHT # Safe fallback

	for other_faction in _factions:
		if other_faction["team"] != team:
			var opponent_origin: Vector2 = other_faction["origin"]
			outward_direction = origin.direction_to(opponent_origin)
			break

	if outward_direction.length_squared() <= 0.001:
		outward_direction = Vector2.RIGHT

	var tile_size := terrain_map.tile_size if terrain_map != null else 64.0
	var minimum_distance := (expansion_min_supply_distance_tiles if for_supply else expansion_min_distance_tiles) * tile_size
	var spacing_distance := expansion_spacing_tiles * tile_size
	var footprint_scale := supply_building_footprint_scale if for_supply else main_building_footprint_scale

	var best_candidate: Variant = null
	var best_score := INF
	var resource_veins := _get_live_resource_veins()

	for attempt in range(48):
		var distance := _random.randf_range(minimum_distance + 24.0, minimum_distance + 220.0)
		var candidate: Vector2

		if not for_supply and not resource_veins.is_empty() and _random.randf() < 0.65:
			var vein := resource_veins[_random.randi_range(0, resource_veins.size() - 1)] as Node2D
			var from_origin := origin.direction_to(vein.global_position)
			if from_origin.length_squared() <= 0.001:
				from_origin = outward_direction
			var resource_offset := _random.randf_range(expansion_min_resource_distance, expansion_min_resource_distance + 128.0)
			candidate = vein.global_position + from_origin * resource_offset
		else:
			var direction := outward_direction.rotated(_random.randf_range(-0.95, 0.95))
			candidate = origin + direction * distance

		if candidate.distance_to(origin) < minimum_distance:
			continue

		var navigation_path: Array[Vector2] = []
		if terrain_map != null:
			var candidate_cell := terrain_map.world_to_cell(candidate)
			var inside = terrain_map.is_inside(candidate_cell)
			var traversable = terrain_map.is_traversable(terrain_map.get_tile(candidate_cell))

			if not inside or not traversable:
				continue

			navigation_path = terrain_map.find_path(builder.global_position, candidate, 20.0, builder, &"expansion_site")
			if navigation_path.is_empty() or not _is_clear_spawner_site(terrain_map, candidate, footprint_scale):
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

		if not _is_far_enough_from_resources(candidate, resource_veins):
			continue

		var score := navigation_path.size() * 2.0
		score += _expansion_site_resource_score(candidate, resource_veins)
		score += _expansion_site_danger_score(faction, candidate, navigation_path, 1.75 if for_supply else 1.0)
		if for_supply:
			score += _expansion_site_protection_score(faction, candidate)

		if score < best_score:
			best_score = score
			best_candidate = candidate

	return best_candidate

func _expansion_site_danger_score(faction: Dictionary, candidate: Vector2, navigation_path: Array[Vector2], risk_multiplier: float = 1.0) -> float:
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
			# Enemy proximity is a risk, not an absolute directional ban. A rich
			# resource can justify a forward outpost, especially with escorts.
			score += (5000.0 + (danger_radius - distance_to_site) * 40.0) * expansion_enemy_risk_weight * risk_multiplier
		elif distance_to_site < danger_radius * 2.0:
			score += (danger_radius * 2.0 - distance_to_site) * 6.0 * expansion_enemy_risk_weight * risk_multiplier

		for path_point in navigation_path:
			var distance_to_route := path_point.distance_to(enemy_building.global_position)
			if distance_to_route < danger_radius:
				score += 2500.0 * expansion_enemy_risk_weight * risk_multiplier
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
	score += float(nearby_enemy_ids.size()) * 450.0 * expansion_enemy_risk_weight * risk_multiplier
	return score

func _expansion_site_protection_score(faction: Dictionary, candidate: Vector2) -> float:
	var nearest_friendly_distance := INF
	for building_value in faction["buildings"]:
		if is_instance_valid(building_value) and building_value is EnemySpawnerBuilding:
			nearest_friendly_distance = minf(nearest_friendly_distance, candidate.distance_to((building_value as EnemySpawnerBuilding).global_position))
	return minf(nearest_friendly_distance, 600.0) * 2.0

func _get_live_resource_veins() -> Array[Node2D]:
	var veins: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("ore_veins"):
		if candidate is Node2D and is_instance_valid(candidate) and float(candidate.get("ore")) > 1.0:
			veins.append(candidate as Node2D)
	return veins

func _expansion_site_resource_score(candidate: Vector2, resource_veins: Array[Node2D]) -> float:
	if resource_veins.is_empty():
		return 0.0
	var best_resource_score := 0.0
	for vein in resource_veins:
		var distance_to_vein := candidate.distance_to(vein.global_position)
		if distance_to_vein > expansion_resource_attraction_radius:
			continue
		# Prefer a useful working distance rather than placing the building on
		# top of the vein or making its footprint awkward for workers.
		var ideal_distance := maxf(float(vein.get("harvest_radius")) + 110.0, 144.0)
		var closeness := 1.0 - absf(distance_to_vein - ideal_distance) / expansion_resource_attraction_radius
		best_resource_score = maxf(best_resource_score, clampf(closeness, 0.0, 1.0))
	return -best_resource_score * expansion_resource_attraction_weight

func _is_far_enough_from_resources(candidate: Vector2, resource_veins: Array[Node2D]) -> bool:
	for vein in resource_veins:
		if candidate.distance_to(vein.global_position) < expansion_min_resource_distance:
			return false
	return true

func _query_entities_near(center: Vector2, radius: float) -> Array[Entity]:
	var indexes := get_tree().get_nodes_in_group("entity_spatial_indexes")
	if not indexes.is_empty():
		return (indexes[0] as Node).query_radius(center, radius)
	var results: Array[Entity] = []
	for candidate in get_tree().get_nodes_in_group("entities"):
		if candidate is Entity and (candidate as Entity).global_position.distance_to(center) <= radius:
			results.append(candidate as Entity)
	return results

func _is_clear_spawner_site(terrain_map: TerrainMap, center: Vector2, footprint_scale: float = 1.0) -> bool:
	# Validate the scaled building footprint plus a walkable perimeter. The
	# perimeter keeps a completed building from pinning its Builder between the
	# structure and a stone tile, which the old four-corner check could allow.
	var half_width := 30.0 * footprint_scale + 28.0
	var half_height := 24.0 * footprint_scale + 28.0
	var offsets := [
		Vector2(-half_width, -half_height), Vector2(0.0, -half_height), Vector2(half_width, -half_height),
		Vector2(-half_width, 0.0), Vector2(half_width, 0.0),
		Vector2(-half_width, half_height), Vector2(0.0, half_height), Vector2(half_width, half_height),
	]
	for offset in offsets:
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
				expansion["site"] = _create_construction_site(expansion["faction_index"], position, expansion.get("building_type", EnemySpawnerBuilding.BuildingType.MAIN))
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
				var building_type: int = expansion.get("building_type", EnemySpawnerBuilding.BuildingType.MAIN)
				site.complete_construction(0 if building_type == EnemySpawnerBuilding.BuildingType.SUPPLY else _random.randi_range(2, 5))
				_expansions.remove_at(index)

func _create_construction_site(faction_index: int, position: Vector2, building_type: int = EnemySpawnerBuilding.BuildingType.MAIN) -> EnemySpawnerBuilding:
	var faction: Dictionary = _factions[faction_index]
	var site := building_scene.instantiate() as EnemySpawnerBuilding
	if site == null:
		return null
	site.faction_name = faction["label"]
	site.faction_team = faction["team"]
	site.autonomous = bool(faction.get("autonomous", true))
	site.auto_train = bool(faction.get("autonomous", true))
	site.building_type = building_type
	if building_type == EnemySpawnerBuilding.BuildingType.SUPPLY:
		site.supply_bonus = supply_building_bonus
		site.footprint_scale = supply_building_footprint_scale
		site.construction_max_health = supply_building_health
	elif building_type == EnemySpawnerBuilding.BuildingType.BARRACKS:
		site.footprint_scale = barracks_building_footprint_scale
		site.construction_max_health = barracks_building_health
	else:
		site.footprint_scale = main_building_footprint_scale
	site.max_active_enemies = 0
	site.builder_chance = 0.08
	site.under_construction = true
	# Construction is completed from the safe perimeter, not by forcing the
	# worker into the building's solid collision footprint.
	site.construction_presence_radius = 112.0
	if building_type == EnemySpawnerBuilding.BuildingType.MAIN:
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

func _get_active_world_seed() -> int:
	var seed_provider := get_node_or_null("/root/WorldSeed")
	return 0 if seed_provider == null else int(seed_provider.call("get_seed"))

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
		if not bool(faction.get("autonomous", true)):
			return
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
				var faction_color := Color("e45b61") if (excess_builder.get_component(TeamComponent) as TeamComponent).team == TeamComponent.Team.ENEMY else Color("63d8e2")
				excess_builder.set("body_color", faction_color)
				excess_builder.queue_redraw()
		return

func _enforce_all_builder_caps() -> void:
	for faction in _factions:
		for building_value in faction["buildings"]:
			if is_instance_valid(building_value) and building_value is EnemySpawnerBuilding:
				_enforce_builder_cap(building_value as EnemySpawnerBuilding)
				break
