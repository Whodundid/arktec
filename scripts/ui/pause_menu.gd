extends CanvasLayer

## Pause overlay. This layer must keep processing while the rest of the scene
## tree is paused so Escape and the Resume button remain available.

var _overlay: Control
var _resume_button: Button
var _settings_button: Button
var _logs_button: Button
var _hint: Label
var _settings_scroll: ScrollContainer
var _settings_section: VBoxContainer
var _camera_speed_slider: HSlider
var _camera_speed_value: Label
var _grid_check: CheckButton
var _tile_details_check: CheckButton
var _nameplates_check: CheckButton
var _deep_profiler_check: CheckButton
var _rebinding_action := ""
var _keybind_buttons: Dictionary = {}
const KEYBIND_ACTIONS := [
	["Train Guard", "train_guard"], ["Train Pursuer", "train_pursuer"], ["Train Flanker", "train_flanker"],
	["Train Builder", "train_builder"], ["Build Supply", "build_supply"], ["Build Barracks", "build_barracks"], ["Build Command", "build_main"],
]

func _ready() -> void:
	# The menu must receive Escape both before and after pausing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _rebinding_action.is_empty() == false and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_rebinding_action = ""
			_update_keybind_buttons()
		else:
			var keycode: int = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
			if _user_settings().set_keybind(_rebinding_action, keycode):
				_rebinding_action = ""
				_update_keybind_buttons()
			else:
				_hint.text = "That key is already assigned"
		get_viewport().set_input_as_handled()
		return
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
	panel.custom_minimum_size = Vector2(430.0, 390.0)
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

	_logs_button = Button.new()
	_logs_button.text = "OPEN LOG FOLDER"
	_logs_button.custom_minimum_size.y = 42.0
	_logs_button.add_theme_font_size_override("font_size", 16)
	_logs_button.pressed.connect(_on_logs_pressed)
	content.add_child(_logs_button)

	_settings_section = VBoxContainer.new()
	_settings_section.add_theme_constant_override("separation", 8)
	_settings_section.visible = false
	_settings_scroll = ScrollContainer.new()
	_settings_scroll.custom_minimum_size.y = 430.0
	_settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_scroll.visible = false
	content.add_child(_settings_scroll)
	_settings_scroll.add_child(_settings_section)

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

	_grid_check = CheckButton.new()
	_grid_check.text = "Terrain grid"
	_grid_check.button_pressed = _current_grid_enabled()
	_grid_check.toggled.connect(_on_grid_toggled)
	_settings_section.add_child(_grid_check)

	_nameplates_check = CheckButton.new()
	_nameplates_check.text = "Unit nameplates"
	_nameplates_check.button_pressed = CharacterEntity.show_nameplates
	_nameplates_check.toggled.connect(_on_nameplates_toggled)
	_settings_section.add_child(_nameplates_check)

	var profiling_title := Label.new()
	profiling_title.text = "PERFORMANCE CAPTURE"
	profiling_title.add_theme_color_override("font_color", Color("f4d58b"))
	_settings_section.add_child(profiling_title)

	_deep_profiler_check = CheckButton.new()
	_deep_profiler_check.text = "Deep movement profiler"
	_deep_profiler_check.tooltip_text = "Writes detailed movement timings to profile_*.jsonl. Leave off during normal play."
	_deep_profiler_check.button_pressed = RuntimeLogger.is_deep_profiling_enabled()
	_deep_profiler_check.toggled.connect(_on_deep_profiler_toggled)
	_settings_section.add_child(_deep_profiler_check)

	var keybinds_title := Label.new()
	keybinds_title.text = "COMMAND HOTKEYS"
	keybinds_title.add_theme_color_override("font_color", Color("f4d58b"))
	_settings_section.add_child(keybinds_title)
	for entry in KEYBIND_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = entry[0]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(126.0, 32.0)
		bind_button.focus_mode = Control.FOCUS_ALL
		bind_button.pressed.connect(_begin_rebind.bind(entry[1]))
		_keybind_buttons[entry[1]] = bind_button
		row.add_child(bind_button)
		_settings_section.add_child(row)
	_update_keybind_buttons()

	var reset_keybinds_button := Button.new()
	reset_keybinds_button.text = "RESET HOTKEYS"
	reset_keybinds_button.pressed.connect(_on_reset_keybinds_pressed)
	_settings_section.add_child(reset_keybinds_button)

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
	_logs_button.visible = false
	_hint.visible = false
	_settings_scroll.visible = true
	_settings_section.visible = true
	_camera_speed_slider.grab_focus()
	_update_keybind_buttons()

func _on_settings_back_pressed() -> void:
	_rebinding_action = ""
	_settings_scroll.visible = false
	_settings_section.visible = false
	_resume_button.visible = true
	_settings_button.visible = true
	_logs_button.visible = true
	_hint.visible = true
	_settings_button.grab_focus()

func _on_logs_pressed() -> void:
	var log_directory := RuntimeLogger.get_log_directory()
	var error := OS.shell_show_in_file_manager(log_directory, true)
	if error != OK:
		RuntimeLogger.warn("Could not open log directory: path=%s error=%s" % [log_directory, error])
		_hint.text = "Could not open log folder"
		return
	RuntimeLogger.info("Opened log directory: %s" % log_directory)
	_hint.text = "Log folder opened"

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

func _current_grid_enabled() -> bool:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	if maps.is_empty():
		return false
	var terrain_map := maps[0] as TerrainMap
	return terrain_map.draw_grid if terrain_map != null else false

func _on_grid_toggled(enabled: bool) -> void:
	for terrain in get_tree().get_nodes_in_group("terrain_maps"):
		var terrain_map := terrain as TerrainMap
		if terrain_map != null:
			terrain_map.draw_grid = enabled
			terrain_map.queue_redraw()

func _on_tile_details_toggled(enabled: bool) -> void:
	for terrain in get_tree().get_nodes_in_group("terrain_maps"):
		var terrain_map := terrain as TerrainMap
		if terrain_map != null:
			terrain_map.draw_tile_details = enabled
			terrain_map.queue_redraw()

func _on_nameplates_toggled(enabled: bool) -> void:
	CharacterEntity.show_nameplates = enabled
	_queue_entity_redraws()

func _on_deep_profiler_toggled(enabled: bool) -> void:
	RuntimeLogger.set_deep_profiling_enabled(enabled)

func _begin_rebind(action: String) -> void:
	_rebinding_action = action
	_hint.text = "Press a key for %s (ESC cancels)" % action.replace("_", " ").to_upper()
	_update_keybind_buttons()

func _update_keybind_buttons() -> void:
	for action in _keybind_buttons:
		var button := _keybind_buttons[action] as Button
		if button != null:
			button.text = "PRESS KEY..." if action == _rebinding_action else _user_settings().get_key_name(_user_settings().get_keybind(action))

func _on_reset_keybinds_pressed() -> void:
	_user_settings().reset_keybinds()
	_rebinding_action = ""
	_hint.text = "Hotkeys reset to defaults"
	_update_keybind_buttons()

func _queue_entity_redraws() -> void:
	for candidate in get_tree().get_nodes_in_group("entities"):
		if candidate is Entity:
			(candidate as Entity).queue_redraw()

func _user_settings() -> Node:
	return get_node("/root/UserSettings")

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
