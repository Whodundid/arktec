class_name OreField
extends Node2D

@export var vein_count := 5
@export var map_bounds := Rect2(-1500, -760, 3000, 1520)
@export var minimum_spacing := 180.0
@export_range(2.0, 60.0, 1.0) var respawn_interval := 12.0
var vein_scene: PackedScene
var _random := RandomNumberGenerator.new()
var _respawn_remaining := 0.0
var _initial_spawn_complete := false

func _ready() -> void:
	if not NetworkSession.is_simulation_authority():
		return
	_random.seed = 8675309
	# BattleSandbox creates its faction buildings from its own _ready(). Wait
	# until that setup exists so we can guarantee every vein is reachable from
	# at least one friendly outpost.
	call_deferred("_spawn_veins")

func _spawn_veins() -> void:
	var terrain_map := _find_terrain_map()
	for index in range(vein_count):
		_spawn_one_vein(terrain_map)
	_initial_spawn_complete = true

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
	for attempt in range(30):
		var position := Vector2(_random.randf_range(map_bounds.position.x, map_bounds.end.x), _random.randf_range(map_bounds.position.y, map_bounds.end.y))
		if not _is_valid_position(position, terrain_map):
			continue
		var vein := OreVein.new()
		vein.maximum_ore = _random.randf_range(180.0, 320.0)
		vein.growth_per_second = _random.randf_range(1.0, 2.2)
		vein.position = position
		vein.depleted.connect(_on_vein_depleted)
		add_child(vein)
		return true
	return false

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
			if owner is Node2D and not terrain_map.find_path(owner.global_position, candidate, 20.0).is_empty():
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
