class_name IdleLookComponent
extends EntityComponent

## Small ambient behavior that changes only a unit's facing while it is idle.
## It never issues movement or combat commands, so player units can use it too.

@export var enabled := true
@export_range(0.5, 30.0, 0.5) var min_idle_seconds := 3.0
@export_range(0.5, 30.0, 0.5) var max_idle_seconds := 7.0
@export_range(0.25, 8.0, 0.25) var min_look_pause_seconds := 1.0
@export_range(0.25, 8.0, 0.25) var max_look_pause_seconds := 3.0

var _random := RandomNumberGenerator.new()
var _movement: MovementComponent
var _combat: CombatComponent
var _alert: AlertComponent
var _idle_remaining := 0.0
var _look_pause_remaining := 0.0
var _look_direction := Vector2.ZERO

func on_entity_ready() -> void:
	_random.randomize()
	_movement = entity.get_component(MovementComponent) as MovementComponent
	_combat = entity.get_component(CombatComponent) as CombatComponent
	_alert = entity.get_component(AlertComponent) as AlertComponent
	_idle_remaining = _random_idle_delay()

func _physics_process(delta: float) -> void:
	if not enabled or entity == null or _movement == null:
		return
	if _is_under_other_control():
		_cancel_idle_look()
		_idle_remaining = _random_idle_delay()
		return

	if _look_direction != Vector2.ZERO:
		entity.turn_towards(_look_direction, delta)
		if absf(entity.facing_direction.angle_to(_look_direction)) <= deg_to_rad(1.0):
			entity.set_facing_direction(_look_direction)
			_look_direction = Vector2.ZERO
			_look_pause_remaining = _random_look_pause()
		return

	if _look_pause_remaining > 0.0:
		_look_pause_remaining -= delta
		return

	_idle_remaining -= delta
	if _idle_remaining <= 0.0:
		_look_direction = Vector2.RIGHT.rotated(_random.randf_range(0.0, TAU))

func _is_under_other_control() -> bool:
	if _movement.is_moving():
		return true
	if _combat != null and is_instance_valid(_combat.target):
		return true
	if _alert != null and _alert.enabled and _alert.state != AlertComponent.State.IDLE:
		return true
	return false

func _cancel_idle_look() -> void:
	_look_direction = Vector2.ZERO
	_look_pause_remaining = 0.0

func _random_idle_delay() -> float:
	return _random.randf_range(minf(min_idle_seconds, max_idle_seconds), maxf(min_idle_seconds, max_idle_seconds))

func _random_look_pause() -> float:
	return _random.randf_range(minf(min_look_pause_seconds, max_look_pause_seconds), maxf(min_look_pause_seconds, max_look_pause_seconds))
