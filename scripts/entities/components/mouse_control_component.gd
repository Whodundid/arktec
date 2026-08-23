class_name MouseControlComponent
extends EntityComponent

## Minimal RTS-style selection and move-order input.

@export var selection_radius := 18.0
@export var debug_control_override := false

var selected := false

func _ready() -> void:
	set_process_unhandled_input(true)
	add_to_group("mouse_controlled_entities")

func _unhandled_input(event: InputEvent) -> void:
	if entity == null or not _can_be_controlled():
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_position := entity.get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_position.distance_to(entity.global_position) <= selection_radius:
				_select_entity()
				get_viewport().set_input_as_handled()

func set_selected(value: bool) -> void:
	selected = value
	if entity != null:
		entity.set_selected(value)

func can_be_controlled() -> bool:
	return _can_be_controlled()

func can_be_selected() -> bool:
	return entity != null

func _select_entity() -> void:
	for other in get_tree().get_nodes_in_group("mouse_controlled_entities"):
		if other is MouseControlComponent:
			other.set_selected(false)
	set_selected(true)

func _can_be_controlled() -> bool:
	if debug_control_override:
		return true
	var team_component := entity.get_component(TeamComponent) as TeamComponent
	return team_component != null and team_component.is_player_controlled()
