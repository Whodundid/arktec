extends Node2D

const RAIL_SEGMENT_SCRIPT = preload("res://scripts/world/rail_segment.gd")
const CARDINAL_DIRECTIONS := [
	{"offset": Vector2i.UP, "bit": 1},
	{"offset": Vector2i.RIGHT, "bit": 2},
	{"offset": Vector2i.DOWN, "bit": 4},
	{"offset": Vector2i.LEFT, "bit": 8},
]

var _segments: Dictionary = {}

func _ready() -> void:
	add_to_group("rail_networks")

func world_to_cell(world_position: Vector2) -> Vector2i:
	var terrain := _find_terrain_map()
	return Vector2i.ZERO if terrain == null else terrain.world_to_cell(world_position)

func cell_center(cell: Vector2i) -> Vector2:
	var terrain := _find_terrain_map()
	return Vector2.ZERO if terrain == null else terrain.cell_center(cell)

func can_place_rail_at_world(world_position: Vector2) -> bool:
	return can_place_rail_cell(world_to_cell(world_position))

func can_place_rail_cell(cell: Vector2i) -> bool:
	var terrain := _find_terrain_map()
	if terrain == null or not terrain.is_inside(cell) or not terrain.is_traversable(terrain.get_tile(cell)):
		return false
	if _segments.has(cell):
		return false
	if terrain.get_artifact_spawn_cells().has(cell):
		return false
	if terrain.get_landing_ship_occupied_positions().has(terrain.cell_center(cell)):
		return false
	var center := terrain.cell_center(cell)
	for vein in get_tree().get_nodes_in_group("ore_veins"):
		if is_instance_valid(vein) and vein is Node2D and terrain.world_to_cell((vein as Node2D).global_position) == cell:
			return false
	for tree in get_tree().get_nodes_in_group("tree_doodads"):
		if is_instance_valid(tree) and tree is Node2D and terrain.world_to_cell((tree as Node2D).global_position) == cell:
			return false
	for candidate in get_tree().get_nodes_in_group("buildings"):
		if not candidate is EnemySpawnerBuilding or not is_instance_valid(candidate):
			continue
		var building := candidate as EnemySpawnerBuilding
		var size := Vector2(building.landing_ship_grid_size) * building.landing_ship_tile_size if building.is_landing_ship else Vector2(60.0, 48.0) * building.footprint_scale
		if Rect2(building.global_position - size * 0.5, size).has_point(center):
			return false
	return true

func create_construction_site(cell: Vector2i, maximum_health: float) -> Node2D:
	if not can_place_rail_cell(cell):
		return null
	var terrain := _find_terrain_map()
	var segment := RAIL_SEGMENT_SCRIPT.new() as Node2D
	segment.name = "Rail_%d_%d" % [cell.x, cell.y]
	segment.set("grid_cell", cell)
	segment.set("tile_size", terrain.tile_size)
	segment.set("maximum_health", maximum_health)
	segment.position = terrain.cell_center(cell)
	_segments[cell] = segment
	add_child(segment)
	_refresh_connections_around(cell)
	return segment

func get_segment_at_cell(cell: Vector2i) -> Node2D:
	var candidate: Variant = _segments.get(cell)
	if candidate != null and is_instance_valid(candidate):
		return candidate as Node2D
	_segments.erase(cell)
	return null

func get_segment_at_world(world_position: Vector2) -> Node2D:
	return get_segment_at_cell(world_to_cell(world_position))

func get_segments() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for cell in _segments.keys():
		var segment := get_segment_at_cell(cell)
		if segment != null:
			result.append(segment)
	return result

func _refresh_connections_around(cell: Vector2i) -> void:
	_refresh_segment_connections(cell)
	for direction in CARDINAL_DIRECTIONS:
		_refresh_segment_connections(cell + direction["offset"])

func _refresh_segment_connections(cell: Vector2i) -> void:
	var segment := get_segment_at_cell(cell)
	if segment == null:
		return
	var mask := 0
	var terrain := _find_terrain_map()
	if terrain != null and cell == terrain.get_landing_ship_rail_receiver_cell():
		mask |= 1 # The ship's lower-center loading port is the virtual north link.
	for direction in CARDINAL_DIRECTIONS:
		if get_segment_at_cell(cell + direction["offset"]) != null:
			mask |= int(direction["bit"])
	segment.call("set_connection_mask", mask)

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	return null if maps.is_empty() else maps[0] as TerrainMap
