class_name EntitySpatialIndex
extends Node

## Lightweight broadphase for gameplay queries. Godot's physics server still
## owns collision truth; this index only narrows the list of entities that AI
## systems need to inspect.

@export_range(16.0, 256.0, 8.0) var cell_size := 128.0

var _cells: Dictionary = {}
var _entity_cells: Dictionary = {}

func _ready() -> void:
	add_to_group("entity_spatial_indexes")

func register_entity(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return
	var cell := _cell_for(entity.global_position)
	_entity_cells[entity] = cell
	_add_to_cell(cell, entity)

func unregister_entity(entity: Entity) -> void:
	if not _entity_cells.has(entity):
		return
	var cell: Vector2i = _entity_cells[entity]
	_remove_from_cell(cell, entity)
	_entity_cells.erase(entity)

func update_entity(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return
	if not _entity_cells.has(entity):
		register_entity(entity)
		return
	var old_cell: Vector2i = _entity_cells[entity]
	var new_cell := _cell_for(entity.global_position)
	if old_cell == new_cell:
		return
	_remove_from_cell(old_cell, entity)
	_entity_cells[entity] = new_cell
	_add_to_cell(new_cell, entity)

func query_radius(center: Vector2, radius: float) -> Array[Entity]:
	var results: Array[Entity] = []
	var radius_squared := radius * radius
	var min_cell := _cell_for(center - Vector2.ONE * radius)
	var max_cell := _cell_for(center + Vector2.ONE * radius)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell_key := Vector2i(x, y)
			var occupants: Array = _cells.get(cell_key, [])
			for value in occupants:
				if not is_instance_valid(value) or not value is Entity:
					continue
				var entity := value as Entity
				if entity.global_position.distance_squared_to(center) <= radius_squared:
					results.append(entity)
	return results

func _cell_for(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))

func _add_to_cell(cell: Vector2i, entity: Entity) -> void:
	var occupants: Array = _cells.get(cell, [])
	if not occupants.has(entity):
		occupants.append(entity)
	_cells[cell] = occupants

func _remove_from_cell(cell: Vector2i, entity: Entity) -> void:
	if not _cells.has(cell):
		return
	var occupants: Array = _cells[cell]
	occupants.erase(entity)
	if occupants.is_empty():
		_cells.erase(cell)
	else:
		_cells[cell] = occupants
