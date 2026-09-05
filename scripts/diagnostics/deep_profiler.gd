extends Node

## Opt-in, low-noise profiling for gameplay systems that are too specific for
## Godot's aggregate performance monitors. Disabled profiling performs no
## timing, allocation, aggregation, or file I/O beyond caller-side enabled
## checks.

const PROFILE_FILE_PREFIX := "profile_"
const MAX_PROFILE_FILE_BYTES := 10 * 1024 * 1024
const SAMPLE_INTERVAL_SECONDS := 1.0
const SLOW_CALL_THRESHOLD_USEC := 1000
const MAX_SLOW_CALLS_PER_SAMPLE := 12
const SCHEMA_VERSION := 1

var _enabled := false
var _profile_file: FileAccess
var _profile_path := ""
var _profile_part := 0
var _current_profile_bytes := 0
var _started_usec := 0
var _sample_elapsed := 0.0
var _timings: Dictionary = {}
var _counters: Dictionary = {}
var _slow_calls: Array[Dictionary] = []
var _physics_steps_since_render := 0
var _sample_physics_steps := 0
var _sample_render_frames := 0
var _max_physics_steps_per_render := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_enabled(RuntimeLogger.is_deep_profiling_enabled())

func _physics_process(_delta: float) -> void:
	if not _enabled or get_tree().paused:
		return
	_physics_steps_since_render += 1
	_sample_physics_steps += 1

func _process(delta: float) -> void:
	if not _enabled or get_tree().paused:
		return
	_sample_render_frames += 1
	_max_physics_steps_per_render = maxi(_max_physics_steps_per_render, _physics_steps_since_render)
	_physics_steps_since_render = 0
	_sample_elapsed += delta
	if _sample_elapsed >= SAMPLE_INTERVAL_SECONDS:
		_write_sample()

func _exit_tree() -> void:
	_close_profile("shutdown")

func is_enabled() -> bool:
	return _enabled

func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	if _enabled:
		_open_profile()
	else:
		_close_profile("disabled")

func record_timing(metric: StringName, elapsed_usec: int, actor: Node2D = null, capture_slow_call: bool = true) -> void:
	if not _enabled:
		return
	var key := str(metric)
	var timing: Dictionary = _timings.get(key, {
		"calls": 0,
		"total_usec": 0,
		"max_usec": 0,
	})
	timing["calls"] = int(timing["calls"]) + 1
	timing["total_usec"] = int(timing["total_usec"]) + elapsed_usec
	timing["max_usec"] = maxi(int(timing["max_usec"]), elapsed_usec)
	_timings[key] = timing
	if capture_slow_call and elapsed_usec >= SLOW_CALL_THRESHOLD_USEC:
		_record_slow_call(key, elapsed_usec, actor)

func increment(metric: StringName, amount: int = 1) -> void:
	if not _enabled:
		return
	var key := str(metric)
	_counters[key] = int(_counters.get(key, 0)) + amount

func get_profile_path() -> String:
	return _profile_path

func _record_slow_call(metric: String, elapsed_usec: int, actor: Node2D) -> void:
	var elapsed_ms := snappedf(float(elapsed_usec) / 1000.0, 0.001)
	if _slow_calls.size() >= MAX_SLOW_CALLS_PER_SAMPLE and elapsed_ms <= float(_slow_calls[-1]["elapsed_ms"]):
		return
	var actor_identity := ""
	var world_position: Variant = null
	if is_instance_valid(actor):
		world_position = [snappedf(actor.global_position.x, 0.1), snappedf(actor.global_position.y, 0.1)]
		if actor.has_method("get_diagnostics_identity"):
			actor_identity = str(actor.call("get_diagnostics_identity"))
		else:
			actor_identity = actor.name
	_slow_calls.append({
		"metric": metric,
		"elapsed_ms": elapsed_ms,
		"actor": actor_identity,
		"world": world_position,
		"physics_frame": Engine.get_physics_frames(),
	})
	_slow_calls.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first["elapsed_ms"]) > float(second["elapsed_ms"])
	)
	if _slow_calls.size() > MAX_SLOW_CALLS_PER_SAMPLE:
		_slow_calls.resize(MAX_SLOW_CALLS_PER_SAMPLE)

func _write_sample() -> void:
	var sample_duration := maxf(_sample_elapsed, 0.0001)
	var formatted_timings: Dictionary = {}
	for key in _timings:
		var timing: Dictionary = _timings[key]
		var calls := int(timing["calls"])
		formatted_timings[key] = {
			"calls": calls,
			"total_ms": snappedf(float(timing["total_usec"]) / 1000.0, 0.001),
			"average_ms": snappedf(float(timing["total_usec"]) / float(maxi(calls, 1)) / 1000.0, 0.001),
			"max_ms": snappedf(float(timing["max_usec"]) / 1000.0, 0.001),
		}
	var entity_count := get_tree().get_nodes_in_group("entities").size()
	_write_record({
		"schema": SCHEMA_VERSION,
		"type": "profile_sample",
		"system_time": Time.get_datetime_string_from_system(false),
		"elapsed_ms": Time.get_ticks_msec() - int(_started_usec / 1000),
		"sample_seconds": snappedf(sample_duration, 0.001),
		"fps": RuntimeLogger.get_fps(),
		"ups": RuntimeLogger.get_ups(),
		"frame_process_ms": snappedf(RuntimeLogger.get_frame_time_ms(), 0.01),
		"physics_process_ms": snappedf(RuntimeLogger.get_physics_time_ms(), 0.01),
		"render_frames": _sample_render_frames,
		"physics_steps": _sample_physics_steps,
		"physics_steps_per_render": snappedf(float(_sample_physics_steps) / float(maxi(_sample_render_frames, 1)), 0.01),
		"max_physics_steps_per_render": _max_physics_steps_per_render,
		"entities": entity_count,
		"timings": formatted_timings,
		"counters": _counters.duplicate(true),
		"slow_calls": _slow_calls.duplicate(true),
	})
	_reset_sample()

func _reset_sample() -> void:
	_sample_elapsed = 0.0
	_timings.clear()
	_counters.clear()
	_slow_calls.clear()
	_sample_physics_steps = 0
	_sample_render_frames = 0
	_max_physics_steps_per_render = 0

func _open_profile() -> void:
	_started_usec = Time.get_ticks_usec()
	_profile_part = 0
	_reset_sample()
	_physics_steps_since_render = 0
	_profile_path = RuntimeLogger.get_run_directory().path_join("%s%03d.jsonl" % [PROFILE_FILE_PREFIX, _profile_part])
	_profile_file = FileAccess.open(_profile_path, FileAccess.WRITE)
	_current_profile_bytes = 0
	if _profile_file == null:
		_enabled = false
		RuntimeLogger.error("Deep profiler could not open output: %s" % _profile_path)
		return
	_write_record({
		"schema": SCHEMA_VERSION,
		"type": "profile_started",
		"system_time": Time.get_datetime_string_from_system(false),
		"slow_call_threshold_ms": float(SLOW_CALL_THRESHOLD_USEC) / 1000.0,
		"sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
	})
	RuntimeLogger.info("Deep profiler enabled: %s" % _profile_path)

func _close_profile(reason: String) -> void:
	if _profile_file == null:
		return
	if not _timings.is_empty() or not _counters.is_empty():
		_write_sample()
	_write_record({
		"schema": SCHEMA_VERSION,
		"type": "profile_stopped",
		"system_time": Time.get_datetime_string_from_system(false),
		"reason": reason,
	})
	_profile_file.flush()
	_profile_file.close()
	_profile_file = null
	RuntimeLogger.info("Deep profiler stopped")

func _write_record(record: Dictionary) -> void:
	if _profile_file == null:
		return
	var line := JSON.stringify(record)
	var line_bytes := line.to_utf8_buffer().size() + 1
	if _current_profile_bytes > 0 and _current_profile_bytes + line_bytes > MAX_PROFILE_FILE_BYTES:
		_roll_profile_file()
	_profile_file.store_line(line)
	_profile_file.flush()
	_current_profile_bytes += line_bytes

func _roll_profile_file() -> void:
	_profile_file.flush()
	_profile_file.close()
	_profile_part += 1
	_profile_path = RuntimeLogger.get_run_directory().path_join("%s%03d.jsonl" % [PROFILE_FILE_PREFIX, _profile_part])
	_profile_file = FileAccess.open(_profile_path, FileAccess.WRITE)
	_current_profile_bytes = 0
