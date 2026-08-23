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

@export var columns := 20
@export var rows := 12
@export var tile_size := 64.0
@export var map_origin := Vector2(-640.0, -384.0)
@export var draw_grid := true

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

	# Stone forms a compact wall with a deliberate one-tile gap to test paths.
	for x in range(5, 11):
		if x != 8:
			_set_tile(Vector2i(x, 8), TileType.STONE)
	for y in range(8, 10):
		_set_tile(Vector2i(5, y), TileType.STONE)

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

	for y in range(rows):
		for x in range(columns):
			var tile_type: int = tiles[y][x]
			if is_traversable(tile_type):
				continue
			_add_blocking_tile(Vector2i(x, y), tile_type)

func _add_blocking_tile(cell: Vector2i, tile_type: int) -> void:
	var body := StaticBody2D.new()
	body.name = "%s_%d_%d" % [tile_name(tile_type), cell.x, cell.y]
	body.collision_layer = 1 # World
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
			if draw_grid:
				draw_rect(rect, Color(0.06, 0.09, 0.10, 0.28), false, 1.0)

func cell_to_world(cell: Vector2i) -> Vector2:
	return map_origin + Vector2(cell) * tile_size

func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori((world_position.x - map_origin.x) / tile_size), floori((world_position.y - map_origin.y) / tile_size))

func find_path(from_world: Vector2, to_world: Vector2, clearance: float = 12.0) -> Array[Vector2]:
	var start_cell := world_to_cell(from_world)
	var goal_cell := world_to_cell(to_world)
	var path: Array[Vector2] = []

	if not is_inside(start_cell) or not is_inside(goal_cell):
		return path
	var goal_position := to_world
	if not is_traversable(get_tile(goal_cell)):
		var fallback_goal := _find_closest_reachable_goal(start_cell, to_world, clearance)
		if fallback_goal.is_empty():
			return path
		goal_cell = fallback_goal["cell"]
		goal_position = fallback_goal["position"]

	var cell_path := _navigation_grid.get_id_path(start_cell, goal_cell)
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

	if _line_is_clear(anchor, goal_position):
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

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows

func get_tile(cell: Vector2i) -> int:
	if not is_inside(cell):
		return TileType.STONE
	return tiles[cell.y][cell.x]

func is_traversable(tile_type: int) -> bool:
	return tile_type == TileType.GRASS or tile_type == TileType.DIRT

func tile_color(tile_type: int) -> Color:
	return TILE_COLORS.get(tile_type, Color.MAGENTA)

func tile_name(tile_type: int) -> String:
	return TILE_NAMES.get(tile_type, "Unknown")

func _set_tile(cell: Vector2i, tile_type: int) -> void:
	if is_inside(cell):
		tiles[cell.y][cell.x] = tile_type
