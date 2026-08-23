extends Node

var _main: Node
var _network_session: Node

func _ready() -> void:
	_network_session = get_node("/root/NetworkSession")
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	call_deferred("_run_test")

func _run_test() -> void:
	await get_tree().physics_frame
	var mercenary := _main.get_node("Mercenary") as Entity
	assert(mercenary.network_entity_id == 1001)
	assert(_network_session.get_entity(1001) == mercenary)

	var movement := mercenary.get_component(MovementComponent) as MovementComponent
	var first_destination := Vector2(-220.0, 160.0)
	_network_session.submit_command(&"context_order", [mercenary.network_entity_id], {"destination": first_destination, "formation": false})
	assert(movement.get_destination_position() != null)

	var accepted_destination: Variant = movement.get_destination_position()
	mercenary.owning_peer_id = 42
	_network_session.submit_command(&"context_order", [mercenary.network_entity_id], {"destination": Vector2(400.0, 300.0), "formation": false})
	assert(movement.get_destination_position() == accepted_destination)

	var enemy := _main.get_node("Enemy") as Entity
	var building: Node = _main.get_node("EnemySpawnerBuilding")
	var building_center: Vector2 = building.global_position
	assert(not building.call("can_wander_to", building_center + Vector2(-80.0, 0.0), building_center + Vector2(80.0, 0.0), 12.0))
	var mercenary_combat := mercenary.get_component(CombatComponent) as CombatComponent
	mercenary_combat.set_auto_target_mode(CombatComponent.AUTO_HOLD_POSITION)
	var enemy_team := enemy.get_component(TeamComponent) as TeamComponent
	enemy_team.team = TeamComponent.Team.ENEMY
	enemy.global_position = mercenary.global_position + Vector2(28.0, 0.0)
	enemy.collision_layer = 4
	enemy.collision_mask = 15
	mercenary.owning_peer_id = 1
	movement.stuck_tick_limit = 4
	movement.stop()
	movement.move_to(mercenary.global_position + Vector2(200.0, 0.0))
	# A stalled mover gets one bounded sidestep before it gives up, so allow
	# enough physics frames for that recovery and the final blocked retry.
	for _index in range(120):
		await get_tree().physics_frame
	assert(not movement.is_moving())

	var alert := enemy.get_component(AlertComponent) as AlertComponent
	alert.enabled = true
	var wander := enemy.get_component(WanderComponent) as WanderComponent
	var home_center := wander.get_territory_center()
	wander.set_territory(Vector2(-300.0, -300.0), 64.0)
	wander.restore_home_territory()
	assert(wander.get_territory_center().distance_to(home_center) < 0.1)
	alert.call("_respond_to_alert", mercenary, mercenary.global_position)
	var enemy_health := enemy.get_component(HealthComponent) as HealthComponent
	enemy_health.damage(80.0, mercenary)
	assert(alert.state == AlertComponent.State.RETURNING)
	mercenary.queue_free()
	enemy_health.damage(1.0, mercenary)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(alert.state == AlertComponent.State.RETURNING)

	print("NETWORK_FOUNDATION_TEST_PASS")
	get_tree().quit(0)
