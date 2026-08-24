class_name SignpostUnit3D
extends Node3D

## Lightweight unit representation for the first 3D gameplay slice.
## The unit occupies 3D space but presents as a camera-facing 2D signpost.

enum Team {
	PLAYER,
	ENEMY,
}

enum OrderMode {
	IDLE,
	MANUAL_MOVE,
	ATTACK_MOVE,
	HOLD_POSITION,
	ATTACK_TARGET,
}

@export var display_name := "Mercenary"
@export var movement_speed := 4.0
@export var signpost_texture: Texture2D
@export var team := Team.PLAYER
@export var maximum_health := 100.0
@export var attack_range := 4.25
@export var fire_interval := 0.55
@export var attack_damage := 20.0

const SIGNPOST_SVG_PATH := "res://assets/art/signpost_unit.svg"

signal died(unit: SignpostUnit3D)

var selected := false
var current_health := 100.0
var order_mode := OrderMode.IDLE
var combat_target: SignpostUnit3D
var attack_move_destination := Vector3.ZERO
var fire_cooldown := 0.0
var _path: Array[Vector3] = []
var _movement_paused := false
var _selection_marker: MeshInstance3D
var _sprite: Sprite3D
var _nameplate: Label3D

func _ready() -> void:
	current_health = maximum_health
	if signpost_texture == null:
		signpost_texture = _load_signpost_texture()
	_build_visuals()
	_refresh_visuals()

func _process(delta: float) -> void:
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	if _movement_paused or _path.is_empty():
		return

	var target := _path[0]
	global_position = global_position.move_toward(target, movement_speed * delta)
	if global_position.distance_to(target) <= 0.025:
		global_position = target
		_path.remove_at(0)

func set_selected(value: bool) -> void:
	selected = value
	if _selection_marker != null:
		_selection_marker.visible = selected

func set_path(points: Array[Vector3]) -> void:
	_path = points.duplicate()
	_movement_paused = false

func clear_path() -> void:
	_path.clear()

func stop_movement() -> void:
	_path.clear()
	_movement_paused = false

func set_movement_paused(value: bool) -> void:
	_movement_paused = value

func is_moving() -> bool:
	return not _path.is_empty() and not _movement_paused

func has_pending_path() -> bool:
	return not _path.is_empty()

func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	_refresh_visuals()
	if current_health <= 0.0:
		died.emit(self)
		queue_free()

func is_alive() -> bool:
	return current_health > 0.0 and not is_queued_for_deletion()

func team_color() -> Color:
	return Color("5ee27a") if team == Team.PLAYER else Color("e45b61")

func _load_signpost_texture() -> Texture2D:
	var svg_source := FileAccess.get_file_as_string(SIGNPOST_SVG_PATH)
	if svg_source.is_empty():
		return null
	var image := Image.new()
	if image.load_svg_from_string(svg_source, 1.0) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _build_visuals() -> void:
	_selection_marker = MeshInstance3D.new()
	_selection_marker.name = "SelectionMarker"
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.46
	marker_mesh.bottom_radius = 0.46
	marker_mesh.height = 0.025
	marker_mesh.radial_segments = 32
	_selection_marker.mesh = marker_mesh
	_selection_marker.position.y = 0.018
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.012, 0.022, 0.026, 0.86)
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.no_depth_test = false
	_selection_marker.material_override = marker_material
	_selection_marker.visible = selected
	add_child(_selection_marker)

	_sprite = Sprite3D.new()
	_sprite.name = "Signpost"
	_sprite.texture = signpost_texture
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = 0.008
	_sprite.position.y = 0.72
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)

	_nameplate = Label3D.new()
	_nameplate.name = "Nameplate"
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.position.y = 1.47
	_nameplate.font_size = 32
	_nameplate.outline_size = 8
	_nameplate.pixel_size = 0.008
	_nameplate.outline_modulate = Color(0.02, 0.06, 0.08, 0.92)
	add_child(_nameplate)

func _refresh_visuals() -> void:
	var color := team_color()
	if _sprite != null:
		_sprite.modulate = Color.WHITE if team == Team.PLAYER else Color(1.0, 0.68, 0.68, 1.0)
	if _nameplate != null:
		_nameplate.text = "%s  %d/%d" % [display_name, ceili(current_health), ceili(maximum_health)]
		_nameplate.modulate = color.lightened(0.22)
	if _selection_marker != null:
		var marker_material := _selection_marker.material_override as StandardMaterial3D
		if marker_material != null:
			marker_material.albedo_color = Color(0.012, 0.022, 0.026, 0.86)
