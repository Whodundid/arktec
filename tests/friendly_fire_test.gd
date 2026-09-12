extends Node

const CHARACTER_SCENE := preload("res://scenes/entities/character_entity.tscn")
const PROJECTILE_SCENE := preload("res://scenes/combat/ranged_projectile.tscn")

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var shooter := _spawn_unit(TeamComponent.Team.PLAYER)
	var friendly := _spawn_unit(TeamComponent.Team.PLAYER)
	var enemy := _spawn_unit(TeamComponent.Team.ENEMY)
	await get_tree().physics_frame

	var friendly_health := friendly.get_component(HealthComponent) as HealthComponent
	var enemy_health := enemy.get_component(HealthComponent) as HealthComponent
	var starting_friendly_health := friendly_health.current_health
	var starting_enemy_health := enemy_health.current_health

	# The health boundary rejects direct same-team damage as a final safeguard.
	friendly_health.damage(20.0, shooter)
	assert(friendly_health.current_health == starting_friendly_health)

	# A friendly crossing the firing line does not absorb or consume the shot.
	var friendly_projectile := _spawn_projectile(shooter, enemy)
	friendly_projectile.call("_on_body_entered", friendly)
	assert(friendly_health.current_health == starting_friendly_health)
	assert(not friendly_projectile.is_queued_for_deletion())

	# An enemy crossing the same firing line still takes damage and consumes it.
	var enemy_projectile := _spawn_projectile(shooter, enemy)
	enemy_projectile.call("_on_body_entered", enemy)
	assert(enemy_health.current_health == starting_enemy_health - enemy_projectile.damage)
	assert(enemy_projectile.is_queued_for_deletion())

	print("FRIENDLY_FIRE_TEST_PASS")
	get_tree().quit(0)

func _spawn_unit(team_value: TeamComponent.Team) -> Entity:
	var unit := CHARACTER_SCENE.instantiate() as Entity
	(unit.get_node("TeamComponent") as TeamComponent).team = team_value
	add_child(unit)
	return unit

func _spawn_projectile(shooter: Entity, intended_target: Entity) -> RangedProjectile:
	var projectile := PROJECTILE_SCENE.instantiate() as RangedProjectile
	projectile.source = shooter
	projectile.target = intended_target
	add_child(projectile)
	projectile.set_physics_process(false)
	return projectile
