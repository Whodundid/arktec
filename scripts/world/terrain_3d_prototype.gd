class_name Terrain3DPrototype
extends Node3D

## Standalone rendering experiment for a true 3D ArtifactRun world.
##
## The gameplay map is still a simple 2D grid, but every cell is rendered as
## a real block on the XZ plane. This keeps the terrain rules familiar while
## allowing an orthographic Camera3D to orbit around the same scene.

enum TileType {
	GRASS,
	STONE,
	DIRT,
	WATER,
}

@export var columns := 28
@export var rows := 16
@export var camera_yaw_degrees := 45.0
@export var camera_distance := 24.0
@export var camera_height := 20.0
@export var camera_size := 18.0

const TILE_SHEET_PATH := "res://assets/art/SPRITE_SHEET_1.png"
const TILE_SHEET_CELL_SIZE := 32.0
const FALLBACK_SHEET_SIZE := Vector2(320.0, 320.0)

const TILE_ATLAS_CELLS := {
	TileType.GRASS: Vector2i(1, 3),
	TileType.STONE: Vector2i(2, 4),
	TileType.DIRT: Vector2i(0, 5),
	TileType.WATER: Vector2i(2, 5),
}

const TILE_FALLBACK_COLORS := {
	TileType.GRASS: Color("4d9c54"),
	TileType.STONE: Color("737b80"),
	TileType.DIRT: Color("80673d"),
	TileType.WATER: Color("356f9c"),
}

var _tiles: Array[Array] = []
var _tile_sheet: Texture2D
var _camera: Camera3D
var _camera_yaw := 0.0
var _dragging_camera := false
var _status_label: Label

func _ready() -> void:
	if ResourceLoader.exists(TILE_SHEET_PATH):
		_tile_sheet = load(TILE_SHEET_PATH) as Texture2D
	_camera_yaw = deg_to_rad(camera_yaw_degrees)
	_build_environment()
	_build_test_map()
	_build_block_world()
	_build_camera()
	_build_overlay()
	_update_camera()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101820")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8c9d2")
	environment.ambient_light_energy = 0.72
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color("fff2cf")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

func _build_test_map() -> void:
	_tiles.clear()
	for y in range(rows):
		var row: Array = []
		for x in range(columns):
			row.append(TileType.GRASS)
		_tiles.append(row)

	for x in range(2, columns - 2):
		_set_tile(Vector2i(x, 5), TileType.DIRT)
		_set_tile(Vector2i(x, 6), TileType.DIRT)

	for y in range(1, 4):
		for x in range(13, 17):
			_set_tile(Vector2i(x, y), TileType.WATER)

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

func _build_block_world() -> void:
	var cells_by_type := {
		TileType.GRASS: [],
		TileType.STONE: [],
		TileType.DIRT: [],
		TileType.WATER: [],
	}

	for y in range(rows):
		for x in range(columns):
			var tile_type: int = _tiles[y][x]
			cells_by_type[tile_type].append(Vector2i(x, y))

	for tile_type: int in cells_by_type:
		_create_tile_multimesh(tile_type, cells_by_type[tile_type])

func _create_tile_multimesh(tile_type: int, cells: Array) -> void:
	if cells.is_empty():
		return

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _create_block_mesh(tile_type)
	multimesh.instance_count = cells.size()

	for index in range(cells.size()):
		var cell: Vector2i = cells[index]
		var height := _tile_height(tile_type, cell)
		var origin := Vector3(
			float(cell.x) - float(columns) * 0.5 + 0.5,
			0.0,
			float(cell.y) - float(rows) * 0.5 + 0.5
		)
		var basis := Basis.IDENTITY.scaled(Vector3(1.0, height, 1.0))
		multimesh.set_instance_transform(index, Transform3D(basis, origin))

	var instance := MultiMeshInstance3D.new()
	instance.name = _tile_name(tile_type) + "Blocks"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(instance)

func _create_block_mesh(tile_type: int) -> ArrayMesh:
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	var colors: Array[Color] = []
	var uv_rect := _atlas_uv_rect(TILE_ATLAS_CELLS[tile_type])

	_append_face(vertices, normals, uvs, colors,
		Vector3(-0.5, 1.0, -0.5), Vector3(0.5, 1.0, -0.5),
		Vector3(0.5, 1.0, 0.5), Vector3(-0.5, 1.0, 0.5),
		Vector3.UP, Color.WHITE, uv_rect)
	_append_face(vertices, normals, uvs, colors,
		Vector3(-0.5, 0.0, 0.5), Vector3(0.5, 0.0, 0.5),
		Vector3(0.5, 0.0, -0.5), Vector3(-0.5, 0.0, -0.5),
		Vector3.DOWN, Color("454c50"), uv_rect)

	var side_color := Color("a0a5a8")
	_append_face(vertices, normals, uvs, colors,
		Vector3(-0.5, 0.0, 0.5), Vector3(-0.5, 1.0, 0.5),
		Vector3(0.5, 1.0, 0.5), Vector3(0.5, 0.0, 0.5),
		Vector3.FORWARD, side_color, uv_rect)
	_append_face(vertices, normals, uvs, colors,
		Vector3(0.5, 0.0, -0.5), Vector3(0.5, 1.0, -0.5),
		Vector3(-0.5, 1.0, -0.5), Vector3(-0.5, 0.0, -0.5),
		Vector3.BACK, side_color.darkened(0.12), uv_rect)
	_append_face(vertices, normals, uvs, colors,
		Vector3(-0.5, 0.0, -0.5), Vector3(-0.5, 1.0, -0.5),
		Vector3(-0.5, 1.0, 0.5), Vector3(-0.5, 0.0, 0.5),
		Vector3.LEFT, side_color.darkened(0.08), uv_rect)
	_append_face(vertices, normals, uvs, colors,
		Vector3(0.5, 0.0, 0.5), Vector3(0.5, 1.0, 0.5),
		Vector3(0.5, 1.0, -0.5), Vector3(0.5, 0.0, -0.5),
		Vector3.RIGHT, side_color.darkened(0.18), uv_rect)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray(colors)

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _create_tile_material(tile_type))
	return mesh

func _append_face(
		vertices: Array[Vector3], normals: Array[Vector3], uvs: Array[Vector2], colors: Array[Color],
		a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3, color: Color, uv_rect: Rect2
	) -> void:
	vertices.append_array([a, b, c, a, c, d])
	for ignored in range(6):
		normals.append(normal)
		colors.append(color)

	var uv_top_left := uv_rect.position
	var uv_top_right := uv_rect.position + Vector2(uv_rect.size.x, 0.0)
	var uv_bottom_right := uv_rect.end
	var uv_bottom_left := uv_rect.position + Vector2(0.0, uv_rect.size.y)
	uvs.append_array([
		uv_bottom_left, uv_top_left, uv_top_right,
		uv_bottom_left, uv_top_right, uv_bottom_right,
	])

func _create_tile_material(tile_type: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = TILE_FALLBACK_COLORS[tile_type]
	if _tile_sheet != null:
		material.albedo_color = Color.WHITE
		material.albedo_texture = _tile_sheet
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _atlas_uv_rect(atlas_cell: Vector2i) -> Rect2:
	var sheet_size := FALLBACK_SHEET_SIZE
	if _tile_sheet != null:
		sheet_size = Vector2(_tile_sheet.get_size())
	# Half-pixel inset prevents neighboring atlas cells from bleeding onto a
	# block face when the camera is rotated or zoomed.
	var pixel_position := Vector2(atlas_cell) * TILE_SHEET_CELL_SIZE + Vector2.ONE * 0.5
	var pixel_size := Vector2.ONE * (TILE_SHEET_CELL_SIZE - 1.0)
	return Rect2(pixel_position / sheet_size, pixel_size / sheet_size)

func _tile_height(tile_type: int, cell: Vector2i) -> float:
	match tile_type:
		TileType.GRASS:
			return 0.34
		TileType.DIRT:
			return 0.30
		TileType.WATER:
			return 0.16
		TileType.STONE:
			# Five deterministic height bands from 0.68 to 1.40 blocks tall.
			return 0.68 + float(_cell_hash(cell, tile_type) % 5) * 0.18
	return 0.34

func _cell_hash(cell: Vector2i, tile_type: int) -> int:
	return absi(cell.x * 92821 + cell.y * 68917 + tile_type * 31337)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "OrbitCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = camera_size
	_camera.near = 0.1
	_camera.far = 200.0
	_camera.current = true
	add_child(_camera)

func _update_camera() -> void:
	if _camera == null:
		return
	var target := Vector3(0.0, 0.25, 0.0)
	_camera.position = target + Vector3(
		cos(_camera_yaw) * camera_distance,
		camera_height,
		sin(_camera_yaw) * camera_distance
	)
	_camera.look_at(target, Vector3.UP)
	if _status_label != null:
		_status_label.text = "3D BLOCK TERRAIN PROTOTYPE\nQ / E or middle-drag: rotate    Wheel: zoom    R: reset\nCamera angle: %d degrees    Stone height: deterministic 0.68-1.40" % roundi(rad_to_deg(_camera_yaw))

func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "PrototypeHUD"
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	canvas.add_child(panel)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color("d8e9e5"))
	_status_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_status_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				_camera_yaw -= deg_to_rad(15.0)
				_update_camera()
				get_viewport().set_input_as_handled()
			KEY_E:
				_camera_yaw += deg_to_rad(15.0)
				_update_camera()
				get_viewport().set_input_as_handled()
			KEY_R:
				_camera_yaw = deg_to_rad(camera_yaw_degrees)
				_camera.size = camera_size
				_update_camera()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging_camera = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.size = maxf(7.0, _camera.size - 1.0)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.size = minf(32.0, _camera.size + 1.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging_camera:
		_camera_yaw += event.relative.x * 0.01
		_update_camera()
		get_viewport().set_input_as_handled()

func _set_tile(cell: Vector2i, tile_type: int) -> void:
	if cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows:
		_tiles[cell.y][cell.x] = tile_type

func _tile_name(tile_type: int) -> String:
	match tile_type:
		TileType.GRASS:
			return "Grass"
		TileType.STONE:
			return "Stone"
		TileType.DIRT:
			return "Dirt"
		TileType.WATER:
			return "Water"
	return "Unknown"
