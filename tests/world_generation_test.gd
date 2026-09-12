extends Node

const TERRAIN_MAP_SCRIPT = preload("res://scripts/world/terrain_map.gd")
const BATTLE_SANDBOX_SCENE = preload("res://scenes/battle_sandbox.tscn")
const CHARACTER_SCENE = preload("res://scenes/entities/character_entity.tscn")

func _ready() -> void:
	var water_sheet := load("res://assets/art/water-sheet.png") as Texture2D
	assert(water_sheet != null)
	assert(water_sheet.get_size() == Vector2(160.0, 32.0))
	var seed_provider := get_node("/root/WorldSeed")
	var reference: Dictionary = {}
	var continental_world_count := 0
	for seed_value in [1, 42, 8675309, 123456789, 2147483646]:
		seed_provider.set("active_seed", seed_value)
		var terrain := _make_map()
		add_child(terrain)
		await get_tree().process_frame
		var counts := _assert_generated_map(terrain)
		if not terrain.is_island_world():
			continental_world_count += 1
			assert(_has_traversable_edge(terrain))
		print("WORLD_GENERATION_COUNTS seed=%d island=%s %s" % [seed_value, terrain.is_island_world(), counts])
		if seed_value == 123456789:
			reference = {
				"tiles": terrain.tiles.duplicate(true),
				"trees": terrain.get_tree_spawn_positions(),
				"factions": terrain.get_faction_spawn_positions(),
				"ore": terrain.get_ore_spawn_positions(),
				"artifacts": terrain.get_artifact_spawn_cells(),
				"landing_ship": terrain.get_landing_ship_top_left_cell(),
			}
		terrain.queue_free()
		await get_tree().process_frame
	assert(continental_world_count > 0)

	seed_provider.set("active_seed", 123456789)
	var second := _make_map()
	add_child(second)
	await get_tree().process_frame
	assert(second.tiles == reference["tiles"])
	assert(second.get_tree_spawn_positions() == reference["trees"])
	assert(second.get_faction_spawn_positions() == reference["factions"])
	assert(second.get_ore_spawn_positions() == reference["ore"])
	assert(second.get_artifact_spawn_cells() == reference["artifacts"])
	assert(second.get_landing_ship_top_left_cell() == reference["landing_ship"])
	second.queue_free()
	await get_tree().process_frame

	seed_provider.set("active_seed", 123456789)
	var sandbox := BATTLE_SANDBOX_SCENE.instantiate()
	add_child(sandbox)
	for _frame in range(3):
		await get_tree().process_frame
	var tree_field := sandbox.get_node("TreeField")
	var sandbox_terrain := sandbox.get_node("TerrainMap")
	assert(tree_field.get_child_count() == int(tree_field.get("tree_count")))
	var stone_occluders := sandbox_terrain.get_node_or_null("StoneOccluders")
	assert(stone_occluders != null)
	assert(stone_occluders.get_child_count() > 1)
	var height_shadows := sandbox_terrain.get_node_or_null("HeightShadows") as MultiMeshInstance2D
	assert(height_shadows != null)
	assert(height_shadows.multimesh != null)
	assert(height_shadows.multimesh.instance_count == _count_exposed_height_edges(sandbox_terrain))
	assert(height_shadows.material is ShaderMaterial)
	assert(height_shadows.texture != null)
	assert(get_tree().get_nodes_in_group("territory_owners").size() == 3)
	assert(get_tree().get_nodes_in_group("ore_veins").size() == 5)
	var artifacts := get_tree().get_nodes_in_group("artifacts")
	assert(artifacts.size() >= 1 and artifacts.size() <= 3)
	var objective_count := 0
	for artifact in artifacts:
		assert((artifact as CollisionObject2D).get_collision_layer_value(5))
		var artifact_collider := artifact.get_node("CollisionShape2D") as CollisionShape2D
		assert(artifact_collider.shape is RectangleShape2D)
		assert((artifact_collider.shape as RectangleShape2D).size == Vector2.ONE * sandbox_terrain.tile_size)
		assert(artifact.get("state") == 0)
		assert(bool(artifact.call("is_invulnerable")))
		var health_before: float = artifact.get("current_health")
		artifact.call("damage", 100.0)
		assert(is_equal_approx(float(artifact.get("current_health")), health_before))
		if bool(artifact.get("mission_objective")):
			objective_count += 1
	assert(objective_count >= 1)
	var landing_ships: Array[Node] = []
	for owner in get_tree().get_nodes_in_group("territory_owners"):
		if bool(owner.get("is_landing_ship")):
			landing_ships.append(owner)
	assert(landing_ships.size() == 1)
	var landing_ship := landing_ships[0] as CollisionObject2D
	assert(landing_ship.global_position == sandbox_terrain.get_landing_ship_center())
	var ship_collider := landing_ship.get_node("CollisionShape2D") as CollisionShape2D
	assert(ship_collider.shape is RectangleShape2D)
	assert((ship_collider.shape as RectangleShape2D).size == Vector2(192.0, 256.0))
	var collision_probe := CHARACTER_SCENE.instantiate() as CollisionObject2D
	assert(collision_probe.get_collision_mask_value(5))
	collision_probe.queue_free()

	print("WORLD_GENERATION_TEST_PASS")
	get_tree().quit(0)

func _assert_generated_map(terrain: TerrainMap) -> Dictionary:
	var counts := _count_tiles(terrain)
	assert(counts[TerrainMap.TileType.GRASS] > 0)
	assert(counts[TerrainMap.TileType.WATER] > 0)
	assert(counts[TerrainMap.TileType.STONE] + counts[TerrainMap.TileType.SMOOTH_STONE] > 0)
	assert(counts[TerrainMap.TileType.DIRT] + counts[TerrainMap.TileType.CRACKED_DIRT] > 0)
	assert(counts[TerrainMap.TileType.SAND] > 0)
	assert(counts[TerrainMap.TileType.DARK_GRASS] > 0)
	assert(counts[TerrainMap.TileType.DRY_GRASS] > 0)
	assert(counts[TerrainMap.TileType.SMOOTH_STONE] > 0)
	assert(counts[TerrainMap.TileType.CRACKED_DIRT] > 0)
	var common_grass_total: int = int(counts[TerrainMap.TileType.GRASS]) + int(counts[TerrainMap.TileType.DRY_GRASS])
	var dry_grass_ratio := float(counts[TerrainMap.TileType.DRY_GRASS]) / maxf(float(common_grass_total), 1.0)
	assert(dry_grass_ratio >= 0.2 and dry_grass_ratio <= 0.8)
	assert(counts[TerrainMap.TileType.DEEP_WATER] < counts[TerrainMap.TileType.WATER])
	_assert_water_regions_are_uniform(terrain)
	_assert_visual_heights(terrain)
	var tree_positions: Array[Vector2] = terrain.get_tree_spawn_positions()
	var faction_positions: Array[Vector2] = terrain.get_faction_spawn_positions()
	var ore_positions: Array[Vector2] = terrain.get_ore_spawn_positions()
	var artifact_cells: Array[Vector2i] = terrain.get_artifact_spawn_cells()
	assert(tree_positions.size() >= 30)
	assert(faction_positions.size() == 2)
	assert(ore_positions.size() >= 5)
	assert(artifact_cells.size() >= 1 and artifact_cells.size() <= 3)
	assert(absf(faction_positions[0].x - faction_positions[1].x) >= terrain.tile_size * float(terrain.columns) * 0.35)
	assert(not terrain.find_path(faction_positions[0], faction_positions[1], 20.0).is_empty())
	_assert_mission_sites(terrain, artifact_cells, ore_positions)
	return counts

func _assert_mission_sites(terrain: TerrainMap, artifact_cells: Array[Vector2i], ore_positions: Array[Vector2]) -> void:
	for index in range(artifact_cells.size()):
		var cell := artifact_cells[index]
		assert(terrain.is_inside(cell))
		assert(terrain.is_traversable(terrain.get_tile(cell)))
		assert(terrain.world_to_cell(terrain.cell_center(cell)) == cell)
		for other_index in range(index + 1, artifact_cells.size()):
			assert(Vector2(cell).distance_to(Vector2(artifact_cells[other_index])) >= 6.0)
		for ore_position in ore_positions:
			assert(terrain.cell_center(cell).distance_to(ore_position) >= terrain.tile_size * 2.0)
	var ship_top_left := terrain.get_landing_ship_top_left_cell()
	assert(ship_top_left != Vector2i(-1, -1))
	for y in range(-1, 5):
		for x in range(-1, 4):
			var ship_cell := ship_top_left + Vector2i(x, y)
			assert(terrain.is_inside(ship_cell))
			assert(terrain.is_traversable(terrain.get_tile(ship_cell)))
	var ship_center_cell := Vector2(ship_top_left) + Vector2(1.5, 2.0)
	for artifact_cell in artifact_cells:
		assert(ship_center_cell.distance_to(Vector2(artifact_cell) + Vector2.ONE * 0.5) >= 18.0)

func _make_map() -> TerrainMap:
	var terrain := TERRAIN_MAP_SCRIPT.new() as TerrainMap
	terrain.columns = 84
	terrain.rows = 84
	terrain.map_origin = Vector2(-2688.0, -2688.0)
	return terrain

func _count_tiles(terrain: TerrainMap) -> Dictionary:
	var counts := {
		TerrainMap.TileType.GRASS: 0,
		TerrainMap.TileType.WATER: 0,
		TerrainMap.TileType.STONE: 0,
		TerrainMap.TileType.DIRT: 0,
		TerrainMap.TileType.SAND: 0,
		TerrainMap.TileType.DARK_GRASS: 0,
		TerrainMap.TileType.SMOOTH_STONE: 0,
		TerrainMap.TileType.CRACKED_DIRT: 0,
		TerrainMap.TileType.DRY_GRASS: 0,
		TerrainMap.TileType.DEEP_WATER: 0,
	}
	for row in terrain.tiles:
		for tile_type in row:
			counts[tile_type] = int(counts[tile_type]) + 1
	return counts

func _assert_visual_heights(terrain: TerrainMap) -> void:
	var found_lowered_water := false
	var found_raised_stone := false
	var stone_heights: Dictionary = {}
	var minimum_stone_height := minf(terrain.stone_min_height_blocks, terrain.stone_max_height_blocks)
	var maximum_stone_height := maxf(terrain.stone_min_height_blocks, terrain.stone_max_height_blocks)
	for y in range(terrain.rows):
		for x in range(terrain.columns):
			var cell := Vector2i(x, y)
			var tile_type := terrain.get_tile(cell)
			var visual_height := terrain.get_visual_height(cell)
			if tile_type in [TerrainMap.TileType.WATER, TerrainMap.TileType.DEEP_WATER] and visual_height < 0.0:
				found_lowered_water = true
			elif tile_type in [TerrainMap.TileType.STONE, TerrainMap.TileType.SMOOTH_STONE] and visual_height > 0.0:
				found_raised_stone = true
				var height_in_blocks := visual_height / terrain.tile_size
				assert(height_in_blocks >= minimum_stone_height - 0.001)
				assert(height_in_blocks <= maximum_stone_height + 0.001)
				stone_heights[snappedf(height_in_blocks, 0.01)] = true
	assert(found_lowered_water)
	assert(found_raised_stone)
	assert(stone_heights.size() > 1)

func _count_exposed_height_edges(terrain: TerrainMap) -> int:
	var exposed_edge_count := 0
	for y in range(terrain.rows):
		for x in range(terrain.columns):
			var cell := Vector2i(x, y)
			var current_height := terrain.get_visual_height(cell)
			if current_height <= 0.0:
				continue
			for normal in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				if current_height - terrain.get_visual_height(cell + normal) > 0.01:
					exposed_edge_count += 1
	return exposed_edge_count

func _assert_water_regions_are_uniform(terrain: TerrainMap) -> void:
	var visited: Dictionary = {}
	var directions: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]
	for y in range(terrain.rows):
		for x in range(terrain.columns):
			var start := Vector2i(x, y)
			var start_type := terrain.get_tile(start)
			if visited.has(start) or start_type not in [TerrainMap.TileType.WATER, TerrainMap.TileType.DEEP_WATER]:
				continue
			var frontier: Array[Vector2i] = [start]
			var frontier_index := 0
			var has_water := false
			var has_deep_water := false
			var touches_map_edge := false
			visited[start] = true
			while frontier_index < frontier.size():
				var cell := frontier[frontier_index]
				frontier_index += 1
				var tile_type := terrain.get_tile(cell)
				has_water = has_water or tile_type == TerrainMap.TileType.WATER
				has_deep_water = has_deep_water or tile_type == TerrainMap.TileType.DEEP_WATER
				if cell.x == 0 or cell.x == terrain.columns - 1 or cell.y == 0 or cell.y == terrain.rows - 1:
					touches_map_edge = true
				for direction in directions:
					var neighbor := cell + direction
					if not terrain.is_inside(neighbor) or visited.has(neighbor):
						continue
					var neighbor_type := terrain.get_tile(neighbor)
					if neighbor_type not in [TerrainMap.TileType.WATER, TerrainMap.TileType.DEEP_WATER]:
						continue
					visited[neighbor] = true
					frontier.append(neighbor)
			assert(not (has_water and has_deep_water))
			if touches_map_edge:
				assert(not has_deep_water)

func _has_traversable_edge(terrain: TerrainMap) -> bool:
	for x in range(terrain.columns):
		if terrain.is_traversable(terrain.get_tile(Vector2i(x, 0))) or terrain.is_traversable(terrain.get_tile(Vector2i(x, terrain.rows - 1))):
			return true
	for y in range(terrain.rows):
		if terrain.is_traversable(terrain.get_tile(Vector2i(0, y))) or terrain.is_traversable(terrain.get_tile(Vector2i(terrain.columns - 1, y))):
			return true
	return false
