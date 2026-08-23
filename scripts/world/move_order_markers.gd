extends Node2D

## World-space destination indicators for active movement orders.

@export_category("Debug")
@export var show_all_entity_markers := false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		show_all_entity_markers = not show_all_entity_markers
		print("Move order markers: %s" % ("ALL ENTITIES" if show_all_entity_markers else "PLAYER ONLY"))
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for candidate in get_tree().get_nodes_in_group("entities"):
		if not candidate is Entity:
			continue
		var entity := candidate as Entity
		var team := entity.get_component(TeamComponent) as TeamComponent
		if not show_all_entity_markers and (team == null or not team.is_player_controlled()):
			continue
		var movement := entity.get_component(MovementComponent) as MovementComponent
		if movement == null:
			continue
		var destination: Variant = movement.get_destination_position()
		var alpha := movement.get_destination_marker_alpha()
		if destination == null or alpha <= 0.0:
			continue
		var color := entity.selection_color()
		color.a = 0.9 * alpha
		draw_circle(destination as Vector2, 10.0, Color(0.02, 0.04, 0.05, 0.65 * alpha))
		draw_arc(destination as Vector2, 9.0, 0.0, TAU, 24, color, 2.0)
		draw_line(destination as Vector2 - Vector2(14, 0), destination as Vector2 + Vector2(14, 0), color, 2.0)
		draw_line(destination as Vector2 - Vector2(0, 14), destination as Vector2 + Vector2(0, 14), color, 2.0)
