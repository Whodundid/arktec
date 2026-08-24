extends Node

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var prototype := preload("res://scenes/terrain_3d_prototype.tscn").instantiate()
	add_child(prototype)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := prototype.get_node("MercenarySignpost") as SignpostUnit3D
	var guard := prototype.get_node("RedGuardSignpost") as SignpostUnit3D
	assert(player != null and guard != null)
	var camera := prototype.get_node("OrbitCamera") as Camera3D
	var player_screen := camera.unproject_position(player.global_position + Vector3(0.0, 0.78, 0.0))
	prototype.call("_select_units_in_screen_rect", Rect2(player_screen - Vector2(12.0, 12.0), Vector2(24.0, 24.0)))
	assert(player.selected, "Projected marquee selection should select the player signpost")

	var diagonal_goal: Vector3 = prototype.call("_cell_to_world_top", Vector2i(10, 11))
	var diagonal_path: Array = prototype.call("_find_world_path", player.global_position, diagonal_goal)
	assert(diagonal_path.size() == 1, "Open terrain should collapse to one free diagonal segment")

	guard.global_position = prototype.call("_cell_to_world_top", Vector2i(7, 10))
	guard.attack_damage = 0.0
	player.attack_damage = 100.0
	player.fire_interval = 0.01
	var attack_move_goal: Vector3 = prototype.call("_cell_to_world_top", Vector2i(10, 10))
	prototype.call("_issue_attack_move", player, attack_move_goal)
	var player_start := player.global_position
	for _index in range(20):
		await get_tree().process_frame
	assert(not is_instance_valid(guard), "Attack-move should destroy an encountered enemy")
	assert(player.global_position.distance_to(player_start) > 0.01, "Attack-move should resume after combat")

	var pursuer := prototype.get_node("RedPursuerSignpost") as SignpostUnit3D
	pursuer.global_position = prototype.call("_cell_to_world_top", Vector2i(7, 10))
	pursuer.attack_damage = 0.0
	pursuer.maximum_health = 1000.0
	pursuer.current_health = 1000.0
	player.attack_damage = 1.0
	player.fire_cooldown = 0.0
	prototype.call("_issue_hold_position", player)
	assert(not player.has_pending_path(), "Hold position should clear movement")
	var health_before := pursuer.current_health
	for _index in range(20):
		await get_tree().process_frame
	assert(pursuer.current_health < health_before, "Hold position should fire without chasing")

	print("TERRAIN_3D_COMBAT_TEST_PASS")
	get_tree().quit(0)
