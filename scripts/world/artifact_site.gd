extends StaticBody2D

enum Rarity { COMMON, RARE, EXOTIC }
enum State { BURIED, EXCAVATING, EXPOSED_WAITING_FOR_RAIL, RAIL_READY, IN_TRANSIT, LOADED, DESTROYED }

signal state_changed(previous_state: int, next_state: int)
signal health_changed(current_health: float, maximum_health: float)
signal artifact_destroyed(artifact: Node2D)
signal excavation_started(artifact: Node2D)
signal excavation_interrupted(artifact: Node2D, progress: float)
signal excavation_completed(artifact: Node2D)
signal rail_readiness_changed(artifact: Node2D, ready: bool)

@export var grid_cell := Vector2i.ZERO
@export var tile_size := 64.0
@export var rarity: Rarity = Rarity.COMMON
@export var mission_objective := false
@export_range(1.0, 10000.0, 1.0) var maximum_health := 300.0
@export_range(0.1, 120.0, 0.5) var common_excavation_duration := 10.0
@export_range(0.1, 120.0, 0.5) var rare_excavation_duration := 15.0
@export_range(0.1, 120.0, 0.5) var exotic_excavation_duration := 22.0

var state: State = State.BURIED
var current_health := 0.0
var excavation_progress := 0.0
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
	set_physics_process(true)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not NetworkSession.is_simulation_authority() or (state != State.EXPOSED_WAITING_FOR_RAIL and state != State.RAIL_READY):
		return
	var ready := _has_operational_adjacent_rail()
	if ready == (state == State.RAIL_READY):
		return
	set_state(State.RAIL_READY if ready else State.EXPOSED_WAITING_FOR_RAIL)
	rail_readiness_changed.emit(self, ready)
	_log_event("rail_ready" if ready else "rail_required")

func is_invulnerable() -> bool:
	return state == State.BURIED or state == State.EXCAVATING or state == State.LOADED or state == State.DESTROYED

func can_begin_excavation() -> bool:
	return state == State.BURIED

func begin_excavation() -> bool:
	if not NetworkSession.is_simulation_authority() or not can_begin_excavation():
		return false
	set_state(State.EXCAVATING)
	excavation_started.emit(self)
	_log_event("excavation_started")
	return true

func interrupt_excavation() -> bool:
	if not NetworkSession.is_simulation_authority() or state != State.EXCAVATING:
		return false
	set_state(State.BURIED)
	excavation_interrupted.emit(self, excavation_progress)
	_log_event("excavation_interrupted progress=%d%%" % roundi(excavation_progress * 100.0))
	return true

func advance_excavation(delta: float) -> bool:
	if not NetworkSession.is_simulation_authority() or state != State.EXCAVATING or delta <= 0.0:
		return false
	excavation_progress = clampf(excavation_progress + delta / get_excavation_duration(), 0.0, 1.0)
	queue_redraw()
	if excavation_progress < 1.0:
		return false
	set_state(State.EXPOSED_WAITING_FOR_RAIL)
	excavation_completed.emit(self)
	_log_event("excavation_completed")
	return true

func get_excavation_duration() -> float:
	match rarity:
		Rarity.RARE:
			return rare_excavation_duration
		Rarity.EXOTIC:
			return exotic_excavation_duration
	return common_excavation_duration

func is_excavation_complete() -> bool:
	return state >= State.EXPOSED_WAITING_FOR_RAIL and state != State.DESTROYED

func is_rail_ready() -> bool:
	return state == State.RAIL_READY

func contains_world_position(world_position: Vector2) -> bool:
	return Rect2(global_position - Vector2.ONE * tile_size * 0.5, Vector2.ONE * tile_size).has_point(world_position)

func get_excavation_work_position(from_position: Vector2, builder_radius: float) -> Vector2:
	var terrain := _find_terrain_map()
	var best_position := global_position + Vector2.DOWN * (tile_size * 0.5 + builder_radius + 4.0)
	var best_distance := INF
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var candidate := global_position + Vector2(direction) * (tile_size * 0.5 + builder_radius + 4.0)
		if terrain != null:
			var cell := terrain.world_to_cell(candidate)
			if not terrain.is_inside(cell) or not terrain.is_traversable(terrain.get_tile(cell)):
				continue
		var distance := from_position.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best_position = candidate
	return best_position

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

func status_text() -> String:
	match state:
		State.BURIED:
			return "BURIED" if excavation_progress <= 0.0 else "EXCAVATION PAUSED  %d%%" % roundi(excavation_progress * 100.0)
		State.EXCAVATING:
			return "EXCAVATING  %d%%" % roundi(excavation_progress * 100.0)
		State.EXPOSED_WAITING_FOR_RAIL:
			return "RAIL REQUIRED"
		State.RAIL_READY:
			return "RAIL READY"
		State.IN_TRANSIT:
			return "IN TRANSIT"
		State.LOADED:
			return "LOADED"
		State.DESTROYED:
			return "DESTROYED"
	return "UNKNOWN"

func _has_operational_adjacent_rail() -> bool:
	var networks := get_tree().get_nodes_in_group("rail_networks")
	if networks.is_empty():
		return false
	var network := networks[0]
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var segment := network.call("get_segment_at_cell", grid_cell + direction) as Node2D
		if segment != null and bool(segment.call("is_operational")):
			return true
	return false

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	return null if maps.is_empty() else maps[0] as TerrainMap

func _log_event(event_name: String) -> void:
	RuntimeLogger.info("Artifact event: %s cell=(%d,%d) rarity=%s objective=%s" % [event_name, grid_cell.x, grid_cell.y, rarity_name(), str(mission_objective)])

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
	if state == State.BURIED or state == State.EXCAVATING:
		draw_circle(Vector2.ZERO, half * 0.37, Color("55483b"))
		draw_arc(Vector2.ZERO, half * 0.27, 0.0, TAU, 20, Color(glow_color, 0.35 + excavation_progress * 0.55), 3.0)
		for offset in [Vector2(-15, -7), Vector2(8, -13), Vector2(14, 10), Vector2(-10, 14)]:
			draw_circle(offset, 5.0, Color("79634b"))
	else:
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
	if state == State.BURIED or state == State.EXCAVATING:
		var progress_bar := Rect2(Vector2(-half + 5.0, half - 9.0), Vector2(tile_size - 10.0, 5.0))
		draw_rect(progress_bar, Color("14191d"), true)
		draw_rect(Rect2(progress_bar.position, Vector2(progress_bar.size.x * excavation_progress, progress_bar.size.y)), glow_color, true)
	var status_width := tile_size * 3.0
	draw_string(ThemeDB.fallback_font, Vector2(-status_width * 0.5, half + 15.0), "%s  |  %s" % [rarity_name(), status_text()], HORIZONTAL_ALIGNMENT_CENTER, status_width, 10, Color("9ed8e0") if state == State.RAIL_READY else glow_color.lightened(0.2))
