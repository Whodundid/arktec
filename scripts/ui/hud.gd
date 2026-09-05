extends Control

var title_font := ThemeDB.fallback_font
var small_font := ThemeDB.fallback_font
const MAX_DISPLAYED_UNITS := 6
const UNIT_CARD_SIZE := Vector2(72, 36)
const UNIT_CARD_GAP := 6.0
var _active_inspected_entity: Entity
var _build_mode := -1
var _pending_build_position := Vector2.ZERO
var _pending_build_type := -1
var _pending_build_builder: Entity
const BUILD_SUPPLY := EnemySpawnerBuilding.BuildingType.SUPPLY
const BUILD_BARRACKS := EnemySpawnerBuilding.BuildingType.BARRACKS
const BUILD_MAIN := EnemySpawnerBuilding.BuildingType.MAIN
const TRAIN_GUARD := AlertComponent.Role.GUARD
const TRAIN_BUILDER := AlertComponent.Role.BUILDER
const TRAIN_FLANKER := AlertComponent.Role.FLANKER

func _ready() -> void:
	set_process(true)
	set_process_input(true)
	queue_redraw()

func _input(event: InputEvent) -> void:
	_sync_active_inspection()
	var selected_entities := _selected_entities()
	var selected_builder := _selected_builder()
	var selected_building := _selected_player_building()
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_gameplay_hotkey(event.keycode if event.keycode != KEY_NONE else event.physical_keycode, selected_builder, selected_building):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		if selected_builder != null:
			_build_mode = -1 if _build_mode >= 0 else BUILD_SUPPLY
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and selected_building != null:
		var train_buttons := _train_button_rects()
		var training_roles := _training_roles(selected_building)
		for index in range(training_roles.size()):
			if train_buttons[index].has_point(event.position):
				_request_training(selected_building, training_roles[index])
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _build_mode >= 0:
		var build_buttons := _build_button_rects()
		var build_types := [BUILD_SUPPLY, BUILD_BARRACKS, BUILD_MAIN]
		for index in range(build_buttons.size()):
			if build_buttons[index].has_point(event.position):
				if ResourceLedger.can_afford(TeamComponent.Team.PLAYER, _get_build_cost(build_types[index])):
					_build_mode = build_types[index]
				get_viewport().set_input_as_handled()
				return
		var sandbox_nodes := get_tree().get_nodes_in_group("battle_sandboxes")
		if selected_builder != null and not sandbox_nodes.is_empty():
			var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
			if bool(sandbox_nodes[0].call("request_player_construction", selected_builder, world_position, _build_mode)):
				_pending_build_position = world_position
				_pending_build_type = _build_mode
				_pending_build_builder = selected_builder
				_build_mode = -1
			get_viewport().set_input_as_handled()
		return
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
			var group_controller := _group_controller()
			if group_controller != null:
				group_controller.request_stance(CombatComponent.AUTO_HOLD_POSITION)
			get_viewport().set_input_as_handled()
			return

	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if combat == null:
		return
	var buttons := _command_button_rects()
	if buttons[0].has_point(event.position):
		var group_controller := _group_controller()
		if group_controller != null:
			group_controller.request_stance(CombatComponent.AUTO_ATTACK_MOVE)
		get_viewport().set_input_as_handled()
	elif buttons[1].has_point(event.position):
		var group_controller := _group_controller()
		if group_controller != null:
			group_controller.request_stance(CombatComponent.AUTO_HOLD_POSITION)
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
	if _pending_build_type >= 0:
		var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
		if not is_instance_valid(_pending_build_builder) or sandboxes.is_empty() or bool(sandboxes[0].call("has_player_construction_started", _pending_build_builder)):
			_pending_build_type = -1
			_pending_build_builder = null
	queue_redraw()

func _draw() -> void:
	@warning_ignore("shadowed_variable_base_class")
	var size := get_viewport_rect().size
	var performance_panel := Rect2(28, 28, 190, 88)

	draw_style_box(_panel(Color("101b25"), Color("4d6f78")), performance_panel)
	draw_string(small_font, performance_panel.position + Vector2(12, 22), "FPS: %3d" % RuntimeLogger.get_fps(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dce5df"))
	draw_string(small_font, performance_panel.position + Vector2(12, 42), "UPS: %3d" % RuntimeLogger.get_ups(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9cb5b5"))
	draw_string(small_font, performance_panel.position + Vector2(12, 62), "FRAME: %5.2f ms" % RuntimeLogger.get_frame_time_ms(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("dce5df"))
	draw_string(small_font, performance_panel.position + Vector2(12, 77), "PHYS:  %5.2f ms" % RuntimeLogger.get_physics_time_ms(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9cb5b5"))
	draw_string(small_font, performance_panel.position + Vector2(108, 22), "ORE: %d" % ResourceLedger.get_ore(TeamComponent.Team.PLAYER), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f4d58b"))

	var buttons := _command_button_rects()
	var selected_entities := _selected_entities()
	var right_panel := Rect2(buttons[0].position - Vector2(16, 190), Vector2(332, 232))
	draw_style_box(_panel(Color("101b25"), Color("4d6f78")), right_panel)

	var hovered_price_label := ""
	var hovered_price_cost := 0
	var selected_building := _selected_player_building()
	var training_roles := _training_roles(selected_building)

	if selected_building != null and not training_roles.is_empty():
		var train_buttons := _train_button_rects()
		var train_panel := Rect2(train_buttons[0].position - Vector2(8, 12), Vector2(300, 58))
		draw_style_box(_panel(Color("101b25"), Color("4d6f78")), train_panel)
		var train_labels := _training_labels(selected_building)
		var train_actions := ["train_guard", "train_pursuer", "train_flanker"] if selected_building.building_type == EnemySpawnerBuilding.BuildingType.BARRACKS else ["train_builder"]
		for index in range(training_roles.size()):
			var can_pay := ResourceLedger.can_afford(TeamComponent.Team.PLAYER, selected_building.training_cost)
			var queue_available := selected_building.get_training_queue_count() < selected_building.get_training_queue_limit()
			_draw_build_button(train_buttons[index], "%s [%s]" % [train_labels[index], _user_settings().get_key_name(_user_settings().get_keybind(train_actions[index]))], false, can_pay and queue_available)
			if train_buttons[index].has_point(get_viewport().get_mouse_position()):
				hovered_price_label = train_labels[index]
				hovered_price_cost = selected_building.training_cost

	if _build_mode >= 0 and _selected_builder() != null:
		var build_buttons := _build_button_rects()
		var build_panel := Rect2(build_buttons[0].position - Vector2(8, 12), Vector2(300, 58))
		draw_style_box(_panel(Color("101b25"), Color("4d6f78")), build_panel)
		var labels := ["SUPPLY", "BARRACKS", "COMMAND"]
		var build_actions := ["build_supply", "build_barracks", "build_main"]

		for index in range(build_buttons.size()):
			var building_type: int = [BUILD_SUPPLY, BUILD_BARRACKS, BUILD_MAIN][index]
			var affordable := ResourceLedger.can_afford(TeamComponent.Team.PLAYER, _get_build_cost(building_type))
			_draw_build_button(build_buttons[index], "%s [%s]" % [labels[index], _user_settings().get_key_name(_user_settings().get_keybind(build_actions[index]))], _build_mode == building_type, affordable)
			if build_buttons[index].has_point(get_viewport().get_mouse_position()):
				hovered_price_label = labels[index]
				hovered_price_cost = _get_build_cost(building_type)

	if _build_mode >= 0 and _selected_builder() != null:
		_draw_building_preview()
	if _pending_build_type >= 0:
		_draw_building_preview_at(_pending_build_position, _pending_build_type, false)
	_draw_unit_cards(selected_entities)

	var selected_entity := _active_inspected_entity
	if selected_entity != null:
		var unit_name := "UNIT"
		var display_name = selected_entity.get("display_name")
		if display_name != null:
			unit_name = str(display_name)
		var health := selected_entity.get_component(HealthComponent) as HealthComponent
		draw_string(title_font, buttons[0].position + Vector2(0, -160), unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f4d58b"))
		if health != null:
			var health_text := "HP %d / %d" % [roundi(health.current_health), roundi(health.maximum_health)]
			draw_string(small_font, buttons[0].position + Vector2(0, -144), health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dce5df"))
		var selected_team := selected_entity.get_component(TeamComponent) as TeamComponent
		if selected_team != null:
			var faction_ore := "FACTION ORE %d" % ResourceLedger.get_ore(selected_team.team)
			draw_string(small_font, buttons[0].position + Vector2(148, -144), faction_ore, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f4d58b"))
			var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
			if not sandboxes.is_empty() and sandboxes[0].has_method("get_faction_supply"):
				var supply: Dictionary = sandboxes[0].call("get_faction_supply", selected_team.team)
				if not supply.is_empty():
					var supply_text := "SUPPLY %d / %d" % [int(supply.get("current", 0)), int(supply.get("maximum", 0))]
					draw_string(small_font, buttons[0].position + Vector2(148, -124), supply_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9ed8e0"))
		if selected_entity is EnemySpawnerBuilding:
			var spawner := selected_entity as EnemySpawnerBuilding
			if spawner.is_training() and spawner.is_training_supply_blocked():
				var paused_text := "TRAINING PAUSED: SUPPLY   QUEUE %d/%d" % [spawner.get_training_queue_count(), spawner.get_training_queue_limit()]
				draw_string(small_font, buttons[0].position + Vector2(0, -124), paused_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e5b85b"))
			elif spawner.is_training():
				var training_text := "TRAINING: %s %d%%   QUEUE %d/%d" % [spawner.get_training_role_name(), roundi(spawner.get_training_progress() * 100.0), spawner.get_training_queue_count(), spawner.get_training_queue_limit()]
				draw_string(small_font, buttons[0].position + Vector2(0, -124), training_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("7fb6df"))
			elif spawner.get_training_queue_count() > 0:
				var queued_text := "TRAINING PAUSED: SUPPLY   QUEUE %d/%d" % [spawner.get_training_queue_count(), spawner.get_training_queue_limit()]
				draw_string(small_font, buttons[0].position + Vector2(0, -124), queued_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e5b85b"))
	var ai_debug_panel := Rect2(28.0, 130.0, 300.0, 118.0)
	draw_style_box(_panel(Color("101b25"), Color("4d6f78")), ai_debug_panel)
	_draw_ai_debug_panel(selected_entity, ai_debug_panel)
	var combat := _selected_combat()
	if combat != null:
		_draw_command_button(buttons[0], "ATTACK-MOVE", combat.auto_target_mode == CombatComponent.AUTO_ATTACK_MOVE)
		_draw_command_button(buttons[1], "HOLD POSITION", combat.auto_target_mode == CombatComponent.AUTO_HOLD_POSITION)
	if not hovered_price_label.is_empty():
		_draw_price_tooltip(hovered_price_label, hovered_price_cost)

func _selected_combat() -> CombatComponent:
	var selected_entity := _selected_entity()
	if selected_entity != null and _is_player_owned(selected_entity):
		return selected_entity.get_component(CombatComponent) as CombatComponent
	return null

func _selected_builder() -> Entity:
	var selected_entity := _selected_entity()
	if selected_entity == null or not _is_player_owned(selected_entity):
		return null
	var alert := selected_entity.get_component(AlertComponent) as AlertComponent
	return selected_entity if alert != null and alert.role == AlertComponent.Role.BUILDER else null

func _selected_player_building() -> EnemySpawnerBuilding:
	var selected_entity := _selected_entity()
	if selected_entity is EnemySpawnerBuilding and _is_player_owned(selected_entity):
		return selected_entity as EnemySpawnerBuilding
	return null

func _training_roles(building: EnemySpawnerBuilding) -> Array:
	if building == null:
		return []
	if building.building_type == EnemySpawnerBuilding.BuildingType.BARRACKS:
		return [TRAIN_GUARD, AlertComponent.Role.PURSUER, TRAIN_FLANKER]
	if building.building_type == EnemySpawnerBuilding.BuildingType.MAIN:
		return [TRAIN_BUILDER]
	return []

func _training_labels(building: EnemySpawnerBuilding) -> Array[String]:
	if building == null:
		return []
	if building.building_type == EnemySpawnerBuilding.BuildingType.BARRACKS:
		return ["GUARD", "PURSUER", "FLANKER"]
	if building.building_type == EnemySpawnerBuilding.BuildingType.MAIN:
		return ["BUILDER"]
	return []

func _handle_gameplay_hotkey(keycode: int, selected_builder: Entity, selected_building: EnemySpawnerBuilding) -> bool:
	if selected_building != null:
		var training_roles := _training_roles(selected_building)
		var training_actions := ["train_guard", "train_pursuer", "train_flanker"] if selected_building.building_type == EnemySpawnerBuilding.BuildingType.BARRACKS else ["train_builder"]
		for index in range(training_roles.size()):
			if keycode == _user_settings().get_keybind(training_actions[index]):
				_request_training(selected_building, training_roles[index])
				return true
	if selected_builder != null:
		var build_types := [BUILD_SUPPLY, BUILD_BARRACKS, BUILD_MAIN]
		var build_actions := ["build_supply", "build_barracks", "build_main"]
		for index in range(build_types.size()):
			if keycode == _user_settings().get_keybind(build_actions[index]):
				if ResourceLedger.can_afford(TeamComponent.Team.PLAYER, _get_build_cost(build_types[index])):
					_build_mode = build_types[index]
				return true
	return false

func _request_training(building: EnemySpawnerBuilding, role: int) -> void:
	if ResourceLedger.can_afford(TeamComponent.Team.PLAYER, building.training_cost) and building.get_training_queue_count() < building.get_training_queue_limit():
		building.request_training(role)

func _user_settings() -> Node:
	return get_node("/root/UserSettings")

func _has_training_supply(building: EnemySpawnerBuilding) -> bool:
	var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
	if building == null or sandboxes.is_empty() or not sandboxes[0].has_method("can_start_unit_training"):
		return true
	return bool(sandboxes[0].call("can_start_unit_training", building))

func _draw_ai_debug_panel(selected_entity: Entity, panel_rect: Rect2) -> void:
	draw_string(title_font, panel_rect.position + Vector2(10, 22), "AI DEBUG", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f4d58b"))
	if selected_entity == null:
		draw_string(small_font, panel_rect.position + Vector2(10, 48), "Select an AI unit to inspect", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9cb5b5"))
		return
	var alert := selected_entity.get_component(AlertComponent) as AlertComponent
	if alert == null:
		draw_string(small_font, panel_rect.position + Vector2(10, 48), "Selected entity has no AI", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9cb5b5"))
		return
	var team := selected_entity.get_component(TeamComponent) as TeamComponent
	var faction := "Unknown"
	if team != null:
		faction = TeamComponent.Team.keys()[team.team].capitalize()
	draw_string(small_font, panel_rect.position + Vector2(10, 45), "%s   %s" % [faction, AlertComponent.get_role_name(alert.role)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, selected_entity.selection_color())
	draw_string(small_font, panel_rect.position + Vector2(10, 66), "Now:  " + alert.get_debug_active_action(), HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x, 12, Color("dce5df"))
	draw_string(small_font, panel_rect.position + Vector2(10, 86), "Next: " + alert.get_debug_next_goal(), HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x, 12, Color("9cb5b5"))
	var movement := selected_entity.get_component(MovementComponent) as MovementComponent
	var destination_text := "none"
	if movement != null and movement.get_destination_position() is Vector2:
		destination_text = "(%d, %d)" % [roundi((movement.get_destination_position() as Vector2).x), roundi((movement.get_destination_position() as Vector2).y)]
	draw_string(small_font, panel_rect.position + Vector2(10, 106), "Destination: " + destination_text, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x, 11, Color("718f91"))

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
	@warning_ignore("shadowed_variable_base_class")
	var strip := _unit_strip_rect()
	var origin := strip.position + Vector2(10.0, 10.0)
	for index in range(displayed_count):
		cards.append(Rect2(origin + Vector2(index * (UNIT_CARD_SIZE.x + UNIT_CARD_GAP), 0), UNIT_CARD_SIZE))
	return cards

func _draw_unit_cards(selected: Array[Entity]) -> void:
	var cards := _unit_card_rects(selected)
	@warning_ignore("shadowed_variable_base_class")
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
	@warning_ignore("shadowed_variable_base_class")
	var size := get_viewport_rect().size
	var strip_width := MAX_DISPLAYED_UNITS * UNIT_CARD_SIZE.x + (MAX_DISPLAYED_UNITS - 1) * UNIT_CARD_GAP + 20.0
	var right_panel_left := _command_button_rects()[0].position.x - 16.0
	return Rect2(Vector2(right_panel_left - strip_width, size.y - 56.0), Vector2(strip_width, 56.0))

func _command_button_rects() -> Array[Rect2]:
	@warning_ignore("shadowed_variable_base_class")
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

func _build_button_rects() -> Array[Rect2]:
	@warning_ignore("shadowed_variable_base_class")
	var size := get_viewport_rect().size
	var origin := Vector2(size.x - 300.0, size.y - 112.0)
	return [Rect2(origin, Vector2(92, 42)), Rect2(origin + Vector2(100, 0), Vector2(92, 42)), Rect2(origin + Vector2(200, 0), Vector2(92, 42))]

func _train_button_rects() -> Array[Rect2]:
	@warning_ignore("shadowed_variable_base_class")
	var size := get_viewport_rect().size
	var origin := Vector2(size.x - 300.0, size.y - 170.0)
	return [Rect2(origin, Vector2(92, 42)), Rect2(origin + Vector2(100, 0), Vector2(92, 42)), Rect2(origin + Vector2(200, 0), Vector2(92, 42))]

func _draw_build_button(rect: Rect2, label: String, active: bool, enabled: bool = true) -> void:
	var fill := Color("49643f") if active else (Color("243844") if enabled else Color("18252c"))
	var border := Color("a8d47a") if active else (Color("4d6f78") if enabled else Color("33464d"))
	draw_style_box(_panel(fill, border), rect)
	draw_string(small_font, rect.position + Vector2(8, 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f4d58b") if enabled else Color("6d7b7d"))

func _draw_building_preview() -> void:
	var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
	if sandboxes.is_empty():
		return
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
	_draw_building_preview_at(world_position, _build_mode, true)

func _draw_building_preview_at(world_position: Vector2, building_type: int, show_validity: bool) -> void:
	var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
	if sandboxes.is_empty():
		return
	var sandbox := sandboxes[0]
	var footprint_scale := _get_building_footprint_scale(building_type)
	var valid := true
	if show_validity:
		valid = bool(sandbox.call("can_place_player_construction", world_position, building_type))
		valid = valid and ResourceLedger.can_afford(TeamComponent.Team.PLAYER, _get_build_cost(building_type))
	var canvas_transform := get_viewport().get_canvas_transform()
	var screen_position: Vector2 = canvas_transform * world_position
	var zoom_scale := Vector2(canvas_transform.x.length(), canvas_transform.y.length())
	var preview_size := Vector2(60.0, 48.0) * footprint_scale * zoom_scale
	var preview_rect := Rect2(screen_position - preview_size * 0.5, preview_size)
	var color := Color("77e28a") if valid else Color("e45b61")
	draw_rect(preview_rect, Color(color, 0.28), true)
	draw_rect(preview_rect, Color(color, 0.95), false, 2.0)
	draw_line(preview_rect.position, preview_rect.end, Color(color, 0.55), 1.0)
	draw_line(Vector2(preview_rect.end.x, preview_rect.position.y), Vector2(preview_rect.position.x, preview_rect.end.y), Color(color, 0.55), 1.0)
	var label := "CONSTRUCTION SITE" if not show_validity else ("VALID SITE" if valid else ("NEED ORE" if not ResourceLedger.can_afford(TeamComponent.Team.PLAYER, _get_build_cost(building_type)) else "BLOCKED"))
	draw_string(small_font, preview_rect.position + Vector2(0.0, -8.0), label, HORIZONTAL_ALIGNMENT_CENTER, preview_rect.size.x, 11, color)

func _get_building_footprint_scale(building_type: int) -> float:
	var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
	if sandboxes.is_empty():
		return 1.0
	var sandbox := sandboxes[0]
	if building_type == BUILD_SUPPLY:
		return float(sandbox.get("supply_building_footprint_scale"))
	if building_type == BUILD_BARRACKS:
		return float(sandbox.get("barracks_building_footprint_scale"))
	return float(sandbox.get("main_building_footprint_scale"))

func _draw_price_tooltip(label: String, cost: int) -> void:
	@warning_ignore("shadowed_variable_base_class")
	var size := get_viewport_rect().size
	var mouse_position := get_viewport().get_mouse_position()
	var tooltip_size := Vector2(142.0, 30.0)
	var tooltip_position := mouse_position + Vector2(14.0, 14.0)
	tooltip_position.x = minf(tooltip_position.x, size.x - tooltip_size.x - 8.0)
	tooltip_position.y = minf(tooltip_position.y, size.y - tooltip_size.y - 8.0)
	var tooltip := Rect2(tooltip_position, tooltip_size)
	draw_style_box(_panel(Color("17242b"), Color("f4d58b")), tooltip)
	draw_string(small_font, tooltip.position + Vector2(9, 20), "%s: %d ORE" % [label, cost], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f4d58b"))

func _get_build_cost(building_type: int) -> int:
	var sandboxes := get_tree().get_nodes_in_group("battle_sandboxes")
	if sandboxes.is_empty():
		return 0
	var sandbox := sandboxes[0]
	if building_type == BUILD_SUPPLY:
		return int(sandbox.get("supply_building_cost"))
	if building_type == BUILD_BARRACKS:
		return int(sandbox.get("barracks_building_cost"))
	return int(sandbox.get("expansion_cost"))

func _panel(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
