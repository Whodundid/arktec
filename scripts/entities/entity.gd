class_name Entity
extends CharacterBody2D

## Base for world entities. Behavior is composed from child EntityComponent nodes.

var _components: Array[EntityComponent] = []
var is_selected := false
var facing_direction := Vector2.UP
@export_range(0.0, 1440.0, 1.0) var turning_rate_degrees_per_second := 720.0

func _ready() -> void:
	for child in get_children():
		if child is EntityComponent:
			_components.append(child)
			child.attach_to_entity(self)

	for component in _components:
		component.on_entity_ready()

func get_component(component_type: Variant) -> EntityComponent:
	for component in _components:
		if is_instance_of(component, component_type):
			return component
	return null

func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()

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
