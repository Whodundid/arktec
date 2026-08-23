class_name WanderComponent
extends EntityComponent

## Lightweight ambient AI. The component picks reachable destinations inside a
## territory, then lets MovementComponent handle the actual path following.
## Combat and explicit player orders always take priority over wandering.

@export var enabled := false
@export_range(16.0, 1000.0, 1.0) var territory_radius := 180.0
@export_range(0.1, 30.0, 0.1) var min_wait_seconds := 1.5
@export_range(0.1, 30.0, 0.1) var max_wait_seconds := 4.0
@export_range(1.0, 64.0, 1.0) var destination_tolerance := 8.0

var territory_owner: Node2D
var _territory_center := Vector2.ZERO
var _home_territory_owner: Node2D
var _home_territory_center := Vector2.ZERO
var _home_territory_radius := 180.0
var _wait_remaining := 0.0
var _destination_active := false
var _random := RandomNumberGenerator.new()
var _movement: MovementComponent

func on_entity_ready() -> void:
	_random.randomize()
	_movement = entity.get_component(MovementComponent) as MovementComponent
	_territory_center = entity.global_position
	_home_territory_center = entity.global_position
	_home_territory_radius = territory_radius
	_wait_remaining = _random_wait()
	# A spawned enemy can receive its building after the Entity's _ready call.
	call_deferred("_begin_wandering")

func _physics_process(delta: float) -> void:
	if not enabled or entity == null or _movement == null:
		return
	if _is_under_other_control():
		return

	if _movement.is_moving():
		return
	if _destination_active:
		_destination_active = false
		_wait_remaining = _random_wait()
		return

	_wait_remaining -= delta
	if _wait_remaining > 0.0:
		return
	_choose_next_destination()

func set_territory_owner(owner: Node2D, radius: float = -1.0) -> void:
	territory_owner = owner
	_home_territory_owner = owner
	if radius > 0.0:
		territory_radius = radius
	_home_territory_radius = territory_radius
	_update_territory_center()
	_home_territory_center = _territory_center
	_wait_remaining = 0.0

func set_territory(center: Vector2, radius: float) -> void:
	# Temporary investigation territory. Do not overwrite the home territory.
	territory_owner = null
	_territory_center = center
	territory_radius = maxf(radius, 16.0)
	_wait_remaining = 0.0

func restore_home_territory() -> void:
	territory_owner = _home_territory_owner
	territory_radius = _home_territory_radius
	_territory_center = _home_territory_center
	_update_territory_center()
	_wait_remaining = 0.0

func get_home_return_position(from_position: Vector2) -> Vector2:
	if is_instance_valid(_home_territory_owner) and _home_territory_owner.has_method("get_wander_return_position"):
		return _home_territory_owner.get_wander_return_position(from_position)
	return _home_territory_center

func get_territory_center() -> Vector2:
	_update_territory_center()
	return _territory_center

func get_territory_radius() -> float:
	return territory_radius

func get_home_territory_center() -> Vector2:
	if is_instance_valid(_home_territory_owner):
		return _home_territory_owner.global_position
	return _home_territory_center

func _begin_wandering() -> void:
	if territory_owner == null:
		_find_nearest_territory_owner()
	_update_territory_center()

func _choose_next_destination() -> void:
	_update_territory_center()
	var terrain_map := _find_terrain_map()
	for attempt in range(12):
		var candidate: Vector2
		if is_instance_valid(territory_owner) and territory_owner.has_method("get_wander_destination"):
			var shared_candidate: Variant = territory_owner.get_wander_destination(entity.global_position, territory_radius)
			if not shared_candidate is Vector2:
				continue
			candidate = shared_candidate as Vector2
		else:
			var angle := _random.randf_range(0.0, TAU)
			var distance := sqrt(_random.randf()) * territory_radius
			candidate = _territory_center + Vector2.RIGHT.rotated(angle) * distance
		if is_instance_valid(territory_owner) and territory_owner.has_method("can_wander_to"):
			if not territory_owner.can_wander_to(entity.global_position, candidate, _movement.path_clearance):
				continue
		if terrain_map != null:
			var path := terrain_map.find_path(entity.global_position, candidate, _movement.path_clearance)
			if path.is_empty():
				continue
			candidate = path.back()
		_movement.move_to(candidate)
		_destination_active = _movement.get_destination_position() != null
		return
	_wait_remaining = _random_wait()

func _is_under_other_control() -> bool:
	var combat := entity.get_component(CombatComponent) as CombatComponent
	return combat != null and (combat.target != null or combat.is_manual_move_active())

func _update_territory_center() -> void:
	if is_instance_valid(territory_owner):
		if territory_owner.has_method("get_wander_territory_center"):
			_territory_center = territory_owner.get_wander_territory_center(entity.global_position)
		else:
			_territory_center = territory_owner.global_position

func _find_nearest_territory_owner() -> void:
	var closest: Node2D
	var closest_distance := INF
	for candidate in get_tree().get_nodes_in_group("territory_owners"):
		if not candidate is Node2D:
			continue
		var owner := candidate as Node2D
		var distance := entity.global_position.distance_squared_to(owner.global_position)
		if distance < closest_distance:
			closest = owner
			closest_distance = distance
	if closest != null:
		var owner_radius := float(closest.get("territory_radius")) if closest.get("territory_radius") != null else territory_radius
		set_territory_owner(closest, owner_radius)

func _random_wait() -> float:
	return _random.randf_range(minf(min_wait_seconds, max_wait_seconds), maxf(min_wait_seconds, max_wait_seconds))

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	return null if maps.is_empty() else maps[0] as TerrainMap
