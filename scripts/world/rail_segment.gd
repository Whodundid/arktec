extends StaticBody2D

const CONNECTION_NORTH := 1
const CONNECTION_EAST := 2
const CONNECTION_SOUTH := 4
const CONNECTION_WEST := 8

signal construction_completed(segment: Node2D)
signal health_changed(current_health: float, maximum_health: float)
signal broken(segment: Node2D)
signal repaired(segment: Node2D)

@export var grid_cell := Vector2i.ZERO
@export var tile_size := 64.0
@export_range(1.0, 1000.0, 1.0) var maximum_health := 60.0

var current_health := 60.0
var construction_progress := 0.0
var under_construction := true
var connection_mask := 0

func _ready() -> void:
	current_health = maximum_health
	collision_layer = 1 << 5 # Projectile blockers; units can cross rails freely.
	collision_mask = 0
	add_to_group("rail_segments")
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * tile_size * 0.72
	collider.shape = shape
	add_child(collider)
	z_index = 900 + floori(global_position.y / 16.0)
	queue_redraw()

func set_connection_mask(next_mask: int) -> void:
	if connection_mask == next_mask:
		return
	connection_mask = next_mask
	queue_redraw()

func set_construction_progress(value: float) -> void:
	construction_progress = clampf(value, 0.0, 1.0)
	queue_redraw()

func complete_construction() -> void:
	if not under_construction:
		return
	construction_progress = 1.0
	under_construction = false
	construction_completed.emit(self)
	queue_redraw()

func damage(amount: float) -> void:
	if not NetworkSession.is_simulation_authority() or amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		broken.emit(self)
	queue_redraw()

func repair(amount: float) -> void:
	if not NetworkSession.is_simulation_authority() or amount <= 0.0 or current_health >= maximum_health:
		return
	var was_broken := current_health <= 0.0
	current_health = minf(current_health + amount, maximum_health)
	health_changed.emit(current_health, maximum_health)
	if was_broken and current_health > 0.0:
		repaired.emit(self)
	queue_redraw()

func is_operational() -> bool:
	return not under_construction and current_health > 0.0

func needs_builder_work() -> bool:
	return under_construction or current_health < maximum_health

func _draw() -> void:
	var half := tile_size * 0.5
	var track_color := Color("a7b2b8")
	var bed_color := Color("3b4650")
	if under_construction:
		track_color = Color("d8b965", 0.42 + construction_progress * 0.5)
		bed_color = Color("554c35", 0.65)
	elif current_health <= 0.0:
		track_color = Color("8b5a52")
		bed_color = Color("302a2a")
	var effective_mask := connection_mask
	if effective_mask == 0:
		effective_mask = CONNECTION_NORTH | CONNECTION_SOUTH
	_draw_track_arm(Vector2.UP, (effective_mask & CONNECTION_NORTH) != 0, half, bed_color, track_color)
	_draw_track_arm(Vector2.RIGHT, (effective_mask & CONNECTION_EAST) != 0, half, bed_color, track_color)
	_draw_track_arm(Vector2.DOWN, (effective_mask & CONNECTION_SOUTH) != 0, half, bed_color, track_color)
	_draw_track_arm(Vector2.LEFT, (effective_mask & CONNECTION_WEST) != 0, half, bed_color, track_color)
	draw_circle(Vector2.ZERO, 11.0, bed_color)
	draw_circle(Vector2.ZERO, 7.0, track_color)
	if under_construction:
		var bar := Rect2(-half + 5.0, half - 10.0, tile_size - 10.0, 5.0)
		draw_rect(bar, Color("1a2025"), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * construction_progress, bar.size.y)), Color("f4d58b"), true)
	elif current_health < maximum_health:
		var ratio := current_health / maximum_health
		var bar := Rect2(-half + 5.0, -half + 5.0, tile_size - 10.0, 5.0)
		draw_rect(bar, Color("1a2025"), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color("df765f") if ratio < 0.4 else Color("e5b85b"), true)
	if current_health <= 0.0:
		draw_line(Vector2(-15.0, -15.0), Vector2(15.0, 15.0), Color("ff796d"), 4.0)
		draw_line(Vector2(15.0, -15.0), Vector2(-15.0, 15.0), Color("ff796d"), 4.0)

func _draw_track_arm(direction: Vector2, enabled: bool, half: float, bed_color: Color, track_color: Color) -> void:
	if not enabled:
		return
	var perpendicular := direction.orthogonal()
	var end := direction * half
	draw_line(Vector2.ZERO, end, bed_color, 18.0)
	draw_line(perpendicular * 5.0, end + perpendicular * 5.0, track_color, 3.0)
	draw_line(-perpendicular * 5.0, end - perpendicular * 5.0, track_color, 3.0)
	for distance_value in [14.0, 27.0]:
		var center: Vector2 = direction * float(distance_value)
		draw_line(center - perpendicular * 10.0, center + perpendicular * 10.0, Color("6e5942"), 3.0)
