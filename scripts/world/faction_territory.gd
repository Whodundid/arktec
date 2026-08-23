class_name FactionTerritory
extends Node2D

## Shared territory for one faction. The territory is represented as a union
## of local circles around its spawners, allowing nearby outposts to behave as
## one region without claiming the empty space between distant bases.

var faction_team: TeamComponent.Team = TeamComponent.Team.ENEMY
var territory_radius := 180.0
var _buildings: Array[Node2D] = []
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()

func add_building(building: Node2D) -> void:
	if building == null or _buildings.has(building):
		return
	_buildings.append(building)
	_update_center()

func get_wander_destination(from_position: Vector2, radius: float) -> Variant:
	var valid_buildings: Array[Node2D] = []
	for building in _buildings:
		if is_instance_valid(building) and not bool(building.get("_destroyed")):
			valid_buildings.append(building)
	if valid_buildings.is_empty():
		return null
	for attempt in range(8):
		var building := valid_buildings[_random.randi_range(0, valid_buildings.size() - 1)]
		var wander_radius := minf(radius, float(building.get("territory_radius")))
		var angle := _random.randf_range(0.0, TAU)
		var distance := sqrt(_random.randf()) * wander_radius
		var candidate := building.global_position + Vector2.RIGHT.rotated(angle) * distance
		# Keep the unit outside the building plus a small body-sized buffer.
		if candidate.distance_to(building.global_position) < 72.0:
			continue
		if building.has_method("can_wander_to") and not bool(building.call("can_wander_to", from_position, candidate, 12.0)):
			continue
		return candidate
	return null

func get_wander_territory_center(_from_position: Vector2) -> Vector2:
	_update_center()
	return global_position

func get_wander_return_position(from_position: Vector2) -> Vector2:
	var best_position := global_position
	var best_distance := INF
	for building in _buildings:
		if not is_instance_valid(building) or bool(building.get("_destroyed")):
			continue
		var candidate: Vector2 = building.call("get_wander_return_position", from_position)
		var distance := from_position.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best_position = candidate
	return best_position

func contains_position(position: Vector2) -> bool:
	for building in _buildings:
		if is_instance_valid(building) and not bool(building.get("_destroyed")) and building.global_position.distance_to(position) <= float(building.get("territory_radius")):
			return true
	return false

func can_wander_to(from_position: Vector2, destination: Vector2, _clearance: float) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from_position, destination)
	query.collision_mask = 1 << 3 # Structures (layer 4)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _update_center() -> void:
	var valid_count := 0
	var center := Vector2.ZERO
	for building in _buildings:
		if is_instance_valid(building) and not bool(building.get("_destroyed")):
			center += building.global_position
			valid_count += 1
	if valid_count > 0:
		global_position = center / float(valid_count)
