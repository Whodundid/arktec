class_name SignpostUnit3D
extends Node3D

## Lightweight unit representation for the first 3D gameplay slice.
## The unit occupies 3D space but presents as a camera-facing 2D signpost.

@export var display_name := "Mercenary"
@export var movement_speed := 4.0
@export var signpost_texture: Texture2D

const SIGNPOST_SVG_PATH := "res://assets/art/signpost_unit.svg"

var selected := false
var _path: Array[Vector3] = []
var _selection_marker: MeshInstance3D

func _ready() -> void:
	if signpost_texture == null:
		signpost_texture = _load_signpost_texture()
	_build_visuals()

func _process(delta: float) -> void:
	if _path.is_empty():
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

func clear_path() -> void:
	_path.clear()

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
	marker_material.albedo_color = Color(0.25, 1.0, 0.48, 0.38)
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.no_depth_test = false
	_selection_marker.material_override = marker_material
	_selection_marker.visible = selected
	add_child(_selection_marker)

	var sprite := Sprite3D.new()
	sprite.name = "Signpost"
	sprite.texture = signpost_texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.008
	sprite.position.y = 0.72
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)

	var label := Label3D.new()
	label.name = "Nameplate"
	label.text = display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.47
	label.font_size = 32
	label.outline_size = 8
	label.pixel_size = 0.008
	label.modulate = Color("e8fff0")
	label.outline_modulate = Color(0.02, 0.06, 0.08, 0.92)
	add_child(label)
