class_name DayNightCycle
extends Node2D

## Lightweight world lighting clock. The full cycle is ten minutes by default:
## six minutes of daylight followed by four minutes of night.

signal lighting_changed(daylight: float, sun_direction: Vector2)

@export_range(60.0, 1800.0, 10.0) var full_day_length_seconds := 600.0
@export_range(0.1, 0.9, 0.05) var daylight_ratio := 0.6
@export_range(0.0, 1.0, 0.01) var starting_time := 0.18
@export var night_color := Color(0.34, 0.40, 0.56, 1.0)
@export var run_in_pause := false

const DAY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const SUNRISE_COLOR := Color(0.98, 0.78, 0.62, 1.0)

var _elapsed_seconds := 0.0
var _last_daylight := -1.0
var _canvas_modulate: CanvasModulate

func _ready() -> void:
	add_to_group("day_night_cycles")
	_elapsed_seconds = fposmod(starting_time, 1.0) * full_day_length_seconds
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "WorldLightModulate"
	add_child(_canvas_modulate)
	_apply_lighting()

func _process(delta: float) -> void:
	if get_tree().paused and not run_in_pause:
		return
	_elapsed_seconds = fposmod(_elapsed_seconds + delta, maxf(full_day_length_seconds, 1.0))
	_apply_lighting()

func get_cycle_progress() -> float:
	return fposmod(_elapsed_seconds / maxf(full_day_length_seconds, 1.0), 1.0)

func get_time_of_day_text() -> String:
	var elapsed_seconds := clampi(floori(_elapsed_seconds), 0, maxi(0, roundi(full_day_length_seconds) - 1))
	var total_seconds := maxi(1, roundi(full_day_length_seconds))
	return "%02d:%02d / %02d:%02d" % [elapsed_seconds / 60, elapsed_seconds % 60, total_seconds / 60, total_seconds % 60]

func get_phase_text() -> String:
	return "DAY" if get_cycle_progress() < clampf(daylight_ratio, 0.1, 0.9) else "NIGHT"

func get_daylight_amount() -> float:
	var progress := get_cycle_progress()
	var day_length := clampf(daylight_ratio, 0.1, 0.9)
	var transition := minf(0.08, minf(day_length * 0.25, (1.0 - day_length) * 0.25))
	var sunrise := smoothstep(0.0, transition, progress) if transition > 0.0 else 1.0
	var sunset_start := day_length - transition
	var sunset := 1.0 - smoothstep(sunset_start, day_length, progress) if transition > 0.0 else 0.0
	return clampf(minf(sunrise, sunset), 0.0, 1.0)

func get_sun_direction() -> Vector2:
	var progress := get_cycle_progress()
	var day_length := clampf(daylight_ratio, 0.1, 0.9)
	if progress >= day_length:
		return Vector2.ZERO
	var day_progress := progress / day_length
	# The sun travels left-to-right across the map during daylight.
	return Vector2.RIGHT.rotated(lerpf(-0.72, 0.72, day_progress)).normalized()

func _apply_lighting() -> void:
	var daylight := get_daylight_amount()
	var sun_direction := get_sun_direction()
	if _canvas_modulate != null:
		var color := night_color.lerp(DAY_COLOR, daylight)
		# Warm the low sun without making the terrain unreadably orange.
		var low_sun := 1.0 - absf(daylight * 2.0 - 1.0)
		_canvas_modulate.color = color.lerp(SUNRISE_COLOR, clampf(low_sun, 0.0, 1.0) * 0.22)
	if absf(daylight - _last_daylight) < 0.001 and is_zero_approx(daylight):
		return
	_last_daylight = daylight
	lighting_changed.emit(daylight, sun_direction)
