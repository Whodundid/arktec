class_name TreeDoodad
extends Node2D

const WORLD_DEPTH_BASE := 1000
const WORLD_DEPTH_STEP := 16.0
const MIDDAY_SHADOW_LENGTH_RATIO := 0.60
const LOW_SUN_SHADOW_LENGTH_RATIO := 1.00

## Decorative tree whose depth is anchored at the trunk base.
## The tree itself has no collision; it adds visual depth without changing
## navigation or creating another way for units to get wedged.

@export var texture: Texture2D
@export_range(48.0, 300.0, 1.0) var target_height := 200.0
@export var flip_h := false
@export_range(0.1, 1.5, 0.05) var wind_factor := 1.0

var _tree_material: ShaderMaterial
var _shadow_material: ShaderMaterial
var _shadow: Sprite2D
var _scale_factor := 1.0

func _ready() -> void:
	if texture == null:
		return
	var source_size := texture.get_size()
	_scale_factor = target_height / maxf(source_size.y, 1.0)
	var base_center_offset := _find_base_center_offset()
	_shadow = Sprite2D.new()
	_shadow.texture = texture
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.flip_h = flip_h
	# Make the sprite's local origin the bottom-center of the source image.
	# The shadow can then rotate and stretch without moving its trunk away from
	# this tree's actual base position.
	_shadow.centered = false
	_shadow.offset = Vector2(-source_size.x * 0.5 - base_center_offset, -source_size.y)
	_shadow.scale = Vector2(_scale_factor * 1.25, _scale_factor * MIDDAY_SHADOW_LENGTH_RATIO)
	_shadow.position = Vector2.ZERO
	_shadow.z_as_relative = true
	# Keep the shadow at the tree's depth so it remains above terrain even for
	# trees near the top of the map, while drawing it behind this tree.
	_shadow.z_index = 0
	_shadow.show_behind_parent = true
	_shadow_material = _make_material("res://shaders/tree_shadow.gdshader")
	_shadow.material = _shadow_material
	add_child(_shadow)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = flip_h
	sprite.scale = Vector2.ONE * _scale_factor
	# Shift the visible sprite by the same detected base offset used by the
	# shadow. The node, visible trunk, and rotating shadow then share one exact
	# ground-contact point even when the source art or horizontal flip is uneven.
	sprite.position = Vector2(-base_center_offset * _scale_factor, -target_height * 0.5)
	_tree_material = _make_material("res://shaders/tree_wind.gdshader")
	sprite.material = _tree_material
	add_child(sprite)
	_connect_day_night_cycle()
	_update_depth()

func _connect_day_night_cycle() -> void:
	var cycles := get_tree().get_nodes_in_group("day_night_cycles")
	if cycles.is_empty():
		return
	var cycle := cycles[0]
	if cycle == null or not cycle.has_method("get_daylight_amount"):
		return
	cycle.lighting_changed.connect(_on_lighting_changed)
	_on_lighting_changed(cycle.get_daylight_amount(), cycle.get_sun_direction())

func _on_lighting_changed(daylight: float, sun_direction: Vector2) -> void:
	if _shadow == null:
		return
	# DayNightCycle already eases daylight through sunrise and sunset. Feed that
	# continuous value into the shadow material so it fades with the sun instead
	# of remaining opaque until the instant the night cutoff hides it.
	var shadow_alpha := 0.30 * clampf(daylight, 0.0, 1.0)
	if _shadow_material != null:
		_shadow_material.set_shader_parameter("shadow_alpha", shadow_alpha)
	_shadow.visible = shadow_alpha > 0.001
	if not _shadow.visible:
		return
	var elevation := 0.22 + daylight * 0.78
	# The texture's local upward direction points away from the base. With this
	# art pivot, the sun direction produces the desired north-side projection;
	# negating it would flip the shadow to the south side.
	_shadow.rotation = sun_direction.angle()
	var shadow_length_ratio := lerpf(LOW_SUN_SHADOW_LENGTH_RATIO, MIDDAY_SHADOW_LENGTH_RATIO, elevation)
	_shadow.scale = Vector2(_scale_factor * 1.25, _scale_factor * shadow_length_ratio)

func _find_base_center_offset() -> float:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return 0.0
	var bottom_start := maxi(0, image.get_height() - maxi(4, floori(float(image.get_height()) / 10.0)))
	var opaque_min := image.get_width()
	var opaque_max := -1
	for y in range(bottom_start, image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.2:
				opaque_min = mini(opaque_min, x)
				opaque_max = maxi(opaque_max, x)
	if opaque_max < opaque_min:
		return 0.0
	var source_center := float(image.get_width() - 1) * 0.5
	var base_center := (float(opaque_min) + float(opaque_max)) * 0.5
	var base_offset := base_center - source_center
	return -base_offset if flip_h else base_offset

func _make_material(shader_path: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(shader_path) as Shader
	return material

func set_wind(wind_direction: Vector2, wind_strength: float, wind_time: float, wind_phase: float) -> void:
	for material in [_tree_material, _shadow_material]:
		if material == null:
			continue
		material.set_shader_parameter("wind_direction", wind_direction)
		material.set_shader_parameter("wind_strength", wind_strength)
		material.set_shader_parameter("wind_factor", wind_factor)
		material.set_shader_parameter("wind_time", wind_time)
		material.set_shader_parameter("wind_phase", wind_phase)

func _update_depth() -> void:
	# Sort from the trunk's ground-contact point so terrain rows, trees, and units
	# all share the same bottom-up depth model.
	z_index = WORLD_DEPTH_BASE + floori(global_position.y / WORLD_DEPTH_STEP)
