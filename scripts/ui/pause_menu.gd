extends CanvasLayer

## Pause overlay. This layer must keep processing while the rest of the scene
## tree is paused so Escape and the Resume button remain available.

var _overlay: Control
var _resume_button: Button

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
	panel.custom_minimum_size = Vector2(360.0, 230.0)
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

	var hint := Label.new()
	hint.text = "Press ESC to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("dce5df"))
	content.add_child(hint)

func _on_resume_pressed() -> void:
	toggle_pause()

func _panel_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style
