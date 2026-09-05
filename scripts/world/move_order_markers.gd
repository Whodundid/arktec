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
	var group_controllers := get_tree().get_nodes_in_group("group_movement_controller")
	if not group_controllers.is_empty():
		var group_controller := group_controllers[0] as GroupMovementController
		if group_controller.has_attack_marker():
			var attack_target := group_controller.get_attack_target()
			var attack_alpha := group_controller.get_attack_marker_alpha()
			var attack_color := Color("ef626c")
			attack_color.a = attack_alpha
			var attack_position := attack_target.global_position
			draw_circle(attack_position, 28.0, Color(0.15, 0.02, 0.03, 0.28 * attack_alpha))
			draw_arc(attack_position, 30.0, 0.0, TAU, 32, attack_color, 3.0)
			draw_line(attack_position - Vector2(38, 0), attack_position + Vector2(38, 0), attack_color, 2.0)
			draw_line(attack_position - Vector2(0, 38), attack_position + Vector2(0, 38), attack_color, 2.0)
			draw_string(ThemeDB.fallback_font, attack_position + Vector2(-32, -42), "ATTACK", HORIZONTAL_ALIGNMENT_CENTER, 64.0, 12, attack_color)
		if group_controller.has_group_marker():
			var group_destination: Vector2 = group_controller.get_group_destination()
			var group_alpha := group_controller.get_group_marker_alpha()
			var group_color := group_controller.get_group_marker_color()
			group_color.a = 0.9 * group_alpha
			draw_circle(group_destination, 12.0, Color(0.02, 0.04, 0.05, 0.65 * group_alpha))
			draw_arc(group_destination, 11.0, 0.0, TAU, 24, group_color, 2.0)
			draw_line(group_destination - Vector2(16, 0), group_destination + Vector2(16, 0), group_color, 2.0)
			draw_line(group_destination - Vector2(0, 16), group_destination + Vector2(0, 16), group_color, 2.0)

	for candidate in get_tree().get_nodes_in_group("entities"):
		if not candidate is Entity:
			continue
		var entity := candidate as Entity
		if not group_controllers.is_empty():
			var group_controller := group_controllers[0] as GroupMovementController
			if group_controller.is_entity_in_group_order(entity) or group_controller.is_entity_in_formation(entity):
				continue
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
