class_name TreeField
extends Node2D

## Seeded visual tree patches. Trees are intentionally non-blocking so this
## first pass improves world depth without changing the navigation rules.

@export var tree_count := 30
@export var patch_count := 7
@export_range(24.0, 260.0, 8.0) var patch_radius := 144.0
@export var map_bounds := Rect2(-1700.0, -940.0, 3400.0, 1880.0)
@export_range(48.0, 300.0, 1.0) var tree_height := 200.0
@export_range(64.0, 260.0, 8.0) var minimum_tree_spacing := 150.0

const TREE_TEXTURE_PATHS := [
	"res://assets/art/trees/birch_0.png",
	"res://assets/art/trees/tree_pine_2.png",
]

var _wind_time := 0.0
var _wind_direction := Vector2(1.0, 0.12).normalized()
var _wind_strength := 5.0

func _ready() -> void:
	var terrain_map := _find_terrain_map()
	var seed_provider := get_node_or_null("/root/WorldSeed")
	if seed_provider == null:
		return
	var random := RandomNumberGenerator.new()
	random.seed = int(seed_provider.call("get_seed")) ^ 0x545245
	var textures: Array[Texture2D] = []
	for path in TREE_TEXTURE_PATHS:
		var loaded := load(path) as Texture2D
		if loaded != null:
			textures.append(loaded)
	if textures.is_empty():
		return
	if terrain_map != null and terrain_map.has_method("get_tree_spawn_positions"):
		var generated_positions: Array[Vector2] = terrain_map.call("get_tree_spawn_positions", tree_count)
		if not generated_positions.is_empty():
			for position in generated_positions:
				_spawn_tree(position, textures, random)
			return

	var spawned := 0
	var spawned_positions: Array = []
	for patch_index in range(patch_count):
		var patch_center := Vector2(
			random.randf_range(map_bounds.position.x, map_bounds.end.x),
			random.randf_range(map_bounds.position.y, map_bounds.end.y)
		)
		for tree_index in range(16):
			if spawned >= tree_count:
				return
			var position := patch_center + Vector2(
				random.randf_range(-patch_radius, patch_radius),
				random.randf_range(-patch_radius, patch_radius)
			)
			if not _is_valid_position(position, terrain_map) or _is_too_close_to_existing_tree(position, spawned_positions):
				continue
			_spawn_tree(position, textures, random)
			spawned_positions.append(position)
			spawned += 1

func _spawn_tree(position: Vector2, textures: Array[Texture2D], random: RandomNumberGenerator) -> void:
	var tree := TreeDoodad.new()
	var texture_index := random.randi_range(0, textures.size() - 1)
	tree.texture = textures[texture_index]
	var species_scale := 0.8 if texture_index == 0 else 1.0
	tree.target_height = tree_height * species_scale * random.randf_range(0.9, 1.1)
	tree.wind_factor = 0.55 if texture_index == 0 else 0.85
	tree.flip_h = random.randf() < 0.5
	tree.position = position
	add_child(tree)

func _is_too_close_to_existing_tree(position: Vector2, existing_positions: Array) -> bool:
	for existing_position in existing_positions:
		if position.distance_to(existing_position as Vector2) < minimum_tree_spacing:
			return true
	return false

func _process(delta: float) -> void:
	_wind_time += delta
	_wind_direction = Vector2.RIGHT.rotated(0.12 + sin(_wind_time * 0.11) * 0.16).normalized()
	_wind_strength = 4.0 + (sin(_wind_time * 0.53) * 0.5 + 0.5) * 4.0 + (sin(_wind_time * 1.31) * 0.5 + 0.5) * 1.5
	for child in get_children():
		if child is TreeDoodad:
			var phase := float(child.get_instance_id() % 31) * 0.37
			(child as TreeDoodad).set_wind(_wind_direction, _wind_strength, _wind_time, phase)

func _is_valid_position(position: Vector2, terrain_map: TerrainMap) -> bool:
	if terrain_map == null:
		return true
	var cell := terrain_map.world_to_cell(position)
	return terrain_map.is_inside(cell) and terrain_map.is_tree_surface(terrain_map.get_tile(cell))

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	return null if maps.is_empty() else maps[0] as TerrainMap
