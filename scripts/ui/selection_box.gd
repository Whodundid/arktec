extends Control

## Screen-space RTS selection rectangle.

@export var drag_threshold := 8.0
@export var fill_color := Color(0.82, 0.66, 0.35, 0.16)
@export var border_color := Color("f4d58b")

var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_current := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)
	set_process(true)

func _process(_delta: float) -> void:
	_update_world_hover(get_viewport().get_mouse_position())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start = event.position
			_drag_current = event.position
			queue_redraw()
		else:
			if _dragging and _drag_start.distance_to(event.position) >= drag_threshold:
				_select_entities_in_box()
				get_viewport().set_input_as_handled()
			elif _dragging:
				_select_entity_at(event.position)
			_dragging = false
			queue_redraw()
	elif event is InputEventMouseMotion and _dragging:
		_drag_current = event.position
		queue_redraw()

func _draw() -> void:
	if not _dragging or _drag_start.distance_to(_drag_current) < drag_threshold:
		return

	var selection_rect := _screen_rect(_drag_start, _drag_current)
	draw_rect(selection_rect, fill_color, true)
	draw_rect(selection_rect, border_color, false, 2.0)

func _select_entities_in_box() -> void:
	var selection_rect := _screen_rect(_drag_start, _drag_current)
	var unit_selectables: Array[MouseControlComponent] = []
	var building_selectables: Array[MouseControlComponent] = []
	var world_selectables: Array[Node2D] = []

	for selectable in get_tree().get_nodes_in_group("mouse_controlled_entities"):
		if not selectable is MouseControlComponent or not selectable.can_be_selected():
			continue
		var entity := selectable.entity as Entity
		if entity == null:
			continue
		var screen_position := get_viewport().get_canvas_transform() * entity.global_position
		if selection_rect.has_point(screen_position):
			if entity.grounded:
				building_selectables.append(selectable)
			else:
				unit_selectables.append(selectable)
	for candidate in get_tree().get_nodes_in_group("world_selectables"):
		if not candidate is Node2D or not is_instance_valid(candidate) or not bool(candidate.call("can_be_selected")):
			continue
		var world_selectable := candidate as Node2D
		var selectable_screen_position := get_viewport().get_canvas_transform() * Vector2(world_selectable.call("get_selection_position"))
		if selection_rect.has_point(selectable_screen_position):
			world_selectables.append(world_selectable)

	# Marquee selection is unit-first: buildings inside a mixed drag are not
	# included, so a formation can be selected without accidentally selecting a
	# nearby Command Center. If the box contains buildings only, select every
	# building of the type nearest the box center.
	if not unit_selectables.is_empty():
		_clear_selection()
		for selectable in unit_selectables:
			selectable.set_selected(true)
		return
	if building_selectables.is_empty():
		if world_selectables.size() == 1:
			_clear_selection()
			world_selectables[0].call("set_selected", true)
		return

	var box_center := selection_rect.get_center()
	var closest_building: MouseControlComponent = building_selectables[0]
	var closest_distance := INF
	for selectable in building_selectables:
		var entity := selectable.entity as Entity
		var screen_position := get_viewport().get_canvas_transform() * entity.global_position
		var distance := screen_position.distance_squared_to(box_center)
		if distance < closest_distance:
			closest_distance = distance
			closest_building = selectable
	_clear_selection()
	var selected_building := closest_building.entity as EnemySpawnerBuilding
	for selectable in building_selectables:
		var building := selectable.entity as EnemySpawnerBuilding
		if selected_building == null or building == null or building.building_type == selected_building.building_type:
			selectable.set_selected(true)

func _select_entity_at(screen_position: Vector2) -> void:
	var mouse_world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var closest: MouseControlComponent = null
	var closest_distance := INF

	for selectable in get_tree().get_nodes_in_group("mouse_controlled_entities"):
		if not selectable is MouseControlComponent or not selectable.can_be_selected():
			continue
		var entity := selectable.entity as Entity
		if entity == null:
			continue
		var distance := entity.global_position.distance_to(mouse_world_position)
		if distance <= selectable.selection_radius and distance < closest_distance:
			closest = selectable
			closest_distance = distance

	if closest != null:
		_clear_selection()
		closest.set_selected(true)
		get_viewport().set_input_as_handled()
		return
	var closest_world_selectable: Node2D
	for candidate in get_tree().get_nodes_in_group("world_selectables"):
		if not candidate is Node2D or not is_instance_valid(candidate) or not bool(candidate.call("can_be_selected")):
			continue
		var world_selectable := candidate as Node2D
		if not bool(world_selectable.call("contains_world_position", mouse_world_position)):
			continue
		var selection_position: Vector2 = world_selectable.call("get_selection_position")
		var distance := selection_position.distance_squared_to(mouse_world_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_world_selectable = world_selectable
	if closest_world_selectable != null:
		_clear_selection()
		closest_world_selectable.call("set_selected", true)
		get_viewport().set_input_as_handled()

func _clear_selection() -> void:
	for selectable in get_tree().get_nodes_in_group("mouse_controlled_entities"):
		if selectable is MouseControlComponent:
			selectable.set_selected(false)
	for selectable in get_tree().get_nodes_in_group("world_selectables"):
		if selectable is Node2D and is_instance_valid(selectable):
			selectable.call("set_selected", false)

func _update_world_hover(screen_position: Vector2) -> void:
	var mouse_world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var hovered: Node2D
	var closest_distance := INF
	for candidate in get_tree().get_nodes_in_group("world_selectables"):
		if not candidate is Node2D or not is_instance_valid(candidate) or not bool(candidate.call("can_be_selected")):
			continue
		var selectable := candidate as Node2D
		if not bool(selectable.call("contains_world_position", mouse_world_position)):
			continue
		var selection_position: Vector2 = selectable.call("get_selection_position")
		var distance := selection_position.distance_squared_to(mouse_world_position)
		if distance < closest_distance:
			closest_distance = distance
			hovered = selectable
	for candidate in get_tree().get_nodes_in_group("world_selectables"):
		if candidate is Node2D and is_instance_valid(candidate):
			candidate.call("set_hovered", candidate == hovered)

func _screen_rect(first: Vector2, second: Vector2) -> Rect2:
	return Rect2(first, second - first).abs()
