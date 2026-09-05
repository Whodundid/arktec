extends Node

const BATTLE_SANDBOX_SCENE = preload("res://scenes/battle_sandbox.tscn")
const CHARACTER_SCENE = preload("res://scenes/entities/character_entity.tscn")

func _ready() -> void:
	# Exercise the profiler directly so this test never changes the user's
	# persisted opt-in setting.
	DeepProfiler.set_enabled(false)
	DeepProfiler.set_enabled(true)
	var profile_path := DeepProfiler.get_profile_path()
	assert(not profile_path.is_empty())
	DeepProfiler.increment("test.counter", 3)
	DeepProfiler.record_timing("test.timing", 1500)
	var sandbox := BATTLE_SANDBOX_SCENE.instantiate()
	add_child(sandbox)
	await get_tree().process_frame
	var home: EnemySpawnerBuilding
	for owner in get_tree().get_nodes_in_group("territory_owners"):
		if owner is EnemySpawnerBuilding:
			home = owner as EnemySpawnerBuilding
			break
	assert(home != null)
	var worker := CHARACTER_SCENE.instantiate() as Entity
	var worker_team := worker.get_node("TeamComponent") as TeamComponent
	worker_team.team = home.faction_team
	worker.global_position = home.global_position + Vector2(160.0, 0.0)
	add_child(worker)
	await get_tree().process_frame
	var harvest := worker.get_component(HarvestComponent) as HarvestComponent
	harvest.carried_ore = 5.0
	var return_started := harvest.request_return_to_building(home)
	assert(return_started)
	await get_tree().create_timer(1.1).timeout
	DeepProfiler.set_enabled(false)

	assert(FileAccess.file_exists(profile_path))
	var file := FileAccess.open(profile_path, FileAccess.READ)
	assert(file != null)
	var found_sample := false
	var found_movement_timing := false
	var found_navigation_timing := false
	var home_approach_calculations := 0
	while file.get_position() < file.get_length():
		var parsed: Variant = JSON.parse_string(file.get_line())
		if not parsed is Dictionary or parsed.get("type", "") != "profile_sample":
			continue
		var counters: Dictionary = parsed.get("counters", {})
		var timings: Dictionary = parsed.get("timings", {})
		if int(counters.get("test.counter", 0)) == 3 and timings.has("test.timing"):
			found_sample = true
		if timings.has("movement.soft_collision_update") and timings.has("movement.move_and_slide"):
			found_movement_timing = true
		if timings.has("navigation.find_path") and int(counters.get("navigation.find_path_requests", 0)) > 0:
			found_navigation_timing = true
		home_approach_calculations += int(counters.get("harvest.home_approach_calculations", 0))
	file.close()
	assert(found_sample)
	assert(found_movement_timing)
	assert(found_navigation_timing)
	assert(home_approach_calculations == 1)
	print("DEEP_PROFILER_TEST_PASS")
	get_tree().quit(0)
