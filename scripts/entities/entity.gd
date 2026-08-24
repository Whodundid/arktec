class_name Entity
extends CharacterBody2D

## Base for world entities. Behavior is composed from child EntityComponent nodes.

var _components: Array[EntityComponent] = []
enum ActionState { IDLE, HARVESTING, WAITING_FOR_RESOURCE, RETURNING_TO_BASE, CONSTRUCTING, COMBAT, PLAYER_COMMAND }
var is_selected := false
var action_state := ActionState.IDLE
var facing_direction := Vector2.UP
@export var network_entity_id := 0
@export var owning_peer_id := 1 # Server peer by default.
@export_range(0.0, 1440.0, 1.0) var turning_rate_degrees_per_second := 720.0
@export_range(0.0, 64.0, 0.5) var collision_radius := 12.0
@export_range(0.0, 8.0, 0.1) var collision_leeway := 2.0
@export_range(0.0, 4.0, 0.05) var teammate_push_strength := 1.0
@export_range(0.0, 1.0, 0.05) var teammate_slide_strength := 0.35
@export var grounded := false
@export_range(0.0, 50.0, 0.1) var health_regen_per_second := 1.0

var _last_teammate_push_frame := -1
var _last_teammate_push_entity_id := -1
var _formation_collision_ignored: Array[Entity] = []
var _spatial_index: Node

func _ready() -> void:
	network_entity_id = NetworkSession.register_entity(self, network_entity_id)
	tree_exiting.connect(_unregister_network_entity)
	NetworkSession.session_mode_changed.connect(_on_session_mode_changed)
	add_to_group("entities")
	_spatial_index = _find_spatial_index()
	if _spatial_index != null:
		_spatial_index.register_entity(self)
		tree_exiting.connect(_unregister_spatial_entity)
	if grounded:
		# Structures are solid to units and are also projectile/LOS blockers.
		collision_layer |= 1 << 3 # Structures (layer 4)
		collision_layer |= 1 << 5 # Projectile blockers (layer 6)
		add_to_group("buildings")
	# Keep world-order indicators and other ground effects beneath entities.
	z_index = 1
	for child in get_children():
		if child is EntityComponent:
			_components.append(child)
			child.attach_to_entity(self)

	for component in _components:
		component.on_entity_ready()
	_update_component_authority()

func is_simulation_authority() -> bool:
	return NetworkSession.is_simulation_authority()

func set_action_state(next_state: int) -> void:
	action_state = next_state

func is_owned_by_peer(peer_id: int) -> bool:
	return owning_peer_id == peer_id

func _on_session_mode_changed(_mode: int) -> void:
	_update_component_authority()

func _physics_process(_delta: float) -> void:
	if _spatial_index != null:
		_spatial_index.update_entity(self)

func _update_component_authority() -> void:
	var authority_enabled := is_simulation_authority()
	for component in _components:
		component.set_physics_process(authority_enabled)

func _unregister_network_entity() -> void:
	NetworkSession.unregister_entity(network_entity_id, self)

func _unregister_spatial_entity() -> void:
	if _spatial_index != null:
		_spatial_index.unregister_entity(self)

func get_nearby_entities(radius: float) -> Array[Entity]:
	if _spatial_index != null:
		return _spatial_index.query_radius(global_position, radius)
	var nearby: Array[Entity] = []
	for candidate in get_tree().get_nodes_in_group("entities"):
		if candidate is Entity:
			nearby.append(candidate as Entity)
	return nearby

func _find_spatial_index() -> Node:
	var indexes := get_tree().get_nodes_in_group("entity_spatial_indexes")
	return null if indexes.is_empty() else indexes[0] as Node

func get_component(component_type: Variant) -> EntityComponent:
	for component in _components:
		if is_instance_of(component, component_type):
			return component
	return null

func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()

func selection_color() -> Color:
	var team_component := get_component(TeamComponent) as TeamComponent
	if team_component == null:
		return Color("d8dde2")
	match team_component.team:
		TeamComponent.Team.PLAYER:
			return Color("5ee27a")
		TeamComponent.Team.ENEMY:
			return Color("e45b61")
		TeamComponent.Team.ALLY:
			return Color("63d8e2")
		TeamComponent.Team.NEUTRAL:
			return Color("d8dde2")
	return Color("d8dde2")

func draw_selection_ring(radius: float = 20.0, width: float = 3.0) -> void:
	if is_selected:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, selection_color(), width)

func set_facing_direction(direction: Vector2) -> void:
	if direction.length_squared() <= 0.0:
		return
	facing_direction = direction.normalized()
	queue_redraw()

func turn_towards(direction: Vector2, delta: float) -> void:
	if direction.length_squared() <= 0.0:
		return

	var current_angle := facing_direction.angle()
	var target_angle := direction.angle()
	var turn_amount := deg_to_rad(turning_rate_degrees_per_second) * delta
	var next_angle := rotate_toward(current_angle, target_angle, turn_amount)
	facing_direction = Vector2.RIGHT.rotated(next_angle)
	queue_redraw()

## Gives a moving unit a little room to move through non-held teammates.
## CharacterBody2D collision still prevents enemies and held units from being
## walked through; this small pre-push makes friendly formations feel soft
## instead of making every unit behave like an immovable crate.
func push_teammates(direction: Vector2, distance: float) -> void:
	if direction.length_squared() <= 0.0 or distance <= 0.0:
		return

	var own_team := get_component(TeamComponent) as TeamComponent
	if own_team == null:
		return
	var desired_direction := direction.normalized()
	for candidate in get_nearby_entities(collision_radius * 4.0 + 64.0):
		if candidate == self or not candidate is Entity:
			continue
		var other := candidate as Entity
		var other_team := other.get_component(TeamComponent) as TeamComponent
		if other_team == null or other_team.team != own_team.team or other.grounded or other.is_hold_position() or is_formation_collision_ignored(other):
			continue
		var other_movement := other.get_component(MovementComponent) as MovementComponent
		var other_is_moving := other_movement != null and other_movement.is_moving()
		# Give opposite-direction traffic a deterministic right of way. Without
		# this, both CharacterBodies can push each other on the same frame and
		# repeatedly undo the other's sidestep.
		if other_is_moving and get_instance_id() > other.get_instance_id():
			continue

		var offset := other.global_position - global_position
		var distance_between := offset.length()
		var combined_radius := collision_radius + other.collision_radius
		if distance_between > combined_radius + collision_leeway + distance:
			continue
		var to_other_direction := offset.normalized()
		if distance_between <= 0.001:
			to_other_direction = desired_direction
		if desired_direction.dot(to_other_direction) < 0.15:
			continue

		var physics_frame := Engine.get_physics_frames()
		if _last_teammate_push_frame == physics_frame and _last_teammate_push_entity_id == other.get_instance_id():
			continue
		# Lock the pair in both directions for this physics frame. Without this,
		# the second unit can immediately resolve the same contact in reverse and
		# make both bodies appear magnetically stuck together.
		_last_teammate_push_frame = physics_frame
		_last_teammate_push_entity_id = other.get_instance_id()
		other._last_teammate_push_frame = physics_frame
		other._last_teammate_push_entity_id = get_instance_id()

		# Test both sides of the mover's travel axis and choose the one with
		# fewer blockers. The instance-id tie-break is only a final fallback,
		# preventing a left/right bias when both sides are genuinely equal.
		var slide_direction := _choose_slide_direction(other, desired_direction, to_other_direction, distance * teammate_slide_strength)

		# Moving teammates get only a tiny separation nudge, while stationary
		# teammates can slide farther so the mover can actually pass around them.
		var slide_scale := 0.12 if other_is_moving else 1.0
		var push_distance := minf(distance * teammate_push_strength * teammate_slide_strength * slide_scale, distance + collision_leeway)
		# Deliberately apply no radial correction here. The displacement is
		# strictly perpendicular to the mover's travel direction; CharacterBody2D
		# collision resolves the final body separation without nudging the target
		# into or around the mover.
		other.global_position += slide_direction * push_distance
		var maps := get_tree().get_nodes_in_group("terrain_maps")
		if not maps.is_empty():
			other.global_position = (maps[0] as TerrainMap).clamp_entity_position(other.global_position, other.collision_radius)

func _choose_slide_direction(other: Entity, desired_direction: Vector2, to_other_direction: Vector2, test_distance: float) -> Vector2:
	var side := desired_direction.orthogonal().normalized()
	var positive_outward := side.dot(to_other_direction)
	var negative_outward := (-side).dot(to_other_direction)
	# Never select a side that moves the shoved unit toward the mover when
	# there is a clearly outward perpendicular option.
	if positive_outward > 0.05 and negative_outward <= 0.05:
		return side
	if negative_outward > 0.05 and positive_outward <= 0.05:
		return -side

	var positive_blockers := _count_slide_blockers(other, side * test_distance)
	var negative_blockers := _count_slide_blockers(other, -side * test_distance)
	if positive_blockers < negative_blockers:
		return side
	if negative_blockers < positive_blockers:
		return -side

	var other_movement := other.get_component(MovementComponent) as MovementComponent
	if other_movement != null and other_movement.move_direction.length_squared() > 0.0:
		var movement_side := other_movement.move_direction.normalized().dot(side)
		if absf(movement_side) > 0.15:
			return side if movement_side > 0.0 else -side
	return side if get_instance_id() < other.get_instance_id() else -side

func _count_slide_blockers(other: Entity, offset: Vector2) -> int:
	var shape := CircleShape2D.new()
	shape.radius = other.collision_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, other.global_position + offset)
	query.collision_mask = other.collision_mask
	query.collide_with_bodies = true
	query.exclude = [other.get_rid(), get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 8).size()

func is_teammate(other: Entity) -> bool:
	if other == null:
		return false
	var own_team := get_component(TeamComponent) as TeamComponent
	var other_team := other.get_component(TeamComponent) as TeamComponent
	return own_team != null and other_team != null and own_team.team == other_team.team

func set_formation_collision_ignored(other: Entity, ignored: bool) -> void:
	if other == null or other == self:
		return
	if ignored:
		if not _formation_collision_ignored.has(other):
			_formation_collision_ignored.append(other)
		add_collision_exception_with(other)
	else:
		_formation_collision_ignored.erase(other)
		remove_collision_exception_with(other)

func is_formation_collision_ignored(other: Entity) -> bool:
	return _formation_collision_ignored.has(other)

func separate_from_teammate(other: Entity) -> void:
	if other == null or not is_instance_valid(other):
		return
	var offset := other.global_position - global_position
	var distance := offset.length()
	var combined_radius := collision_radius + other.collision_radius
	if distance >= combined_radius:
		return
	var normal := offset.normalized()
	if distance <= 0.001:
		normal = Vector2.RIGHT if get_instance_id() < other.get_instance_id() else Vector2.LEFT
	var correction := maxf((combined_radius - distance) * 0.5 + 0.1, 0.1)
	global_position -= normal * correction
	other.global_position += normal * correction
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	if not maps.is_empty():
		var terrain_map := maps[0] as TerrainMap
		global_position = terrain_map.clamp_entity_position(global_position, collision_radius)
		other.global_position = terrain_map.clamp_entity_position(other.global_position, other.collision_radius)

func separate_overlapping_teammates() -> void:
	# Used only when a moving unit has stopped making progress toward its goal.
	# A single deterministic separation pass breaks dense teammate contacts
	# without adding a permanent radial-avoidance force to normal movement.
	var own_team := get_component(TeamComponent) as TeamComponent
	if own_team == null:
		return
	for candidate in get_nearby_entities(collision_radius * 4.0 + 64.0):
		if candidate == self or not candidate is Entity:
			continue
		var other := candidate as Entity
		var other_team := other.get_component(TeamComponent) as TeamComponent
		if other_team == null or other_team.team != own_team.team or other.grounded:
			continue
		if is_formation_collision_ignored(other):
			continue
		if global_position.distance_to(other.global_position) < collision_radius + other.collision_radius:
			separate_from_teammate(other)

func is_hold_position() -> bool:
	var combat := get_component(CombatComponent) as CombatComponent
	return combat != null and combat.auto_target_mode == CombatComponent.AUTO_HOLD_POSITION
