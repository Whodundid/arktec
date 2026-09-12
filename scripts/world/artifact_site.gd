extends StaticBody2D

enum Rarity { COMMON, RARE, EXOTIC }
enum State { BURIED, MINING, MINED_WAITING_FOR_RAIL, READY_FOR_TRANSPORT, IN_TRANSIT, LOADED, DESTROYED }

signal state_changed(previous_state: int, next_state: int)
signal health_changed(current_health: float, maximum_health: float)
signal artifact_destroyed(artifact: Node2D)

@export var grid_cell := Vector2i.ZERO
@export var tile_size := 64.0
@export var rarity: Rarity = Rarity.COMMON
@export var mission_objective := false
@export_range(1.0, 10000.0, 1.0) var maximum_health := 300.0

var state: State = State.BURIED
var current_health := 0.0
var _collision_shape: CollisionShape2D

func _ready() -> void:
	current_health = maximum_health
	collision_layer = 1 << 4 # Artifacts (layer 5).
	collision_mask = 0
	add_to_group("artifacts")
	_collision_shape = CollisionShape2D.new()
	_collision_shape.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * tile_size
	_collision_shape.shape = shape
	add_child(_collision_shape)
	z_index = 1000 + floori(global_position.y / 16.0)
	queue_redraw()

func is_invulnerable() -> bool:
	return state == State.BURIED or state == State.LOADED or state == State.DESTROYED

func set_state(next_state: State) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	state_changed.emit(previous, state)
	queue_redraw()

func damage(amount: float) -> void:
	if not NetworkSession.is_simulation_authority() or is_invulnerable() or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		set_state(State.DESTROYED)
		if _collision_shape != null:
			_collision_shape.set_deferred("disabled", true)
		artifact_destroyed.emit(self)

func rarity_name() -> String:
	return Rarity.keys()[rarity].capitalize()

func _draw() -> void:
	var half := tile_size * 0.5
	if state == State.DESTROYED:
		draw_circle(Vector2.ZERO, half * 0.34, Color("34323b"))
		draw_line(Vector2(-18, -9), Vector2(19, 12), Color("765c7d"), 5.0)
		draw_line(Vector2(-13, 15), Vector2(15, -18), Color("765c7d"), 4.0)
		return
	var glow_color := Color("72c7e8")
	match rarity:
		Rarity.RARE:
			glow_color = Color("b985ef")
		Rarity.EXOTIC:
			glow_color = Color("f1c75b")
	draw_rect(Rect2(Vector2.ONE * -half, Vector2.ONE * tile_size), Color("18242b"), true)
	draw_rect(Rect2(Vector2.ONE * -half, Vector2.ONE * tile_size), Color(glow_color, 0.72), false, 3.0)
	draw_circle(Vector2.ZERO, half * 0.37, Color("253944"))
	var crystal := PackedVector2Array([
		Vector2(0.0, -half * 0.42), Vector2(half * 0.25, -half * 0.08),
		Vector2(half * 0.15, half * 0.38), Vector2(-half * 0.2, half * 0.28),
		Vector2(-half * 0.3, -half * 0.06),
	])
	draw_colored_polygon(crystal, glow_color)
	if mission_objective:
		draw_arc(Vector2.ZERO, half * 0.43, 0.0, TAU, 32, Color("fff2a6"), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-half, -half - 7.0), "OBJECTIVE", HORIZONTAL_ALIGNMENT_CENTER, tile_size, 11, Color("fff2a6"))
	draw_string(ThemeDB.fallback_font, Vector2(-half, half + 15.0), rarity_name(), HORIZONTAL_ALIGNMENT_CENTER, tile_size, 11, glow_color.lightened(0.2))
