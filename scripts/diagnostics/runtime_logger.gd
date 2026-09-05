extends Node

## Persistent runtime diagnostics for ArtifactRun.
##
## The configuration and log intentionally live outside the project so exported
## builds and editor runs use the same diagnostics location.

enum LogLevel { TRACE, DEBUG, INFO, WARN, ERROR, OFF }

const APP_DIRECTORY_NAME := "artifact_run"
const CONFIG_FILE_NAME := "config.json"
const ENVIRONMENT_FILE_NAME := "environment.json"
const RUN_DIRECTORY_PREFIX := "run_"
const LOG_FILE_PREFIX := "log_"
const INPUT_FILE_PREFIX := "input_"
const MAX_LOG_FILE_BYTES := 10 * 1024 * 1024
const MAX_RUN_DIRECTORIES := 3
const DEFAULT_LOG_LEVEL := LogLevel.DEBUG
const LEVEL_NAMES := ["TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"]

var _log_level: int = DEFAULT_LOG_LEVEL
var _log_file: FileAccess
var _run_directory: String = ""
var _run_log_path: String = ""
var _log_part := 0
var _current_log_bytes := 0
var _input_file: FileAccess
var _input_log_path: String = ""
var _input_part := 0
var _current_input_bytes := 0
var _input_flush_elapsed := 0.0
var _record_inputs := true
var _deep_profiling := false
var _performance_sample_elapsed := 0.0
var _fps := 0
var _ups := 0
var _frame_time_ms := 0.0
var _physics_time_ms := 0.0
var _ups_sample_elapsed := 0.0
var _ups_last_physics_frame := 0

func _ready() -> void:
	_load_config()
	_ensure_app_directory()
	_run_directory = _get_new_run_directory()
	DirAccess.make_dir_recursive_absolute(_run_directory)
	_cleanup_old_runs()
	_run_log_path = _run_directory.path_join("%s%03d.log" % [LOG_FILE_PREFIX, _log_part])
	_input_log_path = _run_directory.path_join("%s%03d.jsonl" % [INPUT_FILE_PREFIX, _input_part])
	_open_log()
	_write_log_header()
	_write_environment_snapshot()
	set_process(true)
	set_physics_process(true)
	info("Diagnostics logger initialized; config=%s log=%s" % [get_config_path(), get_log_path()])

func _process(delta: float) -> void:
	_fps = Engine.get_frames_per_second()
	_frame_time_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_physics_time_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_ups_sample_elapsed += delta
	_performance_sample_elapsed += delta
	_input_flush_elapsed += delta
	if _input_flush_elapsed >= 0.25:
		_input_flush_elapsed = 0.0
		if _input_file != null:
			_input_file.flush()
	if _ups_sample_elapsed >= 0.5:
		var current_physics_frame := Engine.get_physics_frames()
		_ups = roundi(float(current_physics_frame - _ups_last_physics_frame) / _ups_sample_elapsed)
		_ups_last_physics_frame = current_physics_frame
		_ups_sample_elapsed = 0.0
	if _performance_sample_elapsed >= 1.0:
		_performance_sample_elapsed = 0.0
		var entity_count := get_tree().get_nodes_in_group("entities").size()
		_write(LogLevel.DEBUG, "PERF SAMPLE: entities=%d root_children=%d" % [entity_count, get_tree().root.get_child_count()])

func _exit_tree() -> void:
	if _log_file != null:
		_write(LogLevel.INFO, "Diagnostics logger shutting down")
		_log_file.close()
		_log_file = null
	if _input_file != null:
		_input_file.flush()
		_input_file.close()
		_input_file = null

func trace(message: String) -> void:
	_write(LogLevel.TRACE, message)

func debug(message: String) -> void:
	_write(LogLevel.DEBUG, message)

func info(message: String) -> void:
	_write(LogLevel.INFO, message)

func warn(message: String) -> void:
	_write(LogLevel.WARN, message)

func error(message: String) -> void:
	_write(LogLevel.ERROR, message)

func get_log_level() -> String:
	return LEVEL_NAMES[_log_level]

func get_fps() -> int:
	return _fps

func get_ups() -> int:
	return _ups

func get_frame_time_ms() -> float:
	return _frame_time_ms

func get_physics_time_ms() -> float:
	return _physics_time_ms

func is_input_recording_enabled() -> bool:
	return _record_inputs

func is_deep_profiling_enabled() -> bool:
	return _deep_profiling

func set_deep_profiling_enabled(enabled: bool) -> void:
	if _deep_profiling == enabled:
		return
	_deep_profiling = enabled
	_save_config()
	var profiler := get_node_or_null("/root/DeepProfiler")
	if profiler != null:
		profiler.call("set_enabled", enabled)

func record_input_event(event_data: Dictionary) -> void:
	if not _record_inputs or _input_file == null:
		return
	var line_data := event_data.duplicate(true)
	line_data["system_time"] = Time.get_datetime_string_from_system(false)
	var line := JSON.stringify(line_data)
	var line_bytes: int = line.to_utf8_buffer().size() + 1
	if _current_input_bytes > 0 and _current_input_bytes + line_bytes > MAX_LOG_FILE_BYTES:
		_roll_input_file()
	_input_file.store_line(line)
	_current_input_bytes += line_bytes

func set_log_level(level_name: String) -> bool:
	var normalized := level_name.strip_edges().to_upper()
	var level := LEVEL_NAMES.find(normalized)
	if level < 0:
		warn("Ignoring unknown log level: %s" % level_name)
		return false
	_log_level = level
	_save_config()
	info("Log level changed to %s" % normalized)
	return true

func get_config_path() -> String:
	return _get_app_directory().path_join(CONFIG_FILE_NAME)

func get_log_path() -> String:
	return _run_log_path if not _run_log_path.is_empty() else _get_app_directory().path_join("run_pending").path_join("%s000.log" % LOG_FILE_PREFIX)

func get_log_directory() -> String:
	return _get_app_directory()

func get_environment_path() -> String:
	return _run_directory.path_join(ENVIRONMENT_FILE_NAME)

func get_run_directory() -> String:
	return _run_directory

func _write(level: int, message: String) -> void:
	if level < _log_level or _log_level == LogLevel.OFF or _log_file == null:
		return
	var line := _format_line(level, message)
	var line_bytes: int = line.to_utf8_buffer().size() + 1
	if _current_log_bytes > 0 and _current_log_bytes + line_bytes > MAX_LOG_FILE_BYTES:
		_roll_log_file()
	_log_file.store_line(line)
	_log_file.flush()
	_current_log_bytes += line_bytes

func _format_line(level: int, message: String) -> String:
	var level_text: String = LEVEL_NAMES[level].rpad(5)
	return "[%s], [%s], [fps=%03d ups=%03d fms=%06.2f pms=%06.2f]: %s" % [
		level_text, Time.get_datetime_string_from_system(false), _fps, _ups, _frame_time_ms, _physics_time_ms, message,
	]

func _load_config() -> void:
	var path := get_config_path()
	if not FileAccess.file_exists(path):
		_save_config()
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.get("log_level") is String:
		var configured_level := LEVEL_NAMES.find(str(parsed["log_level"]).to_upper())
		if configured_level >= 0:
			_log_level = configured_level
	if parsed is Dictionary and parsed.get("record_inputs") is bool:
		_record_inputs = parsed["record_inputs"]
	if parsed is Dictionary and parsed.get("deep_profiling") is bool:
		_deep_profiling = parsed["deep_profiling"]

func _save_config() -> void:
	_ensure_app_directory()
	var file := FileAccess.open(get_config_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"deep_profiling": _deep_profiling,
		"log_level": get_log_level(),
		"record_inputs": _record_inputs,
	}, "\t") + "\n")
	file.close()

func _open_log() -> void:
	_log_file = FileAccess.open(get_log_path(), FileAccess.WRITE)
	_current_log_bytes = 0
	if _record_inputs:
		_input_file = FileAccess.open(_input_log_path, FileAccess.WRITE)
		_current_input_bytes = 0

func _write_log_header() -> void:
	if _log_file == null:
		return
	_log_file.store_line("# Diagnostics: fps=rendered frames per second; ups=physics updates per second; fms=frame/process time in milliseconds; pms=physics process time in milliseconds.")
	_log_file.store_line("# fms and pms are Godot Performance monitor timings sampled during each rendered frame; lower is better.")
	_log_file.flush()

func _write_environment_snapshot() -> void:
	var godot_version: Dictionary = Engine.get_version_info()
	var screen_count: int = DisplayServer.get_screen_count()
	var screens: Array[Dictionary] = []
	for screen_index in range(screen_count):
		var screen_size: Vector2i = DisplayServer.screen_get_size(screen_index)
		screens.append({
			"index": screen_index,
			"size": {"width": screen_size.x, "height": screen_size.y},
		})
	var environment := {
		"captured_at": Time.get_datetime_string_from_system(false),
		"godot": godot_version,
		"os": {
			"name": OS.get_name(),
			"version": OS.get_version(),
		},
		"hardware": {
			"cpu": OS.get_processor_name(),
			"cpu_threads": OS.get_processor_count(),
			"gpu": RenderingServer.get_video_adapter_name(),
			"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
			"monitor_count": screen_count,
			"monitors": screens,
		},
		"runtime": {
			"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"),
			"renderer_mobile": ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "unknown"),
			"viewport_width": ProjectSettings.get_setting("display/window/size/viewport_width", 0),
			"viewport_height": ProjectSettings.get_setting("display/window/size/viewport_height", 0),
			"window_width": ProjectSettings.get_setting("display/window/size/window_width_override", 0),
			"window_height": ProjectSettings.get_setting("display/window/size/window_height_override", 0),
		},
	}
	var file := FileAccess.open(get_environment_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(environment, "\t") + "\n")
		file.close()
	info("Environment: OS=%s %s CPU=%s (%d threads) GPU=%s monitors=%d Godot=%s renderer=%s" % [
		OS.get_name(), OS.get_version(), OS.get_processor_name(), OS.get_processor_count(),
		RenderingServer.get_video_adapter_name(), screen_count,
		"%s.%s.%s" % [godot_version.get("major", 0), godot_version.get("minor", 0), godot_version.get("patch", 0)],
		str(environment["runtime"]["renderer"]),
	])

func _roll_log_file() -> void:
	_log_file.flush()
	_log_file.close()
	_log_part += 1
	_run_log_path = _run_directory.path_join("%s%03d.log" % [LOG_FILE_PREFIX, _log_part])
	_log_file = FileAccess.open(_run_log_path, FileAccess.WRITE)
	_current_log_bytes = 0

func _roll_input_file() -> void:
	_input_file.flush()
	_input_file.close()
	_input_part += 1
	_input_log_path = _run_directory.path_join("%s%03d.jsonl" % [INPUT_FILE_PREFIX, _input_part])
	_input_file = FileAccess.open(_input_log_path, FileAccess.WRITE)
	_current_input_bytes = 0

func _get_new_run_directory() -> String:
	var timestamp: String = Time.get_datetime_string_from_system(false).replace(":", "-").replace("T", "_")
	var milliseconds := posmod(Time.get_ticks_msec(), 1000)
	return _get_app_directory().path_join("%s%s_%03d" % [RUN_DIRECTORY_PREFIX, timestamp, milliseconds])

func _cleanup_old_runs() -> void:
	var run_directories: Array[String] = []
	var directory := DirAccess.open(_get_app_directory())
	if directory == null:
		return
	for directory_name in directory.get_directories():
		if directory_name.begins_with(RUN_DIRECTORY_PREFIX):
			run_directories.append(directory_name)
	directory.list_dir_end()
	directory = null
	run_directories.sort()
	while run_directories.size() > MAX_RUN_DIRECTORIES:
		_remove_directory_recursively(_get_app_directory().path_join(run_directories[0]))
		run_directories.remove_at(0)

func _remove_directory_recursively(path: String) -> void:
	var trash_error: Error = OS.move_to_trash(path)
	if trash_error == OK:
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	var file_names: PackedStringArray = directory.get_files()
	var directory_names: PackedStringArray = directory.get_directories()
	directory.list_dir_end()
	directory = null
	for file_name in file_names:
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in directory_names:
		_remove_directory_recursively(path.path_join(directory_name))
		DirAccess.remove_absolute(path.path_join(directory_name))
	DirAccess.remove_absolute(path)

func _ensure_app_directory() -> void:
	DirAccess.make_dir_recursive_absolute(_get_app_directory())

func _get_app_directory() -> String:
	if OS.get_name() == "Windows":
		var appdata := OS.get_environment("APPDATA")
		if not appdata.is_empty():
			return appdata.path_join(APP_DIRECTORY_NAME)
	var xdg_data_home := OS.get_environment("XDG_DATA_HOME")
	if not xdg_data_home.is_empty():
		return xdg_data_home.path_join(APP_DIRECTORY_NAME)
	var home := OS.get_environment("HOME")
	return home.path_join(".local").path_join("share").path_join(APP_DIRECTORY_NAME)

func get_app_directory() -> String:
	return _get_app_directory()
