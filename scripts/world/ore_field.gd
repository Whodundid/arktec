class_name OreField
extends Node2D

@export var vein_count := 5
@export var map_bounds := Rect2(-1500, -760, 3000, 1520)
@export var minimum_spacing := 180.0
@export_range(2.0, 60.0, 1.0) var respawn_interval := 12.0
@export var ore_seed := 0
var vein_scene: PackedScene
var _random := RandomNumberGenerator.new()
var _respawn_remaining := 0.0
var _initial_spawn_complete := false

func _ready() -> void:
	if not NetworkSession.is_simulation_authority():
		return
	if ore_seed == 0:
		# Derive ore placement from the shared run seed so the whole world can be
		# reproduced later instead of each subsystem choosing an unrelated layout.
		_random.seed = _get_active_world_seed() ^ 0x4F5245
	else:
		# Non-zero seeds keep test runs and future multiplayer map setup
		# reproducible when the authority needs to share the generated layout.
		_random.seed = ore_seed
	# BattleSandbox creates its faction buildings from its own _ready(). Wait
	# until that setup exists so we can guarantee every vein is reachable from
	# at least one friendly outpost.
	call_deferred("_spawn_veins")

func _spawn_veins() -> void:
	var terrain_map := _find_terrain_map()
	if terrain_map != null and terrain_map.has_method("get_ore_spawn_positions"):
		# The terrain generator returns a shared pool of valid ore sites. Select
		# from that pool by faction proximity so one side cannot accidentally get
		# most of the opening economy just because its noise scores came first.
		var generated_positions: Array[Vector2] = _get_fair_spawn_order(terrain_map)
		for position in generated_positions:
			_spawn_one_vein_at(position, terrain_map)
	while _live_vein_count() < vein_count:
		var count_before := _live_vein_count()
		_spawn_one_vein(terrain_map)
		if _live_vein_count() == count_before:
			break
	_initial_spawn_complete = true

func _get_fair_spawn_order(terrain_map: TerrainMap) -> Array[Vector2]:
	var candidates: Array[Vector2] = terrain_map.call("get_ore_spawn_positions", -1)
	var faction_positions: Array[Vector2] = terrain_map.call("get_faction_spawn_positions", -1)
	if faction_positions.size() < 2 or candidates.size() <= 1:
		return candidates.slice(0, mini(vein_count, candidates.size()))

	var remaining := candidates.duplicate()
	var ordered: Array[Vector2] = []
	var faction_index := 0
	var balanced_count := vein_count - (vein_count % 2)
	while not remaining.is_empty() and ordered.size() < balanced_count:
		var origin: Vector2 = faction_positions[faction_index % faction_positions.size()]
		var best_index := 0
		var best_distance := INF
		for index in range(remaining.size()):
			var distance := origin.distance_squared_to(remaining[index])
			if distance < best_distance:
				best_distance = distance
				best_index = index
		ordered.append(remaining[best_index])
		remaining.remove_at(best_index)
		faction_index += 1

	# With an odd number of veins, use the remaining closest-to-center site as
	# the shared/contested resource instead of giving the extra site to a base.
	if ordered.size() < vein_count and not remaining.is_empty():
		var center := Vector2.ZERO
		for origin in faction_positions:
			center += origin
		center /= float(faction_positions.size())
		remaining.sort_custom(func(first: Vector2, second: Vector2) -> bool:
			return first.distance_squared_to(center) < second.distance_squared_to(center)
		)
		ordered.append(remaining[0])

	return ordered

func _physics_process(delta: float) -> void:
	if not NetworkSession.is_simulation_authority():
		return
	if not _initial_spawn_complete:
		return
	_respawn_remaining = maxf(_respawn_remaining - delta, 0.0)
	if _respawn_remaining > 0.0 or _live_vein_count() >= vein_count:
		return
	var terrain_map := _find_terrain_map()
	if _spawn_one_vein(terrain_map):
		_respawn_remaining = respawn_interval

func _spawn_one_vein(terrain_map: TerrainMap) -> bool:
	var spawn_bounds := map_bounds
	if terrain_map != null:
		var inset := Vector2.ONE * terrain_map.tile_size * 1.5
		spawn_bounds = Rect2(
			terrain_map.map_origin + inset,
			Vector2(terrain_map.columns, terrain_map.rows) * terrain_map.tile_size - inset * 2.0
		)
	for attempt in range(30):
		var position := Vector2(_random.randf_range(spawn_bounds.position.x, spawn_bounds.end.x), _random.randf_range(spawn_bounds.position.y, spawn_bounds.end.y))
		if _spawn_one_vein_at(position, terrain_map):
			return true
	return false

func _spawn_one_vein_at(position: Vector2, terrain_map: TerrainMap) -> bool:
	if not _is_valid_position(position, terrain_map):
		return false
	var vein := OreVein.new()
	vein.maximum_ore = _random.randf_range(180.0, 320.0)
	vein.growth_per_second = _random.randf_range(1.0, 2.2)
	vein.position = position
	vein.depleted.connect(_on_vein_depleted)
	add_child(vein)
	return true

func _on_vein_depleted(vein: OreVein) -> void:
	if not is_instance_valid(vein):
		return
	vein.queue_free()
	_respawn_remaining = minf(_respawn_remaining, respawn_interval) if _respawn_remaining > 0.0 else respawn_interval

func _live_vein_count() -> int:
	var count := 0
	for candidate in get_tree().get_nodes_in_group("ore_veins"):
		if is_instance_valid(candidate) and candidate is OreVein:
			count += 1
	return count

func _is_valid_position(candidate: Vector2, terrain_map: TerrainMap) -> bool:
	if candidate.distance_to(Vector2.ZERO) < 260.0:
		return false
	if terrain_map != null:
		# The vein is drawn roughly 48px wide. Check its center and perimeter so
		# it cannot be painted over a wall with only its center on grass.
		for offset in [Vector2.ZERO, Vector2(44, 0), Vector2(-44, 0), Vector2(0, 44), Vector2(0, -44)]:
			var cell := terrain_map.world_to_cell(candidate + offset)
			if not terrain_map.is_inside(cell) or not terrain_map.is_traversable(terrain_map.get_tile(cell)):
				return false
		var reachable := false
		for owner in get_tree().get_nodes_in_group("territory_owners"):
			if owner is Node2D and not terrain_map.find_path(owner.global_position, candidate, 20.0, null, &"ore_spawn").is_empty():
				reachable = true
				break
		if not reachable:
			return false
	for other in get_tree().get_nodes_in_group("ore_veins"):
		if is_instance_valid(other) and other.global_position.distance_to(candidate) < minimum_spacing:
			return false
	return true

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	return null if maps.is_empty() else maps[0] as TerrainMap

func _get_active_world_seed() -> int:
	var seed_provider := get_node_or_null("/root/WorldSeed")
	return 0 if seed_provider == null else int(seed_provider.call("get_seed"))
