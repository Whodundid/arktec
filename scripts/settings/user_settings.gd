extends Node

## Persistent player preferences shared by the game and future customization UI.

const SETTINGS_FILE_NAME := "user_settings.json"
const DEFAULT_KEYBINDS := {
	"train_guard": KEY_Q,
	"train_pursuer": KEY_W,
	"train_flanker": KEY_E,
	"train_builder": KEY_Q,
	"build_supply": KEY_A,
	"build_barracks": KEY_S,
	"build_main": KEY_D,
}

var keybinds: Dictionary = DEFAULT_KEYBINDS.duplicate()
var _settings_path := ""

func _ready() -> void:
	_settings_path = RuntimeLogger.get_app_directory().path_join(SETTINGS_FILE_NAME)
	_load()

func get_keybind(action: String) -> int:
	return int(keybinds.get(action, DEFAULT_KEYBINDS.get(action, KEY_NONE)))

func set_keybind(action: String, keycode: int) -> bool:
	if not DEFAULT_KEYBINDS.has(action) or keycode == KEY_NONE:
		return false
	for other_action in keybinds:
		if other_action != action and _actions_conflict(action, other_action) and int(keybinds[other_action]) == keycode:
			return false
	keybinds[action] = keycode
	_save()
	return true

func reset_keybinds() -> void:
	keybinds = DEFAULT_KEYBINDS.duplicate()
	_save()

func get_key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode) if keycode != KEY_NONE else "UNBOUND"

func get_settings_path() -> String:
	return _settings_path

func _actions_conflict(first: String, second: String) -> bool:
	var first_is_build := first.begins_with("build_")
	var second_is_build := second.begins_with("build_")
	if first_is_build or second_is_build:
		return first_is_build == second_is_build
	return first != "train_builder" and second != "train_builder"

func _load() -> void:
	if not FileAccess.file_exists(_settings_path):
		_save()
		return
	var file := FileAccess.open(_settings_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var saved_binds = parsed.get("keybinds", {})
	if not saved_binds is Dictionary:
		return
	for action in DEFAULT_KEYBINDS:
		var value = saved_binds.get(action, DEFAULT_KEYBINDS[action])
		if value is int and int(value) != KEY_NONE:
			keybinds[action] = int(value)

func _save() -> void:
	DirAccess.make_dir_recursive_absolute(RuntimeLogger.get_app_directory())
	var file := FileAccess.open(_settings_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"version": 1, "keybinds": keybinds}, "\t") + "\n")
		file.close()
