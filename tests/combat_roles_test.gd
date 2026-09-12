extends Node

const CHARACTER_SCENE := preload("res://scenes/entities/character_entity.tscn")

var _shots_fired := 0

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var guard := _spawn_unit(TeamComponent.Team.PLAYER, AlertComponent.Role.GUARD)
	var pursuer := _spawn_unit(TeamComponent.Team.PLAYER, AlertComponent.Role.PURSUER)
	var flanker := _spawn_unit(TeamComponent.Team.PLAYER, AlertComponent.Role.FLANKER)
	var enemy := _spawn_unit(TeamComponent.Team.ENEMY, AlertComponent.Role.GUARD)
	await get_tree().physics_frame

	_assert_guard_profile(guard)
	_assert_pursuer_profile(pursuer)
	_assert_flanker_profile(flanker)
	await _assert_flanker_burst(flanker, enemy)
	await _assert_pursuer_fires_while_moving(pursuer, enemy)

	print("COMBAT_ROLES_TEST_PASS")
	get_tree().quit(0)

func _spawn_unit(team_value: TeamComponent.Team, role_value: AlertComponent.Role) -> Entity:
	var unit := CHARACTER_SCENE.instantiate() as Entity
	(unit.get_node("TeamComponent") as TeamComponent).team = team_value
	add_child(unit)
	(unit.get_component(AlertComponent) as AlertComponent).set_role(role_value)
	return unit

func _assert_guard_profile(unit: Entity) -> void:
	var movement := unit.get_component(MovementComponent) as MovementComponent
	var combat := unit.get_component(CombatComponent) as CombatComponent
	var health := unit.get_component(HealthComponent) as HealthComponent
	assert(is_equal_approx(movement.speed_meters_per_second, 2.2))
	assert(is_equal_approx(health.maximum_health, 170.0))
	assert(is_equal_approx(combat.fire_interval, 0.9))
	assert(is_equal_approx(combat.projectile_damage, 45.0))
	assert(combat.burst_shot_count == 1)
	assert(not combat.can_fire_while_moving)

func _assert_pursuer_profile(unit: Entity) -> void:
	var movement := unit.get_component(MovementComponent) as MovementComponent
	var combat := unit.get_component(CombatComponent) as CombatComponent
	assert(is_equal_approx(movement.speed_meters_per_second, 3.2))
	assert(combat.burst_shot_count == 1)
	assert(combat.can_fire_while_moving)

func _assert_flanker_profile(unit: Entity) -> void:
	var movement := unit.get_component(MovementComponent) as MovementComponent
	var combat := unit.get_component(CombatComponent) as CombatComponent
	var health := unit.get_component(HealthComponent) as HealthComponent
	assert(is_equal_approx(movement.speed_meters_per_second, 4.2))
	assert(is_equal_approx(health.maximum_health, 60.0))
	assert(combat.burst_shot_count == 3)
	assert(is_equal_approx(combat.projectile_damage, 9.0))
	assert(not combat.can_fire_while_moving)

func _assert_flanker_burst(flanker: Entity, enemy: Entity) -> void:
	_shots_fired = 0
	var combat := flanker.get_component(CombatComponent) as CombatComponent
	combat.shot_fired.connect(_on_shot_fired)
	combat.set_target(enemy)
	for _frame in range(20):
		await get_tree().physics_frame
	assert(_shots_fired == 3)
	combat.clear_target("test_complete")
	combat.shot_fired.disconnect(_on_shot_fired)

func _assert_pursuer_fires_while_moving(pursuer: Entity, enemy: Entity) -> void:
	_shots_fired = 0
	var combat := pursuer.get_component(CombatComponent) as CombatComponent
	var movement := pursuer.get_component(MovementComponent) as MovementComponent
	combat.shot_fired.connect(_on_shot_fired)
	movement.move_to(pursuer.global_position + Vector2(1000.0, 0.0))
	combat.set_target(enemy, false)
	await get_tree().physics_frame
	assert(movement.is_moving())
	assert(_shots_fired == 1)
	combat.shot_fired.disconnect(_on_shot_fired)

func _on_shot_fired(_projectile: Node2D, _target: Entity) -> void:
	_shots_fired += 1
