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
}

@export var columns := 28
@export var rows := 16
@export var tile_size := 64.0
@export var map_origin := Vector2(-896.0, -512.0)
@export var draw_grid := true
@export var draw_tile_details := true

const TILE_COLORS := {
	TileType.GRASS: Color("4d7c59"),
	TileType.STONE: Color("68737a"),
	TileType.DIRT: Color("9b704f"),
	TileType.WATER: Color("39779a"),
}

const TILE_NAMES := {
	TileType.GRASS: "Grass",
	TileType.STONE: "Stone",
	TileType.DIRT: "Dirt",
	TileType.WATER: "Water",
}

# Projectile visibility is separate from movement. A tile can be impassable
# without becoming a line-of-sight blocker (water is the first example).
const TILE_BLOCKS_PROJECTILES := {
	TileType.GRASS: false,
	TileType.STONE: true,
	TileType.DIRT: false,
	TileType.WATER: false,
}

const PROJECTILE_BLOCKER_LAYER := 6
const STRUCTURE_LAYER := 4

var tiles: Array[Array] = []
var _collision_root: Node2D
var _navigation_grid := AStarGrid2D.new()

func _ready() -> void:
	add_to_group("terrain_maps")
	_build_test_map()
	_build_navigation_grid()
	if not Engine.is_editor_hint():
		_build_collision()
	queue_redraw()

func _build_test_map() -> void:
	tiles.clear()
	for y in range(rows):
		var row: Array = []
		for x in range(columns):
			row.append(TileType.GRASS)
		tiles.append(row)

	# A short dirt route gives the map some shape while keeping most of it open.
	for x in range(2, columns - 2):
		_set_tile(Vector2i(x, 5), TileType.DIRT)
		_set_tile(Vector2i(x, 6), TileType.DIRT)

	# Water is a blocking patch in the upper-right of the test map.
	for y in range(1, 4):
		for x in range(13, 17):
			_set_tile(Vector2i(x, y), TileType.WATER)

	# Several stone sections create deliberate LOS breaks and flanking routes.
	# Each section has a gap so units can still route through the area.
	for x in range(6, 14):
		if x != 10:
			_set_tile(Vector2i(x, 8), TileType.STONE)
	for y in range(8, 12):
		if y != 10:
			_set_tile(Vector2i(6, y), TileType.STONE)
	for y in range(2, 7):
		if y != 5:
			_set_tile(Vector2i(15, y), TileType.STONE)
	for x in range(15, 21):
		if x != 18:
			_set_tile(Vector2i(x, 6), TileType.STONE)
	for x in range(20, 26):
		if x != 23:
			_set_tile(Vector2i(x, 12), TileType.STONE)
	for y in range(10, 13):
		if y != 11:
			_set_tile(Vector2i(20, y), TileType.STONE)

	# The battle sandbox uses a map twice this size. Add a second set of
	# offset stone sections there so the extra space creates routes and LOS
	# decisions instead of becoming one enormous empty field. These cells are
	# outside the normal 28-column slice and therefore do not affect main.tscn.
	if columns >= 40:
		for x in range(30, 39):
			# Keep the fixed Blue sandbox base at world (650, 0) on open terrain.
			if x != 34 and x != 38:
				_set_tile(Vector2i(x, 16), TileType.STONE)
		for y in range(16, 23):
			if y != 20:
				_set_tile(Vector2i(42, y), TileType.STONE)
		for x in range(40, 52):
			if x != 46:
				_set_tile(Vector2i(x, 25), TileType.STONE)
		for y in range(4, 12):
			if y != 8:
				_set_tile(Vector2i(49, y), TileType.STONE)

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
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			var tile_type: int = tiles[y][x]
			var rect := Rect2(cell_to_world(cell), Vector2.ONE * tile_size)
			draw_rect(rect, tile_color(tile_type), true)
			if draw_tile_details:
				draw_tile_detail(cell, rect, tile_type)
			if draw_grid:
				draw_rect(rect, Color(0.06, 0.09, 0.10, 0.28), false, 1.0)

func draw_tile_detail(cell: Vector2i, rect: Rect2, tile_type: int) -> void:
	# Keep decoration deterministic so editor redraws and multiplayer clients
	# see the same terrain without storing any extra tile state.
	var seed_value := absi(cell.x * 92821 + cell.y * 68917 + tile_type * 31337)
	var center := rect.position + rect.size * 0.5
	match tile_type:
		TileType.GRASS:
			for index in range(2):
				var offset := Vector2(
					float((seed_value >> (index * 3)) % 38) - 19.0,
					float((seed_value >> (index * 5 + 2)) % 34) - 17.0
				)
				var blade_base := center + offset
				draw_line(blade_base, blade_base + Vector2(-2.0, -5.0), Color(0.20, 0.38, 0.25, 0.28), 1.0)
				draw_line(blade_base, blade_base + Vector2(2.0, -4.0), Color(0.26, 0.45, 0.29, 0.22), 1.0)
		TileType.DIRT:
			var line_color := Color(0.35, 0.22, 0.15, 0.24)
			for index in range(2):
				var y_offset := float((seed_value >> (index * 4)) % 30) - 15.0
				var x_offset := float((seed_value >> (index * 6 + 1)) % 18) - 9.0
				draw_line(center + Vector2(-22.0 + x_offset, y_offset), center + Vector2(12.0 + x_offset, y_offset + 2.0), line_color, 1.0)
		TileType.STONE:
			var crack_color := Color(0.25, 0.29, 0.31, 0.42)
			var crack_start := center + Vector2(float(seed_value % 20) - 10.0, -8.0)
			draw_line(crack_start, crack_start + Vector2(-7.0, 7.0), crack_color, 1.0)
			draw_line(crack_start + Vector2(-7.0, 7.0), crack_start + Vector2(2.0, 13.0), crack_color, 1.0)
		TileType.WATER:
			var ripple_color := Color(0.42, 0.73, 0.78, 0.28)
			var ripple_offset := float(seed_value % 18) - 9.0
			draw_line(center + Vector2(-21.0, ripple_offset), center + Vector2(-5.0, ripple_offset - 1.0), ripple_color, 1.0)
			draw_line(center + Vector2(5.0, ripple_offset + 5.0), center + Vector2(22.0, ripple_offset + 4.0), ripple_color, 1.0)

func cell_to_world(cell: Vector2i) -> Vector2:
	return map_origin + Vector2(cell) * tile_size

func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori((world_position.x - map_origin.x) / tile_size), floori((world_position.y - map_origin.y) / tile_size))

func clamp_entity_position(world_position: Vector2, clearance: float) -> Vector2:
	var map_size := Vector2(columns, rows) * tile_size
	var minimum := map_origin + Vector2.ONE * clearance
	var maximum := map_origin + map_size - Vector2.ONE * clearance
	return Vector2(clampf(world_position.x, minimum.x, maximum.x), clampf(world_position.y, minimum.y, maximum.y))

func find_path(from_world: Vector2, to_world: Vector2, clearance: float = 12.0) -> Array[Vector2]:
	var start_cell := world_to_cell(from_world)
	var goal_cell := world_to_cell(to_world)
	var path: Array[Vector2] = []

	if not is_inside(start_cell):
		return path
	var goal_position := to_world
	if not is_inside(goal_cell) or not is_traversable(get_tile(goal_cell)):
		var fallback_goal := _find_closest_reachable_goal(start_cell, to_world, clearance)
		if fallback_goal.is_empty():
			return path
		goal_cell = fallback_goal["cell"]
		goal_position = fallback_goal["position"]

	var cell_path := _navigation_grid.get_id_path(start_cell, goal_cell)
	if cell_path.is_empty():
		var fallback_goal := _find_closest_reachable_goal(start_cell, to_world, clearance)
		if fallback_goal.is_empty():
			return path
		goal_cell = fallback_goal["cell"]
		goal_position = fallback_goal["position"]
		cell_path = _navigation_grid.get_id_path(start_cell, goal_cell)
		if cell_path.is_empty():
			return path

	var route_points: Array[Vector2] = []
	for index in range(1, cell_path.size()):
		var current_cell := Vector2i(cell_path[index])
		var current_center := cell_to_world(current_cell) + Vector2.ONE * tile_size * 0.5

		if index < cell_path.size() - 1:
			var previous_cell := Vector2i(cell_path[index - 1])
			var next_cell := Vector2i(cell_path[index + 1])
			var incoming := current_cell - previous_cell
			var outgoing := next_cell - current_cell

			# At a turn, the diagonal cell toward the inside of the turn is
			# normally the obstacle we are rounding. Place the waypoint near
			# that corner instead of at the center of the current cell.
			if incoming != outgoing and incoming.x * outgoing.x + incoming.y * outgoing.y == 0:
				var inside_direction := -incoming + outgoing
				var inside_cell := current_cell + inside_direction
				if is_inside(inside_cell) and not is_traversable(get_tile(inside_cell)):
					var corner_direction := Vector2(inside_direction).normalized()
					var corner_distance := maxf(0.0, tile_size * 0.5 - clearance)
					route_points.append(current_center + corner_direction * corner_distance)
					continue

		route_points.append(current_center)

	# Remove unnecessary tile-center waypoints. The grid still routes around
	# obstacles, but open terrain can be crossed in a single natural movement.
	var anchor := from_world
	for index in range(route_points.size()):
		var candidate := route_points[index]
		if not _line_is_clear(anchor, candidate):
			var corner := route_points[maxi(0, index - 1)]
			if anchor.distance_to(corner) > 1.0:
				path.append(corner)
			anchor = corner

	if route_points.is_empty():
		path.append(goal_position)
	elif _line_is_clear(anchor, goal_position):
		path.append(goal_position)
	else:
		path.append(route_points[route_points.size() - 1])
		if path.back().distance_to(goal_position) > 1.0:
			path.append(goal_position)
	return path

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

func _line_is_clear(from_world: Vector2, to_world: Vector2) -> bool:
	var distance := from_world.distance_to(to_world)
	var steps := maxi(1, ceili(distance / (tile_size * 0.25)))

	for index in range(steps + 1):
		var sample := from_world.lerp(to_world, float(index) / float(steps))
		var cell := world_to_cell(sample)
		if not is_inside(cell) or not is_traversable(get_tile(cell)):
			return false
	return true

func has_line_of_sight(from_world: Vector2, to_world: Vector2, projectile_radius: float = 6.0, exclude: Array[RID] = []) -> bool:
	var distance := from_world.distance_to(to_world)
	var steps := maxi(1, ceili(distance / 4.0))
	var blocker_mask := (1 << (PROJECTILE_BLOCKER_LAYER - 1)) | (1 << (STRUCTURE_LAYER - 1))
	var shape := CircleShape2D.new()
	shape.radius = projectile_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = blocker_mask
	query.collide_with_bodies = true
	query.exclude = exclude

	# Sample a projectile-sized circle along the segment. A zero-width ray can
	# miss a tile corner even though the actual projectile would collide with it.
	for index in range(steps + 1):
		var sample := from_world.lerp(to_world, float(index) / float(steps))
		query.transform = Transform2D(0.0, sample)
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
	return true

func find_closest_line_of_sight_position(from_world: Vector2, to_world: Vector2, max_distance: float, clearance: float = 12.0, exclude: Array[RID] = []) -> Dictionary:
	var start_cell := world_to_cell(from_world)
	var closest_position := Vector2.ZERO
	var closest_distance := INF

	if not is_inside(start_cell):
		return {}

	# The map is intentionally small, so checking every traversable cell keeps
	# this predictable and makes the closest reachable firing position explicit.
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			if not is_traversable(get_tile(cell)):
				continue
			var candidate := cell_to_world(cell) + Vector2.ONE * tile_size * 0.5
			if candidate.distance_to(to_world) > max_distance:
				continue
			if not has_line_of_sight(candidate, to_world, 6.0, exclude):
				continue
			if _navigation_grid.get_id_path(start_cell, cell).is_empty():
				continue
			var path_distance := from_world.distance_squared_to(candidate)
			if path_distance >= closest_distance:
				continue
			closest_distance = path_distance
			closest_position = _closest_point_in_cell(candidate, cell, clearance)

	if closest_distance == INF:
		return {}
	return {"position": closest_position}

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows

func get_tile(cell: Vector2i) -> int:
	if not is_inside(cell):
		return TileType.STONE
	return tiles[cell.y][cell.x]

func is_traversable(tile_type: int) -> bool:
	return tile_type == TileType.GRASS or tile_type == TileType.DIRT

func blocks_projectiles(tile_type: int) -> bool:
	return TILE_BLOCKS_PROJECTILES.get(tile_type, false)

func tile_color(tile_type: int) -> Color:
	return TILE_COLORS.get(tile_type, Color.MAGENTA)

func tile_name(tile_type: int) -> String:
	return TILE_NAMES.get(tile_type, "Unknown")

func _set_tile(cell: Vector2i, tile_type: int) -> void:
	if is_inside(cell):
		tiles[cell.y][cell.x] = tile_type
