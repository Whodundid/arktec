extends Control

var title_font := ThemeDB.fallback_font
var small_font := ThemeDB.fallback_font
const MAX_DISPLAYED_UNITS := 6
const UNIT_CARD_SIZE := Vector2(72, 36)
const UNIT_CARD_GAP := 6.0
var _active_inspected_entity: Entity

func _ready() -> void:
	set_process(true)
	set_process_input(true)
	queue_redraw()

func _input(event: InputEvent) -> void:
	_sync_active_inspection()
	var selected_entities := _selected_entities()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cards := _unit_card_rects(selected_entities)
		for index in range(cards.size()):
			if cards[index].has_point(event.position):
				_active_inspected_entity = selected_entities[index]
				get_viewport().set_input_as_handled()
				return

	var combat := _selected_combat()
	if event is InputEventKey and event.pressed and not event.echo and combat != null:
		if event.is_action_pressed("attack_move"):
			var group_controller := _group_controller()
			if group_controller != null:
				group_controller.arm_attack_move()
			else:
				combat.arm_attack_move()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hold_position"):
			combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
			get_viewport().set_input_as_handled()
			return

	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if combat == null:
		return
	var buttons := _command_button_rects()
	if buttons[0].has_point(event.position):
		combat.set_auto_target_mode(CombatComponent.AUTO_ATTACK_MOVE)
		get_viewport().set_input_as_handled()
	elif buttons[1].has_point(event.position):
		combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
		get_viewport().set_input_as_handled()
	elif combat.attack_move_armed:
		var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		var group_controller := _group_controller()
		if group_controller != null and group_controller.has_attack_move_armed():
			group_controller.confirm_attack_move(world_position)
		elif not combat.try_set_target_at(world_position):
			combat.confirm_attack_move(world_position)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_sync_active_inspection()
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var panel := Rect2(28, 28, 330, 132)
	draw_style_box(_panel(Color("101b25d9"), Color("4d6f78")), panel)
	draw_string(title_font, Vector2(48, 66), "ARTIFACT RUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("f4d58b"))
	draw_string(small_font, Vector2(48, 94), "VERTICAL SLICE // FIELD BOOTSTRAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9cb5b5"))
	draw_string(small_font, Vector2(48, 128), "DAY 01    10:42    OUTPOST SECURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dce5df"))

	var formation_text := "OFF"
	var formation_controllers := get_tree().get_nodes_in_group("group_movement_controller")
	if not formation_controllers.is_empty() and (formation_controllers[0] as GroupMovementController).is_formation_enabled():
		formation_text = "ON"
	draw_string(small_font, Vector2(48, size.y - 60), "RIGHT-CLICK MOVE   F4 FORMATION %s   F5 SQUAD   F6 UNIT   F7 CLEAR" % formation_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dce5df"))

	var buttons := _command_button_rects()
	var selected_entities := _selected_entities()
	draw_style_box(_panel(Color("101b25"), Color("4d6f78")), Rect2(buttons[0].position - Vector2(16, 74), Vector2(332, 132)))
	_draw_unit_cards(selected_entities)
	var selected_entity := _active_inspected_entity
	if selected_entity != null:
		var unit_name := "UNIT"
		var display_name = selected_entity.get("display_name")
		if display_name != null:
			unit_name = str(display_name)
		var health := selected_entity.get_component(HealthComponent) as HealthComponent
		draw_string(title_font, buttons[0].position + Vector2(0, -42), unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f4d58b"))
		if health != null:
			var health_text := "HP %d / %d" % [roundi(health.current_health), roundi(health.maximum_health)]
			draw_string(small_font, buttons[0].position + Vector2(0, -26), health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dce5df"))
	var combat := _selected_combat()
	if combat != null:
		_draw_command_button(buttons[0], "ATTACK-MOVE", combat.auto_target_mode == CombatComponent.AUTO_ATTACK_MOVE)
		_draw_command_button(buttons[1], "HOLD POSITION", combat.auto_target_mode == CombatComponent.AUTO_HOLD_POSITION)

func _selected_combat() -> CombatComponent:
	var selected_entity := _selected_entity()
	if selected_entity != null and _is_player_owned(selected_entity):
		return selected_entity.get_component(CombatComponent) as CombatComponent
	return null

func _group_controller() -> GroupMovementController:
	var controllers := get_tree().get_nodes_in_group("group_movement_controller")
	return controllers[0] as GroupMovementController if not controllers.is_empty() else null

func _is_player_owned(entity: Entity) -> bool:
	var team := entity.get_component(TeamComponent) as TeamComponent
	return team != null and team.is_player_controlled()

func _selected_entity() -> Entity:
	_sync_active_inspection()
	return _active_inspected_entity

func _selected_entities() -> Array[Entity]:
	var selected: Array[Entity] = []
	for candidate in get_tree().get_nodes_in_group("entities"):
		if candidate is Entity and (candidate as Entity).is_selected:
			selected.append(candidate as Entity)
	return selected

func _sync_active_inspection() -> void:
	var selected := _selected_entities()
	if is_instance_valid(_active_inspected_entity) and _active_inspected_entity.is_selected:
		return
	_active_inspected_entity = selected[0] if not selected.is_empty() else null

func _unit_card_rects(selected: Array[Entity]) -> Array[Rect2]:
	var cards: Array[Rect2] = []
	var displayed_count := mini(selected.size(), MAX_DISPLAYED_UNITS)
	var size := get_viewport_rect().size
	var strip := _unit_strip_rect()
	var origin := strip.position + Vector2(10.0, 10.0)
	for index in range(displayed_count):
		cards.append(Rect2(origin + Vector2(index * (UNIT_CARD_SIZE.x + UNIT_CARD_GAP), 0), UNIT_CARD_SIZE))
	return cards

func _draw_unit_cards(selected: Array[Entity]) -> void:
	var cards := _unit_card_rects(selected)
	var size := get_viewport_rect().size
	draw_style_box(_panel(Color("101b25"), Color("4d6f78")), _unit_strip_rect())
	for index in range(cards.size()):
		var entity := selected[index]
		var card := cards[index]
		var active := entity == _active_inspected_entity
		draw_style_box(_panel(Color("243844") if not active else Color("384c58"), entity.selection_color()), card)
		draw_circle(card.position + Vector2(12, 12), 5.0, entity.selection_color())
		var unit_name := str(entity.get("display_name"))
		draw_string(small_font, card.position + Vector2(22, 16), unit_name, HORIZONTAL_ALIGNMENT_LEFT, 64, 10, Color("dce5df"))
		var health := entity.get_component(HealthComponent) as HealthComponent
		if health == null:
			continue
		var health_ratio := clampf(health.current_health / maxf(health.maximum_health, 1.0), 0.0, 1.0)
		var bar := Rect2(card.position + Vector2(8, 25), Vector2(card.size.x - 16.0, 5))
		draw_rect(bar, Color("101b25"), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * health_ratio, bar.size.y)), entity.selection_color(), true)
	if selected.size() > MAX_DISPLAYED_UNITS:
		draw_string(small_font, Vector2(size.x * 0.5 - 28.0, size.y - 15.0), "+%d MORE" % (selected.size() - MAX_DISPLAYED_UNITS), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("9cb5b5"))

func _unit_strip_rect() -> Rect2:
	var size := get_viewport_rect().size
	var strip_width := MAX_DISPLAYED_UNITS * UNIT_CARD_SIZE.x + (MAX_DISPLAYED_UNITS - 1) * UNIT_CARD_GAP + 20.0
	var right_panel_left := _command_button_rects()[0].position.x - 16.0
	return Rect2(Vector2(right_panel_left - strip_width, size.y - 56.0), Vector2(strip_width, 56.0))

func _command_button_rects() -> Array[Rect2]:
	var size := get_viewport_rect().size
	# The outer panel is 332x82 with a 16px inset around the buttons.
	# Position the button origin so the panel itself touches both edges.
	# Push the outer right edge slightly beyond the viewport so its border is
	# clipped cleanly at the screen edge.
	var origin := Vector2(size.x - 300.0, size.y - 42.0)
	return [Rect2(origin, Vector2(140, 42)), Rect2(origin + Vector2(150, 0), Vector2(140, 42))]

func _draw_command_button(rect: Rect2, label: String, active: bool) -> void:
	var fill := Color("7e4f8f") if active else Color("243844")
	var border := Color("d5a7df") if active else Color("4d6f78")
	draw_style_box(_panel(fill, border), rect)
	draw_string(small_font, rect.position + Vector2(12, 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f4d58b"))

func _panel(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
