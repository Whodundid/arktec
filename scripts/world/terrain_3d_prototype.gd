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
@export var camera_pan_speed := 8.0
@export var camera_edge_pan_speed := 16.0
@export_range(0.0, 64.0, 1.0) var camera_edge_size := 24.0

const TILE_SHEET_PATH := "res://assets/art/SPRITE_SHEET_1.png"
const SIGNPOST_UNIT_SCENE := preload("res://scenes/entities/signpost_unit_3d.tscn")
const PROJECTILE_3D_SCENE := preload("res://scenes/combat/projectile_3d.tscn")
const SELECTION_BOX_SCRIPT := preload("res://scripts/ui/selection_box_3d.gd")
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
var _camera_target := Vector3(0.0, 0.25, 0.0)
var _dragging_camera := false
var _status_label: Label
var _interaction_status := "Click the signpost to select it"
var _navigation_grid := AStarGrid2D.new()
var _unit: SignpostUnit3D
var _units: Array[SignpostUnit3D] = []
var _attack_move_armed := false
var _movement_marker: Node3D
var _movement_marker_unit: SignpostUnit3D
var _movement_marker_finish_remaining := 0.0
var _mouse_confined := true

func _ready() -> void:
	if ResourceLoader.exists(TILE_SHEET_PATH):
		_tile_sheet = load(TILE_SHEET_PATH) as Texture2D
	_camera_yaw = deg_to_rad(camera_yaw_degrees)
	_build_environment()
	_build_test_map()
	_build_block_world()
	_build_navigation_grid()
	_build_terrain_collision()
	_build_camera()
	_build_signpost_unit()
	_build_overlay()
	_set_mouse_confined(true)
	_update_camera()

func _process(delta: float) -> void:
	_update_combat(delta)
	_update_movement_marker(delta)
	var keyboard_direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	var edge_direction := Vector2.ZERO
	if not _dragging_camera and camera_edge_size > 0.0:
		var viewport_size := get_viewport().get_visible_rect().size
		var mouse_position := get_viewport().get_mouse_position()
		if mouse_position.x <= camera_edge_size:
			edge_direction.x -= 1.0
		elif mouse_position.x >= viewport_size.x - camera_edge_size:
			edge_direction.x += 1.0
		if mouse_position.y <= camera_edge_size:
			edge_direction.y -= 1.0
		elif mouse_position.y >= viewport_size.y - camera_edge_size:
			edge_direction.y += 1.0
	if keyboard_direction == Vector2.ZERO and edge_direction == Vector2.ZERO:
		return

	var camera_outward := Vector3(cos(_camera_yaw), 0.0, sin(_camera_yaw))
	var camera_right := Vector3(camera_outward.z, 0.0, -camera_outward.x)
	var movement_velocity := Vector3.ZERO
	if keyboard_direction != Vector2.ZERO:
		var keyboard_movement := camera_right * keyboard_direction.x + camera_outward * keyboard_direction.y
		movement_velocity += keyboard_movement.normalized() * camera_pan_speed
	if edge_direction != Vector2.ZERO:
		var edge_movement := camera_right * edge_direction.x + camera_outward * edge_direction.y
		movement_velocity += edge_movement.normalized() * camera_edge_pan_speed
	_camera_target += movement_velocity * delta
	_camera_target.x = clampf(_camera_target.x, -float(columns) * 0.5, float(columns) * 0.5)
	_camera_target.z = clampf(_camera_target.z, -float(rows) * 0.5, float(rows) * 0.5)
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

func _build_navigation_grid() -> void:
	_navigation_grid.region = Rect2i(0, 0, columns, rows)
	_navigation_grid.cell_size = Vector2.ONE
	_navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_navigation_grid.update()

	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			_navigation_grid.set_point_solid(cell, not _is_traversable(_tiles[y][x]))

func _build_terrain_collision() -> void:
	var terrain_body := StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	add_child(terrain_body)

	# One broad floor collider supports the walkable terrain. Stone and water
	# receive additional cell colliders so later CharacterBody3D units cannot
	# walk through geometry that the navigation grid considers blocked.
	_add_box_collision(
		terrain_body,
		"TerrainFloor",
		Vector3(float(columns), 0.34, float(rows)),
		Vector3(0.0, 0.17, 0.0)
	)

	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			var tile_type: int = _tiles[y][x]
			if tile_type == TileType.STONE:
				var stone_height := _tile_height(tile_type, cell)
				_add_box_collision(
					terrain_body,
					"Stone_%d_%d" % [x, y],
					Vector3(1.0, stone_height, 1.0),
					_cell_to_world(cell, stone_height * 0.5)
				)
			elif tile_type == TileType.WATER:
				_add_box_collision(
					terrain_body,
					"Water_%d_%d" % [x, y],
					Vector3(1.0, 0.48, 1.0),
					_cell_to_world(cell, 0.24)
				)

func _add_box_collision(parent: StaticBody3D, shape_name: String, size: Vector3, position: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = shape_name
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position = position
	parent.add_child(collision)

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

func _build_signpost_unit() -> void:
	_unit = _spawn_signpost("Mercenary", SignpostUnit3D.Team.PLAYER, Vector2i(4, 10))
	_spawn_signpost("Red Guard", SignpostUnit3D.Team.ENEMY, Vector2i(11, 10))
	_spawn_signpost("Red Pursuer", SignpostUnit3D.Team.ENEMY, Vector2i(24, 4))
	_spawn_signpost("Red Flanker", SignpostUnit3D.Team.ENEMY, Vector2i(22, 14))

func _spawn_signpost(unit_name: String, team: int, spawn_cell: Vector2i) -> SignpostUnit3D:
	var signpost := SIGNPOST_UNIT_SCENE.instantiate() as SignpostUnit3D
	signpost.name = unit_name.replace(" ", "") + "Signpost"
	signpost.display_name = unit_name
	signpost.team = team
	if team == SignpostUnit3D.Team.ENEMY:
		signpost.order_mode = SignpostUnit3D.OrderMode.HOLD_POSITION
	add_child(signpost)
	signpost.position = _cell_to_world_top(spawn_cell)
	signpost.died.connect(_on_unit_died)
	_units.append(signpost)
	return signpost

func _update_camera() -> void:
	if _camera == null:
		return
	_camera.position = _camera_target + Vector3(
		cos(_camera_yaw) * camera_distance,
		camera_height,
		sin(_camera_yaw) * camera_distance
	)
	_camera.look_at(_camera_target, Vector3.UP)
	_refresh_status()

func _refresh_status() -> void:
	if _status_label != null:
		_status_label.text = "3D BLOCK TERRAIN PROTOTYPE\nArrows/screen edges: pan    Q/E or middle-drag: rotate    Wheel: zoom    R: reset\nLeft-click: select/A-move    Right-click: context move    A: attack-move    H: hold    F10: confine mouse    F11: fullscreen    Camera: %d\n%s" % [roundi(rad_to_deg(_camera_yaw)), _interaction_status]

func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "PrototypeHUD"
	add_child(canvas)

	var selection_box := SELECTION_BOX_SCRIPT.new()
	selection_box.name = "SelectionBox"
	selection_box.controller = self
	canvas.add_child(selection_box)
	selection_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	canvas.add_child(panel)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color("d8e9e5"))
	_status_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_status_label)

func _show_movement_marker(unit: SignpostUnit3D, destination: Vector3, color: Color) -> void:
	_clear_movement_marker()
	_movement_marker = Node3D.new()
	_movement_marker.name = "MovementDestinationMarker"
	_movement_marker.position = destination + Vector3(0.0, 0.055, 0.0)
	add_child(_movement_marker)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(
		0.018 + color.r * 0.055,
		0.024 + color.g * 0.055,
		0.028 + color.b * 0.055,
		0.94
	)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.31
	torus.outer_radius = 0.38
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_movement_marker.add_child(ring)

	for size in [Vector3(0.92, 0.025, 0.055), Vector3(0.055, 0.025, 0.92)]:
		var cross_bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		cross_bar.mesh = box
		cross_bar.material_override = material
		cross_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_movement_marker.add_child(cross_bar)

	_movement_marker_unit = unit
	_movement_marker_finish_remaining = 0.55

func _update_movement_marker(delta: float) -> void:
	if not is_instance_valid(_movement_marker):
		return
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.08
	_movement_marker.scale = Vector3.ONE * pulse
	if is_instance_valid(_movement_marker_unit) and _movement_marker_unit.has_pending_path():
		_movement_marker_finish_remaining = 0.55
		return
	_movement_marker_finish_remaining -= delta
	if _movement_marker_finish_remaining <= 0.0:
		_clear_movement_marker()

func _clear_movement_marker() -> void:
	if is_instance_valid(_movement_marker):
		_movement_marker.queue_free()
	_movement_marker = null
	_movement_marker_unit = null
	_movement_marker_finish_remaining = 0.0

func _handle_left_click(screen_position: Vector2) -> void:
	if _unit == null or _camera == null:
		return

	if _attack_move_armed and _unit.selected:
		var attack_target := _find_unit_at_screen(screen_position, SignpostUnit3D.Team.ENEMY)
		_attack_move_armed = false
		if attack_target != null:
			_issue_explicit_attack(_unit, attack_target)
			return
		var attack_destination = _screen_to_world(screen_position)
		if attack_destination is Vector3:
			_issue_attack_move(_unit, attack_destination as Vector3)
		return

	var clicked_player := _find_unit_at_screen(screen_position, SignpostUnit3D.Team.PLAYER)
	if clicked_player == _unit:
		_unit.set_selected(true)
		_interaction_status = "%s selected" % _unit.display_name
		_refresh_status()
		return

	_interaction_status = "Use right-click to move, or press A then left-click"
	_refresh_status()

func _select_units_in_screen_rect(selection_rect: Rect2) -> void:
	_attack_move_armed = false
	var selected_count := 0
	for candidate in _units:
		if not is_instance_valid(candidate) or candidate.team != SignpostUnit3D.Team.PLAYER:
			continue
		var screen_position := _camera.unproject_position(candidate.global_position + Vector3(0.0, 0.78, 0.0))
		var selected := selection_rect.has_point(screen_position)
		candidate.set_selected(selected)
		if selected:
			selected_count += 1
	_interaction_status = "%d player signpost%s selected" % [selected_count, "" if selected_count == 1 else "s"]
	_refresh_status()

func _handle_right_click(screen_position: Vector2) -> void:
	if _unit == null or not _unit.selected:
		_interaction_status = "Select the player signpost first"
		_refresh_status()
		return
	_attack_move_armed = false
	var attack_target := _find_unit_at_screen(screen_position, SignpostUnit3D.Team.ENEMY)
	if attack_target != null:
		_issue_explicit_attack(_unit, attack_target)
		return
	var destination = _screen_to_world(screen_position)
	if destination is Vector3:
		_issue_manual_move(_unit, destination as Vector3)

func _screen_to_world(screen_position: Vector2) -> Variant:
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position)
	var ground_plane := Plane(Vector3.UP, 0.0)
	return ground_plane.intersects_ray(ray_origin, ray_direction)

func _find_unit_at_screen(screen_position: Vector2, desired_team: int) -> SignpostUnit3D:
	var closest: SignpostUnit3D
	var closest_distance := 44.0
	for candidate in _units:
		if not is_instance_valid(candidate) or candidate.team != desired_team:
			continue
		var candidate_screen := _camera.unproject_position(candidate.global_position + Vector3(0.0, 0.78, 0.0))
		var distance := candidate_screen.distance_to(screen_position)
		if distance < closest_distance:
			closest = candidate
			closest_distance = distance
	return closest

func _issue_manual_move(unit: SignpostUnit3D, destination: Vector3) -> void:
	unit.combat_target = null
	unit.order_mode = SignpostUnit3D.OrderMode.MANUAL_MOVE
	if _set_unit_path(unit, destination):
		_show_movement_marker(unit, _destination_on_top(destination), unit.team_color())
		_interaction_status = "RIGHT-CLICK MOVE: combat ignored while traveling"
	else:
		unit.order_mode = SignpostUnit3D.OrderMode.IDLE
	_refresh_status()

func _issue_attack_move(unit: SignpostUnit3D, destination: Vector3) -> void:
	unit.combat_target = null
	unit.order_mode = SignpostUnit3D.OrderMode.ATTACK_MOVE
	unit.attack_move_destination = destination
	if _set_unit_path(unit, destination):
		_show_movement_marker(unit, _destination_on_top(destination), Color("d5a7df"))
		_interaction_status = "ATTACK-MOVE: engaging enemies encountered en route"
	else:
		unit.order_mode = SignpostUnit3D.OrderMode.IDLE
	_refresh_status()

func _issue_hold_position(unit: SignpostUnit3D) -> void:
	unit.stop_movement()
	_clear_movement_marker()
	unit.combat_target = null
	unit.order_mode = SignpostUnit3D.OrderMode.HOLD_POSITION
	_interaction_status = "HOLD POSITION: firing in range without chasing"
	_refresh_status()

func _issue_explicit_attack(unit: SignpostUnit3D, target: SignpostUnit3D) -> void:
	unit.combat_target = target
	unit.order_mode = SignpostUnit3D.OrderMode.ATTACK_TARGET
	unit.set_movement_paused(false)
	_show_movement_marker(unit, target.global_position, Color("e45b61"))
	if not _can_attack(unit, target):
		_set_unit_path(unit, target.global_position)
	_interaction_status = "FOCUS FIRE: %s" % target.display_name
	_refresh_status()

func _set_unit_path(unit: SignpostUnit3D, destination: Vector3) -> bool:
	var path := _find_world_path(unit.global_position, destination)
	if path.is_empty():
		unit.stop_movement()
		_interaction_status = "No traversable route to that destination"
		return false
	unit.set_path(path)
	return true

func _destination_on_top(destination: Vector3) -> Vector3:
	var cell := _world_to_cell(destination)
	if not _is_inside(cell):
		return destination
	return Vector3(
		destination.x,
		_tile_height(_tiles[cell.y][cell.x], cell) + 0.02,
		destination.z
	)

func _find_world_path(from_world: Vector3, to_world: Vector3) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var start_cell := _world_to_cell(from_world)
	var goal_cell := _world_to_cell(to_world)
	if not _is_inside(start_cell) or not _is_inside(goal_cell):
		return path
	if not _is_traversable(_tiles[goal_cell.y][goal_cell.x]):
		return path

	var cell_path := _navigation_grid.get_id_path(start_cell, goal_cell)
	if cell_path.is_empty():
		return path

	var exact_destination := Vector3(
		to_world.x,
		_tile_height(_tiles[goal_cell.y][goal_cell.x], goal_cell) + 0.02,
		to_world.z
	)
	var raw_points: Array[Vector3] = []
	for index in range(1, cell_path.size()):
		raw_points.append(_cell_to_world_top(Vector2i(cell_path[index])))

	# Greedily skip cell centers while a straight segment remains traversable.
	# Open terrain therefore becomes one natural diagonal instead of a staircase.
	var anchor := from_world
	var raw_index := 0
	while raw_index < raw_points.size():
		var farthest := raw_index
		for probe in range(raw_index, raw_points.size()):
			if not _grid_segment_is_clear(anchor, raw_points[probe]):
				break
			farthest = probe
		path.append(raw_points[farthest])
		anchor = raw_points[farthest]
		raw_index = farthest + 1

	if path.is_empty() or path.back().distance_to(exact_destination) > 0.025:
		path.append(exact_destination)
	else:
		path[path.size() - 1] = exact_destination
	return path

func _grid_segment_is_clear(from_world: Vector3, to_world: Vector3) -> bool:
	var planar_distance := Vector2(from_world.x, from_world.z).distance_to(Vector2(to_world.x, to_world.z))
	var steps := maxi(1, ceili(planar_distance / 0.18))
	for index in range(steps + 1):
		var sample := from_world.lerp(to_world, float(index) / float(steps))
		var cell := _world_to_cell(sample)
		if not _is_inside(cell) or not _is_traversable(_tiles[cell.y][cell.x]):
			return false
	return true

func _update_combat(_delta: float) -> void:
	for unit in _units:
		if not is_instance_valid(unit) or not unit.is_alive():
			continue
		if not is_instance_valid(unit.combat_target) or not unit.combat_target.is_alive():
			unit.combat_target = null

		match unit.order_mode:
			SignpostUnit3D.OrderMode.MANUAL_MOVE:
				if not unit.has_pending_path():
					unit.order_mode = SignpostUnit3D.OrderMode.IDLE
				continue
			SignpostUnit3D.OrderMode.HOLD_POSITION:
				unit.stop_movement()
				if unit.combat_target == null:
					unit.combat_target = _acquire_nearest_target(unit)
			SignpostUnit3D.OrderMode.ATTACK_MOVE:
				if unit.combat_target == null:
					unit.combat_target = _acquire_nearest_target(unit)
				if unit.combat_target == null:
					unit.set_movement_paused(false)
					if not unit.has_pending_path():
						unit.order_mode = SignpostUnit3D.OrderMode.IDLE
					continue
			SignpostUnit3D.OrderMode.ATTACK_TARGET:
				if unit.combat_target == null:
					unit.order_mode = SignpostUnit3D.OrderMode.IDLE
					unit.set_movement_paused(false)
					continue
			SignpostUnit3D.OrderMode.IDLE:
				if unit.combat_target == null:
					unit.combat_target = _acquire_nearest_target(unit)

		var target := unit.combat_target
		if target == null:
			continue
		if _can_attack(unit, target):
			unit.set_movement_paused(true)
			_fire_if_ready(unit, target)
		elif unit.order_mode == SignpostUnit3D.OrderMode.ATTACK_TARGET:
			unit.set_movement_paused(false)
			if not unit.has_pending_path():
				_set_unit_path(unit, target.global_position)
		else:
			unit.combat_target = null
			unit.set_movement_paused(false)

func _acquire_nearest_target(unit: SignpostUnit3D) -> SignpostUnit3D:
	var closest: SignpostUnit3D
	var closest_distance := INF
	for candidate in _units:
		if not is_instance_valid(candidate) or candidate == unit or candidate.team == unit.team or not candidate.is_alive():
			continue
		var distance := _planar_distance(unit.global_position, candidate.global_position)
		if distance > unit.attack_range or distance >= closest_distance:
			continue
		if not _has_combat_line_of_sight(unit.global_position, candidate.global_position):
			continue
		closest = candidate
		closest_distance = distance
	return closest

func _can_attack(unit: SignpostUnit3D, target: SignpostUnit3D) -> bool:
	return (
		is_instance_valid(target)
		and target.is_alive()
		and target.team != unit.team
		and _planar_distance(unit.global_position, target.global_position) <= unit.attack_range
		and _has_combat_line_of_sight(unit.global_position, target.global_position)
	)

func _has_combat_line_of_sight(from_world: Vector3, to_world: Vector3) -> bool:
	var distance := _planar_distance(from_world, to_world)
	var steps := maxi(1, ceili(distance / 0.15))
	for index in range(1, steps):
		var sample := from_world.lerp(to_world, float(index) / float(steps))
		var cell := _world_to_cell(sample)
		if _is_inside(cell) and _tiles[cell.y][cell.x] == TileType.STONE:
			return false
	return true

func _fire_if_ready(unit: SignpostUnit3D, target: SignpostUnit3D) -> void:
	if unit.fire_cooldown > 0.0:
		return
	unit.fire_cooldown = unit.fire_interval
	var projectile: Node3D = PROJECTILE_3D_SCENE.instantiate()
	projectile.set("target", target)
	projectile.set("damage", unit.attack_damage)
	projectile.set("projectile_color", unit.team_color())
	add_child(projectile)
	projectile.global_position = unit.global_position + Vector3(0.0, 0.84, 0.0)

func _planar_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x, first.z).distance_to(Vector2(second.x, second.z))

func _on_unit_died(dead_unit: SignpostUnit3D) -> void:
	_units.erase(dead_unit)
	for unit in _units:
		if is_instance_valid(unit) and unit.combat_target == dead_unit:
			unit.combat_target = null
	if dead_unit == _unit:
		_interaction_status = "Player signpost destroyed"
	else:
		_interaction_status = "%s destroyed" % dead_unit.display_name
	_refresh_status()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_A:
				if _unit != null and _unit.selected:
					_attack_move_armed = true
					_interaction_status = "ATTACK-MOVE ARMED: left-click a destination"
					_refresh_status()
					get_viewport().set_input_as_handled()
			KEY_H:
				if _unit != null and _unit.selected:
					_attack_move_armed = false
					_issue_hold_position(_unit)
					get_viewport().set_input_as_handled()
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
				_camera_target = Vector3(0.0, 0.25, 0.0)
				_camera.size = camera_size
				_update_camera()
				get_viewport().set_input_as_handled()
			KEY_F10:
				_set_mouse_confined(not _mouse_confined)
				get_viewport().set_input_as_handled()
			KEY_F11:
				var window_mode := DisplayServer.window_get_mode()
				if window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
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

func _set_mouse_confined(confined: bool) -> void:
	_mouse_confined = confined
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED if confined else Input.MOUSE_MODE_VISIBLE
	_interaction_status = "Mouse confined to game window" if confined else "Mouse released"
	_refresh_status()

func _cell_to_world(cell: Vector2i, y_position: float = 0.0) -> Vector3:
	return Vector3(
		float(cell.x) - float(columns) * 0.5 + 0.5,
		y_position,
		float(cell.y) - float(rows) * 0.5 + 0.5
	)

func _cell_to_world_top(cell: Vector2i) -> Vector3:
	var tile_type: int = _tiles[cell.y][cell.x]
	return _cell_to_world(cell, _tile_height(tile_type, cell) + 0.02)

func _world_to_cell(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x + float(columns) * 0.5),
		floori(world_position.z + float(rows) * 0.5)
	)

func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows

func _is_traversable(tile_type: int) -> bool:
	return tile_type == TileType.GRASS or tile_type == TileType.DIRT

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
