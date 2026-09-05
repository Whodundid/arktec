extends Node

## Records only ArtifactRun controls and viewport mouse input for reproduction.
## Raw unrelated keyboard input and text/unicode input are deliberately ignored.

const EXPLICIT_GAME_KEYS := [KEY_ESCAPE, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7]
var _started_at_msec := 0

func _ready() -> void:
	_started_at_msec = Time.get_ticks_msec()
	set_process_input(true)
	if RuntimeLogger.is_input_recording_enabled():
		RuntimeLogger.record_input_event({"type": "recorder_started", "schema": 1})

func _input(event: InputEvent) -> void:
	if not RuntimeLogger.is_input_recording_enabled():
		return
	if event is InputEventKey:
		_record_key(event as InputEventKey)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		RuntimeLogger.record_input_event({
			"type": "mouse_motion",
			"elapsed_ms": Time.get_ticks_msec() - _started_at_msec,
			"position": _vector_to_array(motion.position),
			"relative": _vector_to_array(motion.relative),
		})
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		RuntimeLogger.record_input_event({
			"type": "mouse_button",
			"elapsed_ms": Time.get_ticks_msec() - _started_at_msec,
			"button": button.button_index,
			"pressed": button.pressed,
			"position": _vector_to_array(button.position),
			"factor": button.factor,
		})

func _record_key(event: InputEventKey) -> void:
	if event.echo:
		return
	var actions: Array[String] = []
	for action in InputMap.get_actions():
		var action_name := str(action)
		if action_name.begins_with("ui_"):
			continue
		if InputMap.event_is_action(event, action_name):
			actions.append(action_name)
	if actions.is_empty() and not EXPLICIT_GAME_KEYS.has(event.keycode) and not EXPLICIT_GAME_KEYS.has(event.physical_keycode):
		return
	RuntimeLogger.record_input_event({
		"type": "game_key",
		"elapsed_ms": Time.get_ticks_msec() - _started_at_msec,
		"actions": actions,
		"pressed": event.pressed,
		"physical_keycode": event.physical_keycode,
		"keycode": event.keycode,
		"location": event.location,
	})

func _vector_to_array(value: Vector2) -> Array[float]:
	return [value.x, value.y]
