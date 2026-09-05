extends Node2D

const TERRAIN_MAP_SCRIPT = preload("res://scripts/world/terrain_map.gd")

func _ready() -> void:
	var terrain := TERRAIN_MAP_SCRIPT.new() as TerrainMap
	terrain.columns = 16
	terrain.rows = 16
	terrain.map_origin = Vector2(-512.0, -512.0)
	add_child(terrain)
	await get_tree().process_frame
	await get_tree().process_frame
	var heights: Array[Array] = []
	for y in range(terrain.rows):
		var height_row: Array = []
		for x in range(terrain.columns):
			terrain.tiles[y][x] = TerrainMap.TileType.GRASS
			height_row.append(0.0)
		heights.append(height_row)
	var outcrop := {
		Vector2i(7, 7): 42.0, Vector2i(8, 7): 56.0, Vector2i(9, 7): 48.0,
		Vector2i(7, 8): 42.0, Vector2i(8, 8): 56.0, Vector2i(7, 9): 42.0,
	}
	for cell in outcrop:
		terrain.tiles[cell.y][cell.x] = TerrainMap.TileType.SMOOTH_STONE
		heights[cell.y][cell.x] = outcrop[cell]
	terrain.set("_tile_heights", heights)
	terrain._rebuild_terrain_render_texture()
	terrain.queue_redraw()
	var camera := Camera2D.new()
	camera.position = terrain.cell_to_world(Vector2i(8, 8)) + Vector2.ONE * terrain.tile_size * 0.5
	camera.zoom = Vector2.ONE * 2.0
	add_child(camera)
	camera.make_current()
	terrain._update_height_shadow_lighting(1.0, Vector2.RIGHT.rotated(-0.28))
	for _frame in range(4):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://tests/_height_shadow_probe.png")
	get_tree().quit(0)
