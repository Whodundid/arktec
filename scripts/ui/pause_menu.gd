extends CanvasLayer

## Pause overlay. This layer must keep processing while the rest of the scene
## tree is paused so Escape and the Resume button remain available.

var _overlay: Control
var _resume_button: Button
var _settings_button: Button
var _hint: Label
var _settings_section: VBoxContainer
var _camera_speed_slider: HSlider
var _camera_speed_value: Label
var _tile_details_check: CheckButton
var _nameplates_check: CheckButton
var _team_markers_check: CheckButton

func _ready() -> void:
	# The menu must receive Escape both before and after pausing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var should_pause := not get_tree().paused
	get_tree().paused = should_pause
	visible = should_pause
	if should_pause and _resume_button != null:
		_resume_button.grab_focus()

func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.015, 0.025, 0.035, 0.78)
	tint.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(tint)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400.0, 500.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("101b25f5"), Color("6b9a9d"), 3))
	center.add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 32)
	margins.add_theme_constant_override("margin_right", 32)
	margins.add_theme_constant_override("margin_top", 26)
	margins.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margins)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margins.add_child(content)

	var title := Label.new()
	title.text = "MISSION PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f4d58b"))
	title.add_theme_font_size_override("font_size", 28)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "The field is waiting for your orders."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("9cb5b5"))
	content.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8.0
	content.add_child(spacer)

	_resume_button = Button.new()
	_resume_button.text = "RESUME"
	_resume_button.custom_minimum_size.y = 42.0
	_resume_button.focus_mode = Control.FOCUS_ALL
	_resume_button.add_theme_font_size_override("font_size", 16)
	_resume_button.pressed.connect(_on_resume_pressed)
	content.add_child(_resume_button)

	_settings_button = Button.new()
	_settings_button.text = "SETTINGS"
	_settings_button.custom_minimum_size.y = 42.0
	_settings_button.add_theme_font_size_override("font_size", 16)
	_settings_button.pressed.connect(_on_settings_pressed)
	content.add_child(_settings_button)

	_settings_section = VBoxContainer.new()
	_settings_section.add_theme_constant_override("separation", 8)
	_settings_section.visible = false
	content.add_child(_settings_section)

	var settings_title := Label.new()
	settings_title.text = "CAMERA PAN SPEED"
	settings_title.add_theme_color_override("font_color", Color("f4d58b"))
	_settings_section.add_child(settings_title)

	_camera_speed_slider = HSlider.new()
	_camera_speed_slider.min_value = 240.0
	_camera_speed_slider.max_value = 1400.0
	_camera_speed_slider.step = 20.0
	_camera_speed_slider.custom_minimum_size.y = 28.0
	var camera := _get_camera()
	_camera_speed_slider.value = float(camera.get("pan_speed")) if camera != null else 760.0
	_camera_speed_slider.value_changed.connect(_on_camera_speed_changed)
	_settings_section.add_child(_camera_speed_slider)

	_camera_speed_value = Label.new()
	_camera_speed_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camera_speed_value.add_theme_color_override("font_color", Color("dce5df"))
	_settings_section.add_child(_camera_speed_value)
	_update_camera_speed_label(_camera_speed_slider.value)

	var diagnostics_title := Label.new()
	diagnostics_title.text = "RENDER DIAGNOSTICS"
	diagnostics_title.add_theme_color_override("font_color", Color("f4d58b"))
	_settings_section.add_child(diagnostics_title)

	_tile_details_check = CheckButton.new()
	_tile_details_check.text = "Tile details"
	_tile_details_check.button_pressed = _current_tile_details_enabled()
	_tile_details_check.toggled.connect(_on_tile_details_toggled)
	_settings_section.add_child(_tile_details_check)

	_nameplates_check = CheckButton.new()
	_nameplates_check.text = "Unit nameplates"
	_nameplates_check.button_pressed = CharacterEntity.show_nameplates
	_nameplates_check.toggled.connect(_on_nameplates_toggled)
	_settings_section.add_child(_nameplates_check)

	_team_markers_check = CheckButton.new()
	_team_markers_check.text = "Team markers"
	_team_markers_check.button_pressed = CharacterEntity.show_team_markers
	_team_markers_check.toggled.connect(_on_team_markers_toggled)
	_settings_section.add_child(_team_markers_check)

	var back_button := Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size.y = 42.0
	back_button.pressed.connect(_on_settings_back_pressed)
	_settings_section.add_child(back_button)

	_hint = Label.new()
	_hint.text = "Press ESC to resume"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color("dce5df"))
	content.add_child(_hint)

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_settings_pressed() -> void:
	_resume_button.visible = false
	_settings_button.visible = false
	_hint.visible = false
	_settings_section.visible = true
	_camera_speed_slider.grab_focus()

func _on_settings_back_pressed() -> void:
	_settings_section.visible = false
	_resume_button.visible = true
	_settings_button.visible = true
	_hint.visible = true
	_settings_button.grab_focus()

func _on_camera_speed_changed(value: float) -> void:
	var camera := _get_camera()
	if camera != null:
		camera.set("pan_speed", value)
	_update_camera_speed_label(value)

func _update_camera_speed_label(value: float) -> void:
	if _camera_speed_value != null:
		_camera_speed_value.text = "%d px/s" % roundi(value)

func _current_tile_details_enabled() -> bool:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	if maps.is_empty():
		return true
	var terrain_map := maps[0] as TerrainMap
	return terrain_map.draw_tile_details if terrain_map != null else true

func _on_tile_details_toggled(enabled: bool) -> void:
	for terrain in get_tree().get_nodes_in_group("terrain_maps"):
		var terrain_map := terrain as TerrainMap
		if terrain_map != null:
			terrain_map.draw_tile_details = enabled
			terrain_map.queue_redraw()

func _on_nameplates_toggled(enabled: bool) -> void:
	CharacterEntity.show_nameplates = enabled
	_queue_entity_redraws()

func _on_team_markers_toggled(enabled: bool) -> void:
	CharacterEntity.show_team_markers = enabled
	_queue_entity_redraws()

func _queue_entity_redraws() -> void:
	for candidate in get_tree().get_nodes_in_group("entities"):
		if candidate is Entity:
			(candidate as Entity).queue_redraw()

func _get_camera() -> Node:
	var cameras := get_tree().get_nodes_in_group("rts_cameras")
	if cameras.is_empty():
		return null
	return cameras[0] as RTSCamera

func _panel_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style
