class_name PlayerUnitSpawner
extends Node2D

## Debug harness for testing multi-unit movement and combat.

@export var unit_scene: PackedScene
@export var spawn_origin := Vector2(-120, 190)
@export var spawn_spacing := 30.0
@export var speed_cycle := [2.0, 2.5, 3.0, 3.5]

var _next_spawn_index := 0
var _spawned_units: Array[Entity] = []

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F5:
		for _index in range(6):
			spawn_unit()
	elif event.keycode == KEY_F6:
		spawn_unit()
	elif event.keycode == KEY_F7:
		_clear_units()
	else:
		return
	get_viewport().set_input_as_handled()

func spawn_unit() -> Entity:
	if unit_scene == null:
		return null
	var unit := unit_scene.instantiate() as Entity
	if unit == null:
		return null
	var row := _next_spawn_index / 3
	var column := _next_spawn_index % 3
	unit.global_position = spawn_origin + Vector2(column * spawn_spacing, row * spawn_spacing)
	unit.set("display_name", "Scout %d" % (_next_spawn_index + 1))
	unit.set("body_color", Color("5fb8c2"))
	unit.collision_layer = 2
	unit.collision_mask = 15
	get_tree().current_scene.add_child(unit)
	var team := unit.get_component(TeamComponent) as TeamComponent
	if team != null:
		team.team = TeamComponent.Team.PLAYER
	var movement := unit.get_component(MovementComponent) as MovementComponent
	if movement != null and not speed_cycle.is_empty():
		movement.speed_meters_per_second = speed_cycle[_next_spawn_index % speed_cycle.size()]
	_spawned_units.append(unit)
	_next_spawn_index += 1
	return unit

func _clear_units() -> void:
	for unit in _spawned_units:
		if is_instance_valid(unit):
			unit.queue_free()
	_spawned_units.clear()
