@tool
class_name TerrainMap
extends Node2D

## Small, code-defined tile map for the first playable terrain slice.
##
## A tile is traversable when it has no physics body. Non-traversable tiles
## get one axis-aligned rectangle in the World physics layer, so CharacterBody2D
## entities can use their existing move_and_slide() movement unchanged.

enum TileType {
	GRASS,
	STONE,
	DIRT,
	WATER,
	SAND,
	DARK_GRASS,
	SMOOTH_STONE,
	CRACKED_DIRT,
	DRY_GRASS,
	DEEP_WATER,
}

@export var columns := 28
@export var rows := 16
@export var tile_size := 64.0
@export var map_origin := Vector2(-896.0, -512.0)
## Optional debug overlay; keep the shipped terrain free of cell outlines.
@export var draw_grid := false
@export var dynamic_path_avoidance := false
@export_range(1.0, 20.0, 0.5) var dynamic_path_penalty := 5.0
@export_range(0, 2, 1) var dynamic_path_reservation_radius := 1
@export_group("Layered Generation")
@export_range(0.01, 0.2, 0.005) var land_noise_frequency := 0.055
@export_range(-0.8, 0.4, 0.05) var land_threshold := -0.22
@export_range(0.0, 1.0, 0.05) var island_world_chance := 0.3
@export_range(0.0, 1.0, 0.05) var continental_edge_falloff := 0.14
@export_range(0.01, 0.3, 0.005) var stone_noise_frequency := 0.105
@export_range(0.0, 0.9, 0.05) var stone_threshold := 0.32
@export_range(0.01, 0.3, 0.005) var dirt_noise_frequency := 0.085
@export_range(-0.2, 0.9, 0.05) var dirt_threshold := 0.26
@export_range(0.01, 0.3, 0.005) var tree_noise_frequency := 0.075
@export_range(-0.4, 0.9, 0.05) var tree_threshold := 0.08
@export_range(0.0, 1.0, 0.05) var deep_water_pond_chance := 0.2
@export_range(0.05, 0.5, 0.01) var water_animation_frame_seconds := 0.35
@export_group("2.5D Terrain")
@export var draw_height_effects := true
@export_range(0.0, 24.0, 1.0) var water_depth_pixels := 10.0
@export_range(0.0, 1.0, 0.01) var stone_min_height_blocks := 0.40
@export_range(0.0, 1.0, 0.01) var stone_max_height_blocks := 1.00
@export var draw_height_shadows := true
@export_range(0.0, 0.5, 0.01) var height_shadow_alpha := 0.22
@export_range(0.0, 2.0, 0.05) var height_shadow_midday_length_blocks := 0.40
@export_range(0.0, 3.0, 0.05) var height_shadow_low_sun_length_blocks := 0.75
@export_range(0.5, 3.0, 0.05) var height_shadow_max_length_blocks := 1.10
## Kept as a compatibility/debug toggle for the pause menu. When disabled,
## terrain renders as flat colors instead of atlas textures.
@export var draw_tile_details := true

const TILE_SHEET_CELL_SIZE := 32
const MAP_BOTTOM_SIDE_RENDER_PIXELS := TILE_SHEET_CELL_SIZE

const TILE_SHEET_REGIONS := {
	# These three atlas cells are matching grass variants. The stable world-seed
	# and cell hash below select among them without terrain flicker on redraw.
	TileType.GRASS: [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)],
	TileType.STONE: [Vector2i(2, 4)],
	TileType.DIRT: [Vector2i(0, 5)],
	TileType.WATER: [Vector2i(2, 5)],
	TileType.SAND: [Vector2i(9, 4)],
	TileType.DARK_GRASS: [Vector2i(4, 3), Vector2i(5, 3)],
	TileType.SMOOTH_STONE: [Vector2i(7, 0)],
	TileType.CRACKED_DIRT: [Vector2i(8, 1)],
	TileType.DRY_GRASS: [Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2)],
	# The former primary water texture remains available for sparse deep pools.
	TileType.DEEP_WATER: [Vector2i(2, 5)],
}

const TILE_COLORS := {
	TileType.GRASS: Color("4d7c59"),
	TileType.STONE: Color("68737a"),
	TileType.DIRT: Color("9b704f"),
	TileType.WATER: Color("39779a"),
	TileType.SAND: Color("d8b668"),
	TileType.DARK_GRASS: Color("236b35"),
	TileType.SMOOTH_STONE: Color("777b7c"),
	TileType.CRACKED_DIRT: Color("6d3a1e"),
	TileType.DRY_GRASS: Color("778845"),
	TileType.DEEP_WATER: Color("1f3f67"),
}

const TILE_NAMES := {
	TileType.GRASS: "Grass",
	TileType.STONE: "Stone",
	TileType.DIRT: "Dirt",
	TileType.WATER: "Water",
	TileType.SAND: "Sand",
	TileType.DARK_GRASS: "Dark Grass",
	TileType.SMOOTH_STONE: "Smooth Stone",
	TileType.CRACKED_DIRT: "Cracked Dirt",
	TileType.DRY_GRASS: "Dry Grass",
	TileType.DEEP_WATER: "Deep Water",
}

# Projectile visibility is separate from movement. A tile can be impassable
# without becoming a line-of-sight blocker (water is the first example).
const TILE_BLOCKS_PROJECTILES := {
	TileType.GRASS: false,
	TileType.STONE: true,
	TileType.DIRT: false,
	TileType.WATER: false,
	TileType.SAND: false,
	TileType.DARK_GRASS: false,
	TileType.SMOOTH_STONE: true,
	TileType.CRACKED_DIRT: false,
	TileType.DRY_GRASS: false,
	TileType.DEEP_WATER: false,
}

const PROJECTILE_BLOCKER_LAYER := 6
const STRUCTURE_LAYER := 4
const TERRAIN_RENDER_TILE_PIXELS := TILE_SHEET_CELL_SIZE
const WORLD_DEPTH_BASE := 1000
const WORLD_DEPTH_STEP := 16.0
const ANIMATED_WATER_MARKER := Color(1.0, 0.0, 1.0, 0.5)
const ANIMATED_WATER_SIDE_MARKER := Color(1.0, 0.0, 1.0, 0.25)
const ANIMATED_WATER_SHADER := """
shader_type canvas_item;

uniform sampler2D water_sheet : filter_nearest, repeat_disable;
uniform float frame_seconds = 0.30;
uniform float water_origin_y = 0.0;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	bool is_water_marker = base.r > 0.99 && base.g < 0.01 && base.b > 0.99 && base.a > 0.45 && base.a < 0.55;
	bool is_water_side_marker = base.r > 0.99 && base.g < 0.01 && base.b > 0.99 && base.a > 0.20 && base.a < 0.30;
	if (is_water_marker || is_water_side_marker) {
		vec2 pixel = UV * vec2(textureSize(TEXTURE, 0));
		vec2 tile_uv = fract((pixel - vec2(0.0, water_origin_y)) / 32.0);
		// Give each tile a stable phase offset while keeping one shared frame
		// duration. The half-tile y offset keeps the top surface's cell index
		// stable despite the small water-depth render padding.
		vec2 tile_cell = vec2(floor(pixel.x / 32.0), floor((pixel.y - water_origin_y + 16.0) / 32.0));
		float phase = floor(fract(sin(dot(tile_cell, vec2(12.9898, 78.233))) * 43758.5453) * 5.0);
		float frame = floor(mod(TIME / max(frame_seconds, 0.001) + phase, 5.0));
		vec2 water_uv = vec2((tile_uv.x + frame) / 5.0, tile_uv.y);
		float side_shade = is_water_side_marker ? 0.62 : 1.0;
		COLOR = texture(water_sheet, water_uv) * vertex_color * side_shade;
	} else {
		COLOR = base * vertex_color;
	}
}
"""

var tiles: Array[Array] = []
var _collision_root: Node2D
var _navigation_grid := AStarGrid2D.new()
var _tile_sheet: Texture2D
var _animated_water_sheet: Texture2D
var _animated_water_material: ShaderMaterial
var _generation_seed := 0
var _world_shape_is_island := false
var _continental_open_edge := 0
var _tile_heights: Array[Array] = []
var _tree_spawn_positions: Array[Vector2] = []
var _faction_spawn_positions: Array[Vector2] = []
var _ore_spawn_positions: Array[Vector2] = []
var _terrain_render_texture: ImageTexture
var _stone_occluder_root: Node2D
var _height_shadow_layer: MultiMeshInstance2D
var _height_shadow_material: ShaderMaterial
var _terrain_render_position := Vector2.ZERO
var _terrain_render_size := Vector2.ZERO
var _cached_render_details := false
var _cached_render_heights := false

func _ready() -> void:
	RuntimeLogger.info("Terrain generation started: %dx%d tiles" % [columns, rows])
	add_to_group("terrain_maps")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tile_sheet_path := "res://assets/art/SPRITE_SHEET_1.png"
	if ResourceLoader.exists(tile_sheet_path):
		_tile_sheet = load(tile_sheet_path) as Texture2D
	var water_sheet_path := "res://assets/art/water-sheet.png"
	if ResourceLoader.exists(water_sheet_path):
		_animated_water_sheet = load(water_sheet_path) as Texture2D
	_configure_animated_water_material()
	_stone_occluder_root = Node2D.new()
	_stone_occluder_root.name = "StoneOccluders"
	add_child(_stone_occluder_root)
	_configure_height_shadow_layer()
	_generate_layered_world()
	_build_navigation_grid()
	if not Engine.is_editor_hint():
		_build_collision()
	call_deferred("_connect_height_shadows_to_day_night_cycle")
	queue_redraw()
	RuntimeLogger.info("Terrain generation complete: trees=%d ore_sites=%d" % [_tree_spawn_positions.size(), _ore_spawn_positions.size()])

func _configure_height_shadow_layer() -> void:
	_height_shadow_layer = MultiMeshInstance2D.new()
	_height_shadow_layer.name = "HeightShadows"
	_height_shadow_layer.z_as_relative = true
	_height_shadow_layer.z_index = 1
	# MultiMeshInstance2D still expects a canvas texture RID even though the
	# shadow shader generates a flat color instead of sampling artwork.
	var white_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white_image.fill(Color.WHITE)
	_height_shadow_layer.texture = ImageTexture.create_from_image(white_image)
	var shader := load("res://shaders/terrain_height_shadow.gdshader") as Shader
	if shader != null:
		_height_shadow_material = ShaderMaterial.new()
		_height_shadow_material.shader = shader
		_height_shadow_layer.material = _height_shadow_material
	add_child(_height_shadow_layer)

func _connect_height_shadows_to_day_night_cycle() -> void:
	var cycles := get_tree().get_nodes_in_group("day_night_cycles")
	if cycles.is_empty():
		_update_height_shadow_lighting(1.0, Vector2.RIGHT)
		return
	var cycle := cycles[0]
	if cycle == null or not cycle.has_method("get_daylight_amount"):
		return
	if not cycle.lighting_changed.is_connected(_update_height_shadow_lighting):
		cycle.lighting_changed.connect(_update_height_shadow_lighting)
	_update_height_shadow_lighting(cycle.get_daylight_amount(), cycle.get_sun_direction())

func _update_height_shadow_lighting(daylight: float, sun_direction: Vector2) -> void:
	if _height_shadow_layer == null or _height_shadow_material == null:
		return
	var clamped_daylight := clampf(daylight, 0.0, 1.0)
	_height_shadow_layer.visible = draw_height_effects and draw_height_shadows and clamped_daylight > 0.001
	# A tree shadow's source texture points upward before TreeDoodad rotates it.
	# Rotate the cycle vector the same quarter-turn so terrain and tree shadows
	# travel together instead of disagreeing about where north is.
	var projection_direction := sun_direction.rotated(-PI * 0.5)
	if projection_direction.is_zero_approx():
		projection_direction = Vector2.UP
	_height_shadow_material.set_shader_parameter("daylight", clamped_daylight)
	_height_shadow_material.set_shader_parameter("shadow_direction", projection_direction.normalized())

func _rebuild_height_shadows() -> void:
	if _height_shadow_layer == null:
		return
	var exposed_edges: Array[Dictionary] = []
	if draw_height_effects and draw_height_shadows:
		for y in range(rows):
			for x in range(columns):
				var cell := Vector2i(x, y)
				var current_height := get_visual_height(cell)
				if current_height <= 0.0:
					continue
				for normal in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
					var neighbor_height := get_visual_height(cell + normal)
					var exposed_height := current_height - neighbor_height
					if exposed_height <= 0.01:
						continue
					var edge_center := cell_to_world(cell) + Vector2.ONE * tile_size * 0.5
					edge_center += Vector2(normal) * tile_size * 0.5
					# Raised surfaces are rendered north by their visual height. Anchor
					# the shadow to that visible perimeter instead of the logical cell,
					# so the stone row no longer has to be cleared by a long hidden cast.
					edge_center -= Vector2(0.0, current_height)
					exposed_edges.append({
						"position": edge_center,
						"height_blocks": exposed_height / maxf(tile_size, 1.0),
						"normal": Vector2(normal),
					})

	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_custom_data = true
	var quad := QuadMesh.new()
	var maximum_projection := tile_size * height_shadow_max_length_blocks
	# The source mesh only establishes a conservative visibility bound; the
	# vertex shader reshapes it into the actual sun-facing projection.
	quad.size = Vector2.ONE * (tile_size + maximum_projection * 2.0)
	instances.mesh = quad
	instances.instance_count = exposed_edges.size()
	for index in range(exposed_edges.size()):
		var edge: Dictionary = exposed_edges[index]
		var edge_normal: Vector2 = edge["normal"]
		instances.set_instance_transform_2d(index, Transform2D(0.0, edge["position"]))
		# RGBA carries exposed height and the outward edge normal. The shader
		# activates only edges facing the current projection direction.
		instances.set_instance_custom_data(index, Color(edge["height_blocks"], edge_normal.x, edge_normal.y, 1.0))
	_height_shadow_layer.multimesh = instances
	_height_shadow_layer.visible = draw_height_effects and draw_height_shadows
	if _height_shadow_material != null:
		_height_shadow_material.set_shader_parameter("tile_size", tile_size)
		_height_shadow_material.set_shader_parameter("shadow_alpha", height_shadow_alpha)
		_height_shadow_material.set_shader_parameter("midday_length_blocks", height_shadow_midday_length_blocks)
		_height_shadow_material.set_shader_parameter("low_sun_length_blocks", height_shadow_low_sun_length_blocks)
		_height_shadow_material.set_shader_parameter("max_shadow_length", maximum_projection)

func _configure_animated_water_material() -> void:
	if _animated_water_sheet == null:
		_animated_water_material = null
		material = null
		return
	var water_shader := Shader.new()
	water_shader.code = ANIMATED_WATER_SHADER
	_animated_water_material = ShaderMaterial.new()
	_animated_water_material.shader = water_shader
	_animated_water_material.set_shader_parameter("water_sheet", _animated_water_sheet)
	_animated_water_material.set_shader_parameter("frame_seconds", water_animation_frame_seconds)
	material = _animated_water_material

func _generate_layered_world() -> void:
	_generation_seed = _get_active_world_seed()
	_tree_spawn_positions.clear()
	_faction_spawn_positions.clear()
	_ore_spawn_positions.clear()

	var land_noise := _make_noise(_generation_seed ^ 0x4C414E, land_noise_frequency, 4)
	var detail_noise := _make_noise(_generation_seed ^ 0x454C56, land_noise_frequency * 2.1, 2)
	var stone_noise := _make_noise(_generation_seed ^ 0x53544E, stone_noise_frequency, 3)
	var dirt_noise := _make_noise(_generation_seed ^ 0x444952, dirt_noise_frequency, 3)
	var surface_noise := _make_noise(_generation_seed ^ 0x535246, 0.095, 3)
	var dry_grass_noise := _make_noise(_generation_seed ^ 0x445259, 0.072, 3)
	var tree_noise := _make_noise(_generation_seed ^ 0x545245, tree_noise_frequency, 3)
	var ore_noise := _make_noise(_generation_seed ^ 0x4F5245, 0.065, 3)
	var shape_random := RandomNumberGenerator.new()
	shape_random.seed = _generation_seed ^ 0x534850
	_world_shape_is_island = shape_random.randf() < island_world_chance
	_continental_open_edge = shape_random.randi_range(0, 3)
	var random := RandomNumberGenerator.new()
	random.seed = _generation_seed ^ 0x574F52

	_generate_land_water_layer(land_noise, detail_noise)
	_generate_deep_water_layer()
	_generate_sand_layer(surface_noise)
	_generate_stone_layer(stone_noise, surface_noise)
	_generate_dirt_layer(dirt_noise, surface_noise)
	_generate_dark_grass_layer(surface_noise)
	_generate_dry_grass_layer(dry_grass_noise)
	_generate_visual_height_layer()
	_generate_tree_layer(tree_noise, random)
	_shuffle_positions(_tree_spawn_positions, random)
	_generate_faction_spawn_layer()
	_prune_tree_positions_near(_faction_spawn_positions, tile_size * 3.0)
	_generate_ore_layer(ore_noise, random)
	_prune_tree_positions_near(_ore_spawn_positions, tile_size * 1.5)

func _make_noise(seed_value: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.52
	noise.fractal_lacunarity = 2.0
	return noise

func _generate_land_water_layer(land_noise: FastNoiseLite, detail_noise: FastNoiseLite) -> void:
	tiles.clear()
	for y in range(rows):
		var row: Array = []
		for x in range(columns):
			var normalized_x := absf((float(x) + 0.5) / float(columns) * 2.0 - 1.0)
			var normalized_y := absf((float(y) + 0.5) / float(rows) * 2.0 - 1.0)
			var edge_distance := maxf(normalized_x, normalized_y)
			var edge_strength := 1.05 if _world_shape_is_island else continental_edge_falloff
			var edge_falloff := smoothstep(0.72, 1.0, edge_distance) * edge_strength
			var elevation := land_noise.get_noise_2d(float(x), float(y)) * 0.78
			elevation += detail_noise.get_noise_2d(float(x), float(y)) * 0.22
			if not _world_shape_is_island:
				var open_edge_distance := _distance_to_open_edge(x, y)
				elevation += (1.0 - smoothstep(0.0, 0.42, open_edge_distance)) * 0.38
			elevation -= edge_falloff
			row.append(TileType.GRASS if elevation >= land_threshold else TileType.WATER)
		tiles.append(row)

	# Guarantee a usable central landmass even for an unusually wet seed.
	var center := Vector2i(columns / 2, rows / 2)
	for y in range(-2, 3):
		for x in range(-3, 4):
			_set_tile(center + Vector2i(x, y), TileType.GRASS)

func _generate_deep_water_layer() -> void:
	var source_tiles := tiles.duplicate(true)
	var visited: Dictionary = {}
	var directions: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]
	for y in range(rows):
		for x in range(columns):
			var start := Vector2i(x, y)
			if visited.has(start) or source_tiles[y][x] != TileType.WATER:
				continue
			var region: Array[Vector2i] = []
			var frontier: Array[Vector2i] = [start]
			var frontier_index := 0
			var touches_map_edge := false
			visited[start] = true
			while frontier_index < frontier.size():
				var current := frontier[frontier_index]
				frontier_index += 1
				region.append(current)
				if current.x == 0 or current.x == columns - 1 or current.y == 0 or current.y == rows - 1:
					touches_map_edge = true
				for direction in directions:
					var neighbor := current + direction
					if not is_inside(neighbor) or visited.has(neighbor):
						continue
					if source_tiles[neighbor.y][neighbor.x] != TileType.WATER:
						continue
					visited[neighbor] = true
					frontier.append(neighbor)

			# Any connected water touching the map boundary is ocean/coast and can
			# never become legacy deep water. Only enclosed ponds and lakes qualify.
			if touches_map_edge or region.size() < 4:
				continue
			var pond_random := RandomNumberGenerator.new()
			pond_random.seed = _generation_seed ^ (start.x * 92821 + start.y * 68917 + region.size() * 31337)
			if pond_random.randf() > deep_water_pond_chance:
				continue
			for cell in region:
				_set_tile(cell, TileType.DEEP_WATER)

func _distance_to_open_edge(x: int, y: int) -> float:
	match _continental_open_edge:
		0:
			return float(x) / maxf(float(columns - 1), 1.0)
		1:
			return float(columns - 1 - x) / maxf(float(columns - 1), 1.0)
		2:
			return float(y) / maxf(float(rows - 1), 1.0)
		_:
			return float(rows - 1 - y) / maxf(float(rows - 1), 1.0)

func _generate_sand_layer(noise: FastNoiseLite) -> void:
	var source_tiles := tiles.duplicate(true)
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			if source_tiles[y][x] != TileType.GRASS or not _has_neighboring_water(source_tiles, cell, 1):
				continue
			if noise.get_noise_2d(float(x + 193), float(y - 71)) >= -0.3:
				_set_tile(cell, TileType.SAND)

func _generate_stone_layer(noise: FastNoiseLite, variant_noise: FastNoiseLite) -> void:
	var source_tiles := tiles.duplicate(true)
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			var value := noise.get_noise_2d(float(x), float(y))
			var tile_type: int = source_tiles[y][x]
			var stone_type := TileType.SMOOTH_STONE if variant_noise.get_noise_2d(float(x - 211), float(y + 97)) >= 0.0 else TileType.STONE
			if _is_open_land_tile(tile_type) and value >= stone_threshold:
				_set_tile(cell, stone_type)
			elif _is_water_tile(tile_type) and value >= stone_threshold + 0.16 and _has_neighboring_land(source_tiles, cell, 2):
				_set_tile(cell, stone_type)

func _has_neighboring_land(source_tiles: Array, cell: Vector2i, radius: int) -> bool:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var neighbor := cell + Vector2i(x, y)
			if is_inside(neighbor) and _is_open_land_tile(source_tiles[neighbor.y][neighbor.x]):
				return true
	return false

func _has_neighboring_water(source_tiles: Array, cell: Vector2i, radius: int) -> bool:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var neighbor := cell + Vector2i(x, y)
			if is_inside(neighbor) and _is_water_tile(source_tiles[neighbor.y][neighbor.x]):
				return true
	return false

func _generate_dirt_layer(noise: FastNoiseLite, variant_noise: FastNoiseLite) -> void:
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			if get_tile(cell) == TileType.GRASS and noise.get_noise_2d(float(x), float(y)) >= dirt_threshold:
				var dirt_type := TileType.CRACKED_DIRT if variant_noise.get_noise_2d(float(x + 149), float(y + 233)) >= 0.08 else TileType.DIRT
				_set_tile(cell, dirt_type)

func _generate_dark_grass_layer(noise: FastNoiseLite) -> void:
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			if get_tile(cell) == TileType.GRASS and noise.get_noise_2d(float(x - 317), float(y - 181)) >= 0.18:
				_set_tile(cell, TileType.DARK_GRASS)

func _generate_dry_grass_layer(noise: FastNoiseLite) -> void:
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			# Roughly half of the remaining ordinary grass becomes broad, seeded
			# dry-grass regions, keeping both common ground types similarly visible.
			if get_tile(cell) == TileType.GRASS and noise.get_noise_2d(float(x), float(y)) >= 0.0:
				_set_tile(cell, TileType.DRY_GRASS)

func _generate_visual_height_layer() -> void:
	_tile_heights.clear()
	var minimum_height_step := ceili(minf(stone_min_height_blocks, stone_max_height_blocks) * 100.0)
	var maximum_height_step := floori(maxf(stone_min_height_blocks, stone_max_height_blocks) * 100.0)
	var height_random := RandomNumberGenerator.new()
	height_random.seed = _generation_seed ^ 0x484754
	for y in range(rows):
		var height_row: Array = []
		for x in range(columns):
			var tile_type := get_tile(Vector2i(x, y))
			var height := 0.0
			if _is_water_tile(tile_type):
				height = -water_depth_pixels
			elif _is_stone_tile(tile_type):
				var height_step := height_random.randi_range(minimum_height_step, maximum_height_step)
				height = tile_size * float(height_step) / 100.0
			height_row.append(height)
		_tile_heights.append(height_row)

func _generate_tree_layer(noise: FastNoiseLite, random: RandomNumberGenerator) -> void:
	var maximum_candidates := maxi(48, (columns * rows) / 8)
	var minimum_spacing := tile_size * 1.35
	for y in range(1, rows - 1):
		for x in range(1, columns - 1):
			if _tree_spawn_positions.size() >= maximum_candidates:
				return
			var cell := Vector2i(x, y)
			if not is_tree_surface(get_tile(cell)):
				continue
			var density := noise.get_noise_2d(float(x), float(y))
			if density < tree_threshold or random.randf() > 0.58:
				continue
			var position := cell_to_world(cell) + Vector2.ONE * tile_size * 0.5
			position += Vector2(random.randf_range(-0.28, 0.28), random.randf_range(-0.28, 0.28)) * tile_size
			if _position_is_spaced(position, _tree_spawn_positions, minimum_spacing):
				_tree_spawn_positions.append(position)

func _generate_faction_spawn_layer() -> void:
	var region := _largest_traversable_region()
	if region.is_empty():
		return
	var center_y := float(rows - 1) * 0.5
	var left_cell := region[0]
	var right_cell := region[0]
	var left_score := INF
	var right_score := INF
	for cell in region:
		if not _cell_has_open_radius(cell, 1):
			continue
		var vertical_penalty := absf(float(cell.y) - center_y) * 0.35
		var candidate_left_score := float(cell.x) + vertical_penalty
		var candidate_right_score := float(columns - 1 - cell.x) + vertical_penalty
		if candidate_left_score < left_score:
			left_score = candidate_left_score
			left_cell = cell
		if candidate_right_score < right_score:
			right_score = candidate_right_score
			right_cell = cell
	_faction_spawn_positions.append(cell_to_world(left_cell) + Vector2.ONE * tile_size * 0.5)
	_faction_spawn_positions.append(cell_to_world(right_cell) + Vector2.ONE * tile_size * 0.5)

func _generate_ore_layer(noise: FastNoiseLite, random: RandomNumberGenerator) -> void:
	var candidates: Array[Dictionary] = []
	for cell in _largest_traversable_region():
		if not _cell_has_open_radius(cell, 1):
			continue
		var position := cell_to_world(cell) + Vector2.ONE * tile_size * 0.5
		if not _position_is_spaced(position, _faction_spawn_positions, tile_size * 4.0):
			continue
		candidates.append({"cell": cell, "score": noise.get_noise_2d(float(cell.x), float(cell.y)) + random.randf_range(-0.08, 0.08)})
	candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first["score"]) > float(second["score"])
	)
	for candidate in candidates:
		if _ore_spawn_positions.size() >= 12:
			break
		var cell: Vector2i = candidate["cell"]
		var position := cell_to_world(cell) + Vector2.ONE * tile_size * 0.5
		if _position_is_spaced(position, _ore_spawn_positions, tile_size * 4.0):
			_ore_spawn_positions.append(position)

func _largest_traversable_region() -> Array[Vector2i]:
	var visited: Dictionary = {}
	var largest: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for y in range(rows):
		for x in range(columns):
			var start := Vector2i(x, y)
			if visited.has(start) or not is_traversable(get_tile(start)):
				continue
			var region: Array[Vector2i] = []
			var frontier: Array[Vector2i] = [start]
			visited[start] = true
			var frontier_index := 0
			while frontier_index < frontier.size():
				var current := frontier[frontier_index]
				frontier_index += 1
				region.append(current)
				for direction in directions:
					var neighbor := current + direction
					if visited.has(neighbor) or not is_inside(neighbor) or not is_traversable(get_tile(neighbor)):
						continue
					visited[neighbor] = true
					frontier.append(neighbor)
			if region.size() > largest.size():
				largest = region
	return largest

func _cell_has_open_radius(center: Vector2i, radius: int) -> bool:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var cell := center + Vector2i(x, y)
			if not is_inside(cell) or not is_traversable(get_tile(cell)):
				return false
	return true

func _position_is_spaced(position: Vector2, existing: Array[Vector2], minimum_spacing: float) -> bool:
	for other in existing:
		if position.distance_to(other) < minimum_spacing:
			return false
	return true

func _shuffle_positions(positions: Array[Vector2], random: RandomNumberGenerator) -> void:
	for index in range(positions.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var held := positions[index]
		positions[index] = positions[swap_index]
		positions[swap_index] = held

func _prune_tree_positions_near(positions: Array[Vector2], radius: float) -> void:
	var filtered: Array[Vector2] = []
	for tree_position in _tree_spawn_positions:
		if _position_is_spaced(tree_position, positions, radius):
			filtered.append(tree_position)
	_tree_spawn_positions = filtered

func get_tree_spawn_positions(maximum_count: int = -1) -> Array[Vector2]:
	return _copy_positions(_tree_spawn_positions, maximum_count)

func get_faction_spawn_positions(maximum_count: int = -1) -> Array[Vector2]:
	return _copy_positions(_faction_spawn_positions, maximum_count)

func get_ore_spawn_positions(maximum_count: int = -1) -> Array[Vector2]:
	return _copy_positions(_ore_spawn_positions, maximum_count)

func is_island_world() -> bool:
	return _world_shape_is_island

func _copy_positions(source: Array[Vector2], maximum_count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var count := source.size() if maximum_count < 0 else mini(maximum_count, source.size())
	for index in range(count):
		result.append(source[index])
	return result

func _get_active_world_seed() -> int:
	var seed_provider := get_node_or_null("/root/WorldSeed")
	return 0 if seed_provider == null else int(seed_provider.call("get_seed"))

func _build_navigation_grid() -> void:
	_navigation_grid.region = Rect2i(0, 0, columns, rows)
	_navigation_grid.cell_size = Vector2.ONE * tile_size
	_navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_navigation_grid.update()

	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			_navigation_grid.set_point_solid(cell, not is_traversable(tiles[y][x]))

func _build_collision() -> void:
	_collision_root = Node2D.new()
	_collision_root.name = "TileCollisions"
	add_child(_collision_root)
	_add_map_boundaries()

	for y in range(rows):
		for x in range(columns):
			var tile_type: int = tiles[y][x]
			if is_traversable(tile_type):
				continue
			_add_blocking_tile(Vector2i(x, y), tile_type)

func _add_map_boundaries() -> void:
	var bounds := Rect2(map_origin, Vector2(columns, rows) * tile_size)
	var wall_thickness := tile_size
	_add_boundary("MapBoundaryLeft", Vector2(bounds.position.x - wall_thickness * 0.5, bounds.position.y + bounds.size.y * 0.5), Vector2(wall_thickness, bounds.size.y + wall_thickness * 2.0))
	_add_boundary("MapBoundaryRight", Vector2(bounds.end.x + wall_thickness * 0.5, bounds.position.y + bounds.size.y * 0.5), Vector2(wall_thickness, bounds.size.y + wall_thickness * 2.0))
	_add_boundary("MapBoundaryTop", Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y - wall_thickness * 0.5), Vector2(bounds.size.x, wall_thickness))
	_add_boundary("MapBoundaryBottom", Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.end.y + wall_thickness * 0.5), Vector2(bounds.size.x, wall_thickness))

func _add_boundary(boundary_name: String, boundary_position: Vector2, boundary_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = boundary_name
	body.collision_layer = 1 # World
	body.collision_mask = 0
	body.position = boundary_position
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = boundary_size
	shape.shape = rectangle
	body.add_child(shape)
	_collision_root.add_child(body)

func _add_blocking_tile(cell: Vector2i, tile_type: int) -> void:
	var body := StaticBody2D.new()
	body.name = "%s_%d_%d" % [tile_name(tile_type), cell.x, cell.y]
	body.collision_layer = 1 # World
	if blocks_projectiles(tile_type):
		body.collision_layer |= 1 << (PROJECTILE_BLOCKER_LAYER - 1)
	body.collision_mask = 0
	body.position = cell_to_world(cell) + Vector2.ONE * tile_size * 0.5

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2.ONE * tile_size
	shape.shape = rectangle
	body.add_child(shape)
	_collision_root.add_child(body)

func _draw() -> void:
	if _terrain_render_texture == null or _cached_render_details != draw_tile_details or _cached_render_heights != draw_height_effects:
		_rebuild_terrain_render_texture()
	if _terrain_render_texture != null:
		draw_texture_rect(
			_terrain_render_texture,
			Rect2(_terrain_render_position, _terrain_render_size),
			false
		)
	if not draw_grid:
		return
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			var logical_rect := Rect2(cell_to_world(cell), Vector2.ONE * tile_size)
			var visual_height := get_visual_height(cell) if draw_height_effects else 0.0
			var surface_rect := Rect2(logical_rect.position - Vector2(0.0, visual_height), logical_rect.size)
			draw_rect(surface_rect, Color(0.06, 0.09, 0.10, 0.28), false, 1.0)

func _rebuild_terrain_render_texture() -> void:
	_cached_render_details = draw_tile_details
	_cached_render_heights = draw_height_effects
	var pixels_per_world_unit := float(TERRAIN_RENDER_TILE_PIXELS) / tile_size
	var maximum_stone_height := maxf(stone_min_height_blocks, stone_max_height_blocks) * tile_size
	var top_padding := ceili(maximum_stone_height * pixels_per_world_unit) if draw_height_effects else 0
	var bottom_padding := ceili(water_depth_pixels * pixels_per_world_unit) if draw_height_effects else 0
	# Leave room for a full textured side below the final map row.
	bottom_padding += MAP_BOTTOM_SIDE_RENDER_PIXELS
	var image_size := Vector2i(
		columns * TERRAIN_RENDER_TILE_PIXELS,
		rows * TERRAIN_RENDER_TILE_PIXELS + top_padding + bottom_padding
	)
	var terrain_image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	terrain_image.fill(Color.TRANSPARENT)
	var atlas_image: Image = _tile_sheet.get_image() if _tile_sheet != null else null

	# Rasterize back-to-front once. South-facing elevation boundaries are drawn
	# before their top surfaces, and the following row naturally covers any
	# hidden portion. This avoids the full backing rectangles that caused the
	# giant striped slabs and reduces the live terrain to one canvas draw call.
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			var tile_type: int = tiles[y][x]
			var height_pixels := _visual_height_to_render_pixels(get_visual_height(cell)) if draw_height_effects else 0
			var tile_image := _make_tile_image(atlas_image, cell, tile_type)
			_rasterize_height_face(terrain_image, tile_image, cell, tile_type, height_pixels, top_padding)
			_rasterize_tile_surface(terrain_image, tile_image, cell, tile_type, height_pixels, top_padding)

	_terrain_render_texture = ImageTexture.create_from_image(terrain_image)
	var world_units_per_pixel := tile_size / float(TERRAIN_RENDER_TILE_PIXELS)
	_terrain_render_position = map_origin - Vector2(0.0, float(top_padding) * world_units_per_pixel)
	_terrain_render_size = Vector2(image_size) * world_units_per_pixel
	_rebuild_stone_occluder_rows(atlas_image, top_padding, world_units_per_pixel)
	_rebuild_height_shadows()
	if _animated_water_material != null:
		var animated_water_height := _visual_height_to_render_pixels(-water_depth_pixels) if draw_height_effects else 0
		_animated_water_material.set_shader_parameter("water_origin_y", float(top_padding - animated_water_height))
		_animated_water_material.set_shader_parameter("frame_seconds", water_animation_frame_seconds)

func _rebuild_stone_occluder_rows(atlas_image: Image, top_padding: int, world_units_per_pixel: float) -> void:
	if _stone_occluder_root == null:
		return
	for child in _stone_occluder_root.get_children():
		_stone_occluder_root.remove_child(child)
		child.queue_free()

	# One cached sprite per occupied stone row lets Godot interleave terrain,
	# trees, and entities by their ground-contact Y. This is the row-rendering
	# equivalent of a traditional bottom-up world draw without sorting tiles or
	# rebuilding textures every frame.
	for y in range(rows):
		var minimum_x := columns
		var maximum_x := -1
		var minimum_render_y := 2147483647
		var maximum_render_y := -2147483648
		for x in range(columns):
			var cell := Vector2i(x, y)
			if not _is_stone_tile(get_tile(cell)):
				continue
			minimum_x = mini(minimum_x, x)
			maximum_x = maxi(maximum_x, x)
			var height_pixels := _visual_height_to_render_pixels(get_visual_height(cell)) if draw_height_effects else 0
			var surface_top := top_padding + y * TERRAIN_RENDER_TILE_PIXELS - height_pixels
			var surface_bottom := surface_top + TERRAIN_RENDER_TILE_PIXELS
			var south_cell := cell + Vector2i.DOWN
			var south_height := _south_height_render_pixels(south_cell)
			var face_bottom := top_padding + (y + 1) * TERRAIN_RENDER_TILE_PIXELS - south_height
			minimum_render_y = mini(minimum_render_y, surface_top)
			maximum_render_y = maxi(maximum_render_y, maxi(surface_bottom, face_bottom))
		if maximum_x < minimum_x:
			continue

		var render_offset := Vector2i(minimum_x * TERRAIN_RENDER_TILE_PIXELS, minimum_render_y)
		var row_image_size := Vector2i(
			(maximum_x - minimum_x + 1) * TERRAIN_RENDER_TILE_PIXELS,
			maximum_render_y - minimum_render_y
		)
		var row_image := Image.create(row_image_size.x, row_image_size.y, false, Image.FORMAT_RGBA8)
		row_image.fill(Color.TRANSPARENT)
		for x in range(minimum_x, maximum_x + 1):
			var cell := Vector2i(x, y)
			var tile_type := get_tile(cell)
			if not _is_stone_tile(tile_type):
				continue
			var height_pixels := _visual_height_to_render_pixels(get_visual_height(cell)) if draw_height_effects else 0
			var tile_image := _make_tile_image(atlas_image, cell, tile_type)
			_rasterize_height_face(row_image, tile_image, cell, tile_type, height_pixels, top_padding, render_offset)
			_rasterize_tile_surface(row_image, tile_image, cell, tile_type, height_pixels, top_padding, render_offset)

		var row_sprite := Sprite2D.new()
		row_sprite.name = "StoneRow_%d" % y
		row_sprite.centered = false
		row_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row_sprite.texture = ImageTexture.create_from_image(row_image)
		row_sprite.position = _terrain_render_position + Vector2(render_offset) * world_units_per_pixel
		row_sprite.scale = Vector2.ONE * world_units_per_pixel
		row_sprite.z_as_relative = true
		row_sprite.z_index = WORLD_DEPTH_BASE + floori((map_origin.y + float(y + 1) * tile_size) / WORLD_DEPTH_STEP)
		_stone_occluder_root.add_child(row_sprite)

func _rasterize_height_face(image: Image, tile_image: Image, cell: Vector2i, tile_type: int, height_pixels: int, top_padding: int, render_offset := Vector2i.ZERO) -> void:
	if not draw_height_effects:
		return
	var south_cell := cell + Vector2i.DOWN
	var south_height_pixels := _south_height_render_pixels(south_cell)
	if height_pixels <= south_height_pixels:
		return
	var face_top := top_padding + (cell.y + 1) * TERRAIN_RENDER_TILE_PIXELS - height_pixels
	var face_bottom := top_padding + (cell.y + 1) * TERRAIN_RENDER_TILE_PIXELS - south_height_pixels
	var face_rect := Rect2i(
		cell.x * TERRAIN_RENDER_TILE_PIXELS - render_offset.x,
		face_top - render_offset.y,
		TERRAIN_RENDER_TILE_PIXELS,
		face_bottom - face_top
	)
	var face_color := tile_color(tile_type).darkened(0.42)
	if draw_tile_details and tile_type == TileType.WATER and _animated_water_sheet != null:
		# Keep side water on the same animated sheet as the top surface.
		image.fill_rect(face_rect, ANIMATED_WATER_SIDE_MARKER)
		return
	if tile_image == null or face_rect.size.y <= 0:
		image.fill_rect(face_rect, face_color)
	else:
		# Project the complete tile texture onto the vertical face. Scale the
		# source vertically instead of repeating it: repeating a 32px top-down
		# texture was what created the conspicuous chopped strips at tile edges.
		for face_y in range(face_rect.size.y):
			var source_y := mini(
				floori(float(face_y) * float(tile_image.get_height()) / float(face_rect.size.y)),
				tile_image.get_height() - 1
			)
			for face_x in range(face_rect.size.x):
				var source_x := mini(
					floori(float(face_x) * float(tile_image.get_width()) / float(face_rect.size.x)),
					tile_image.get_width() - 1
				)
				var texel := tile_image.get_pixel(source_x, source_y).darkened(0.42)
				if face_y == 0:
					texel = texel.lightened(0.07)
				elif face_y == face_rect.size.y - 1:
					texel = texel.darkened(0.12)
				image.set_pixel(face_rect.position.x + face_x, face_rect.position.y + face_y, texel)

func _rasterize_tile_surface(image: Image, tile_image: Image, cell: Vector2i, tile_type: int, height_pixels: int, top_padding: int, render_offset := Vector2i.ZERO) -> void:
	var destination := Vector2i(
		cell.x * TERRAIN_RENDER_TILE_PIXELS - render_offset.x,
		top_padding + cell.y * TERRAIN_RENDER_TILE_PIXELS - height_pixels - render_offset.y
	)
	if draw_tile_details and tile_type == TileType.WATER and _animated_water_sheet != null:
		image.fill_rect(Rect2i(destination, Vector2i.ONE * TERRAIN_RENDER_TILE_PIXELS), ANIMATED_WATER_MARKER)
		return
	if tile_image == null:
		image.fill_rect(Rect2i(destination, Vector2i.ONE * TERRAIN_RENDER_TILE_PIXELS), tile_color(tile_type))
		return
	image.blit_rect(tile_image, Rect2i(Vector2i.ZERO, tile_image.get_size()), destination)

func _make_tile_image(atlas_image: Image, cell: Vector2i, tile_type: int) -> Image:
	var regions: Array = TILE_SHEET_REGIONS.get(tile_type, [])
	if not draw_tile_details or atlas_image == null or regions.is_empty():
		return null
	# Hash the complete cell identity instead of reducing a linear x/y sum. The
	# old modulo pattern repeated along diagonals, which was especially obvious
	# whenever the dry-grass variant containing the small rock was selected.
	var variation_hash := hash(Vector4i(cell.x, cell.y, tile_type, _generation_seed))
	var atlas_cell: Vector2i = regions[posmod(variation_hash, regions.size())]
	var source_rect := Rect2i(atlas_cell * TILE_SHEET_CELL_SIZE, Vector2i.ONE * TILE_SHEET_CELL_SIZE)
	var tile_image := atlas_image.get_region(source_rect)
	return tile_image

func _visual_height_to_render_pixels(visual_height: float) -> int:
	return roundi(visual_height * float(TERRAIN_RENDER_TILE_PIXELS) / tile_size)

func _south_height_render_pixels(cell: Vector2i) -> int:
	if not is_inside(cell):
		return -MAP_BOTTOM_SIDE_RENDER_PIXELS
	return _visual_height_to_render_pixels(get_visual_height(cell)) if draw_height_effects else 0

func cell_to_world(cell: Vector2i) -> Vector2:
	return map_origin + Vector2(cell) * tile_size

func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori((world_position.x - map_origin.x) / tile_size), floori((world_position.y - map_origin.y) / tile_size))

func clamp_entity_position(world_position: Vector2, clearance: float) -> Vector2:
	var map_size := Vector2(columns, rows) * tile_size
	var minimum := map_origin + Vector2.ONE * clearance
	var maximum := map_origin + map_size - Vector2.ONE * clearance
	return Vector2(clampf(world_position.x, minimum.x, maximum.x), clampf(world_position.y, minimum.y, maximum.y))

func find_path(from_world: Vector2, to_world: Vector2, clearance: float = 12.0, requester: Entity = null, profile_reason: StringName = &"") -> Array[Vector2]:
	if not DeepProfiler.is_enabled():
		return _find_path_impl(from_world, to_world, clearance, requester)
	var started_usec := Time.get_ticks_usec()
	var path := _find_path_impl(from_world, to_world, clearance, requester)
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	DeepProfiler.record_timing("navigation.find_path", elapsed_usec, requester)
	DeepProfiler.increment("navigation.find_path_requests")
	DeepProfiler.increment("navigation.path_points_returned", path.size())
	if not profile_reason.is_empty():
		DeepProfiler.record_timing(StringName("navigation.find_path.%s" % profile_reason), elapsed_usec, requester, false)
	return path

func _find_path_impl(from_world: Vector2, to_world: Vector2, clearance: float, requester: Entity) -> Array[Vector2]:
	var start_cell := world_to_cell(from_world)
	var goal_cell := world_to_cell(to_world)
	var path: Array[Vector2] = []
	var reserved_cells := _apply_dynamic_path_penalties(requester)

	if not is_inside(start_cell):
		_clear_dynamic_path_penalties(reserved_cells)
		return path
	var goal_position := to_world
	if not is_inside(goal_cell) or not is_traversable(get_tile(goal_cell)):
		var fallback_goal := _find_closest_reachable_goal(start_cell, to_world, clearance)
		if fallback_goal.is_empty():
			_clear_dynamic_path_penalties(reserved_cells)
			return path
		goal_cell = fallback_goal["cell"]
		goal_position = fallback_goal["position"]

	# Most movement on open terrain needs no A* search at all. This also avoids
	# feeding dozens of unnecessary tile centers into the smoothing pass.
	if _line_is_clear(from_world, goal_position, clearance):
		_clear_dynamic_path_penalties(reserved_cells)
		return [goal_position]

	var cell_path := _navigation_grid.get_id_path(start_cell, goal_cell)
	if cell_path.is_empty():
		var fallback_goal := _find_closest_reachable_goal(start_cell, to_world, clearance)
		if fallback_goal.is_empty():
			_clear_dynamic_path_penalties(reserved_cells)
			return path
		goal_cell = fallback_goal["cell"]
		goal_position = fallback_goal["position"]
		cell_path = _navigation_grid.get_id_path(start_cell, goal_cell)
		if cell_path.is_empty():
			_clear_dynamic_path_penalties(reserved_cells)
			return path

	var route_points: Array[Vector2] = []
	for index in range(1, cell_path.size() - 1):
		var current_cell := Vector2i(cell_path[index])
		var current_center := cell_to_world(current_cell) + Vector2.ONE * tile_size * 0.5
		var previous_cell := Vector2i(cell_path[index - 1])
		var next_cell := Vector2i(cell_path[index + 1])
		var incoming := current_cell - previous_cell
		var outgoing := next_cell - current_cell
		if incoming == outgoing:
			continue

		# At a turn, the diagonal cell toward the inside of the turn is
		# normally the obstacle we are rounding. Place the waypoint near
		# that corner instead of at the center of the current cell.
		if incoming.x * outgoing.x + incoming.y * outgoing.y == 0:
			var inside_direction := -incoming + outgoing
			var inside_cell := current_cell + inside_direction
			if is_inside(inside_cell) and not is_traversable(get_tile(inside_cell)):
				var corner_direction := Vector2(inside_direction).normalized()
				var corner_distance := maxf(0.0, tile_size * 0.5 - clearance)
				# inside_direction points toward the blocked diagonal cell. Offset
				# toward the opposite corner so the unit rounds the obstacle instead
				# of stopping on its water/terrain corner.
				route_points.append(current_center - corner_direction * corner_distance)
				continue

		route_points.append(current_center)

	# Remove unnecessary tile-center waypoints. The grid still routes around
	# obstacles, but open terrain can be crossed in a single natural movement.
	var anchor := from_world
	for index in range(route_points.size()):
		var candidate := route_points[index]
		if not _line_is_clear(anchor, candidate, clearance):
			var corner := route_points[maxi(0, index - 1)]
			if anchor.distance_to(corner) > 1.0:
				path.append(corner)
			anchor = corner

	if route_points.is_empty():
		path.append(goal_position)
	elif _line_is_clear(anchor, goal_position, clearance):
		path.append(goal_position)
	else:
		path.append(route_points[route_points.size() - 1])
		if path.back().distance_to(goal_position) > 1.0:
			path.append(goal_position)
	_clear_dynamic_path_penalties(reserved_cells)
	return path

func _apply_dynamic_path_penalties(requester: Entity) -> Array[Vector2i]:
	var reserved_cells: Array[Vector2i] = []
	if not dynamic_path_avoidance:
		return reserved_cells
	for candidate in get_tree().get_nodes_in_group("entities"):
		if candidate == requester or not candidate is Entity:
			continue
		var movement := (candidate as Entity).get_component(MovementComponent) as MovementComponent
		if movement == null:
			continue
		var planned_path := movement.get_navigation_path()
		if planned_path.size() < 2:
			continue
		for path_index in range(1, planned_path.size()):
			var path_point := planned_path[path_index]
			# Preserve the final approach lane; penalize the shared travel corridor
			# rather than making units fight over the exact destination cell.
			if path_index == planned_path.size() - 1:
				continue
			var cell := world_to_cell(path_point)
			for y in range(-dynamic_path_reservation_radius, dynamic_path_reservation_radius + 1):
				for x in range(-dynamic_path_reservation_radius, dynamic_path_reservation_radius + 1):
					var reserved_cell := cell + Vector2i(x, y)
					if not is_inside(reserved_cell) or not is_traversable(get_tile(reserved_cell)) or reserved_cells.has(reserved_cell):
						continue
					reserved_cells.append(reserved_cell)
					_navigation_grid.set_point_weight_scale(reserved_cell, dynamic_path_penalty)
	return reserved_cells

func _clear_dynamic_path_penalties(reserved_cells: Array[Vector2i]) -> void:
	for cell in reserved_cells:
		_navigation_grid.set_point_weight_scale(cell, 1.0)

func _find_closest_reachable_goal(start_cell: Vector2i, target: Vector2, clearance: float) -> Dictionary:
	var closest_position := Vector2.ZERO
	var closest_cell := Vector2i.ZERO
	var closest_distance := INF

	# The map is intentionally small, so checking every walkable cell keeps this
	# behavior predictable and lets us skip nearby cells blocked off by a wall.
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			if not is_traversable(get_tile(cell)):
				continue

			var candidate := _closest_point_in_cell(target, cell, clearance)
			var distance := candidate.distance_squared_to(target)
			if distance >= closest_distance:
				continue

			var cell_path := _navigation_grid.get_id_path(start_cell, cell)
			if cell_path.is_empty():
				continue

			closest_distance = distance
			closest_position = candidate
			closest_cell = cell

	if closest_distance == INF:
		return {}
	return {"cell": closest_cell, "position": closest_position}

func _closest_point_in_cell(target: Vector2, cell: Vector2i, clearance: float) -> Vector2:
	var rect := Rect2(cell_to_world(cell), Vector2.ONE * tile_size)
	var minimum := rect.position + Vector2.ONE * clearance
	var maximum := rect.end - Vector2.ONE * clearance
	return Vector2(
		clampf(target.x, minimum.x, maximum.x),
		clampf(target.y, minimum.y, maximum.y)
	)

func _line_is_clear(from_world: Vector2, to_world: Vector2, clearance: float = 0.0) -> bool:
	var distance := from_world.distance_to(to_world)
	# Half-tile spacing cannot skip across a blocking tile and cuts the cost of
	# long direct-path checks in half compared with the old quarter-tile pass.
	var steps := maxi(1, ceili(distance / (tile_size * 0.5)))
	var clearance_samples: Array[Vector2] = [Vector2.ZERO]
	if clearance > 0.0:
		# A center-only test can approve a diagonal that clips the corner of a
		# stone tile. Sample the unit's perimeter as well as its center so the
		# smoothed segment respects the requested circular clearance.
		for direction_index in range(8):
			var angle := float(direction_index) * TAU / 8.0
			clearance_samples.append(Vector2.RIGHT.rotated(angle) * clearance)

	for index in range(steps + 1):
		var sample := from_world.lerp(to_world, float(index) / float(steps))
		for offset in clearance_samples:
			var cell := world_to_cell(sample + offset)
			if not is_inside(cell) or not is_traversable(get_tile(cell)):
				return false
	return true

func has_line_of_sight(from_world: Vector2, to_world: Vector2, projectile_radius: float = 6.0, exclude: Array[RID] = []) -> bool:
	if not _terrain_line_has_clearance(from_world, to_world, projectile_radius):
		return false

	# Terrain occupancy is already known by the grid, so asking the physics
	# server about every four pixels only duplicates work. One swept-circle test
	# is retained for dynamic/authored structures that are not part of the grid.
	var shape := CircleShape2D.new()
	shape.radius = projectile_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, from_world)
	query.motion = to_world - from_world
	query.collision_mask = 1 << (STRUCTURE_LAYER - 1)
	query.collide_with_bodies = true
	query.exclude = exclude
	var motion_result := get_world_2d().direct_space_state.cast_motion(query)
	return motion_result.is_empty() or motion_result[0] >= 0.999

func _terrain_line_has_clearance(from_world: Vector2, to_world: Vector2, projectile_radius: float) -> bool:
	var distance := from_world.distance_to(to_world)
	var steps := maxi(1, ceili(distance / (tile_size * 0.35)))
	var direction := from_world.direction_to(to_world)
	var perpendicular := direction.orthogonal() * projectile_radius
	var offsets: Array[Vector2] = [Vector2.ZERO]
	if projectile_radius > 0.0 and direction != Vector2.ZERO:
		offsets.append(perpendicular)
		offsets.append(-perpendicular)
	for index in range(steps + 1):
		var sample := from_world.lerp(to_world, float(index) / float(steps))
		for offset in offsets:
			var cell := world_to_cell(sample + offset)
			if not is_inside(cell) or blocks_projectiles(get_tile(cell)):
				return false
	return true

func find_closest_line_of_sight_position(from_world: Vector2, to_world: Vector2, max_distance: float, clearance: float = 12.0, exclude: Array[RID] = []) -> Dictionary:
	var start_cell := world_to_cell(from_world)
	if not is_inside(start_cell):
		return {}
	var candidates: Array[Dictionary] = []
	var target_cell := world_to_cell(to_world)
	var search_radius := ceili(max_distance / tile_size) + 1
	var minimum_x := maxi(0, target_cell.x - search_radius)
	var maximum_x := mini(columns - 1, target_cell.x + search_radius)
	var minimum_y := maxi(0, target_cell.y - search_radius)
	var maximum_y := mini(rows - 1, target_cell.y + search_radius)
	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			var cell := Vector2i(x, y)
			if not is_traversable(get_tile(cell)):
				continue
			var candidate := cell_to_world(cell) + Vector2.ONE * tile_size * 0.5
			if candidate.distance_to(to_world) > max_distance:
				continue
			if not has_line_of_sight(candidate, to_world, 6.0, exclude):
				continue
			candidates.append({"cell": cell, "position": candidate, "distance": from_world.distance_squared_to(candidate)})
	candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first["distance"]) < float(second["distance"])
	)
	# Nearby candidates are overwhelmingly likely to share the unit's connected
	# land region. Bound A* probes so a blocked target cannot stall an entire frame.
	for index in range(mini(candidates.size(), 32)):
		var candidate: Dictionary = candidates[index]
		if not _navigation_grid.get_id_path(start_cell, candidate["cell"]).is_empty():
			return {"position": _closest_point_in_cell(candidate["position"], candidate["cell"], clearance)}
	return {}

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows

func get_tile(cell: Vector2i) -> int:
	if not is_inside(cell):
		return TileType.STONE
	return tiles[cell.y][cell.x]

func is_traversable(tile_type: int) -> bool:
	return tile_type in [TileType.GRASS, TileType.DIRT, TileType.SAND, TileType.DARK_GRASS, TileType.DRY_GRASS, TileType.CRACKED_DIRT]

func is_tree_surface(tile_type: int) -> bool:
	return tile_type in [TileType.GRASS, TileType.DARK_GRASS, TileType.DRY_GRASS]

func get_visual_height(cell: Vector2i) -> float:
	if not is_inside(cell) or cell.y >= _tile_heights.size() or cell.x >= _tile_heights[cell.y].size():
		return 0.0
	return float(_tile_heights[cell.y][cell.x])

func _is_open_land_tile(tile_type: int) -> bool:
	return tile_type == TileType.GRASS or tile_type == TileType.SAND

func _is_stone_tile(tile_type: int) -> bool:
	return tile_type == TileType.STONE or tile_type == TileType.SMOOTH_STONE

func _is_water_tile(tile_type: int) -> bool:
	return tile_type == TileType.WATER or tile_type == TileType.DEEP_WATER

func blocks_projectiles(tile_type: int) -> bool:
	return TILE_BLOCKS_PROJECTILES.get(tile_type, false)

func tile_color(tile_type: int) -> Color:
	return TILE_COLORS.get(tile_type, Color.MAGENTA)

func tile_name(tile_type: int) -> String:
	return TILE_NAMES.get(tile_type, "Unknown")

func _set_tile(cell: Vector2i, tile_type: int) -> void:
	if is_inside(cell):
		tiles[cell.y][cell.x] = tile_type
