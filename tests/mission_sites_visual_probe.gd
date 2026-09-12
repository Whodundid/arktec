extends Node

const BATTLE_SANDBOX_SCENE = preload("res://scenes/battle_sandbox.tscn")

func _ready() -> void:
	get_viewport().size = Vector2i(1280, 720)
	get_node("/root/WorldSeed").set("active_seed", 123456789)
	var sandbox := BATTLE_SANDBOX_SCENE.instantiate()
	sandbox.set("starting_spawn_jitter", 0.0)
	add_child(sandbox)
	for _frame in range(6):
		await get_tree().process_frame
	var terrain := sandbox.get_node("TerrainMap") as TerrainMap
	var camera := sandbox.get_node("RTSCamera") as Camera2D
	var network := sandbox.get_node("RailNetwork") as Node2D
	var receiver := terrain.get_landing_ship_rail_receiver_cell()
	for cell in [receiver, receiver + Vector2i.DOWN, receiver + Vector2i.DOWN + Vector2i.LEFT, receiver + Vector2i.DOWN + Vector2i.RIGHT]:
		if bool(network.call("can_place_rail_cell", cell)):
			var segment := network.call("create_construction_site", cell, 60.0) as Node2D
			segment.call("complete_construction")
	var broken_demo := network.call("get_segment_at_cell", receiver + Vector2i.DOWN + Vector2i.RIGHT) as Node2D
	if broken_demo != null:
		broken_demo.call("damage", 60.0)
	for candidate in get_tree().get_nodes_in_group("entities"):
		if candidate is Entity and not (candidate as Entity).grounded:
			var team := (candidate as Entity).get_component(TeamComponent) as TeamComponent
			var alert := (candidate as Entity).get_component(AlertComponent) as AlertComponent
			if team != null and team.team == TeamComponent.Team.PLAYER and alert != null and alert.role == AlertComponent.Role.BUILDER:
				(candidate as Entity).set_selected(true)
				break
	(sandbox.get_node("HUD/Interface") as Control).set("_build_mode", 100)
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE
	var output_directory := OS.get_temp_dir()
	camera.global_position = terrain.get_landing_ship_center()
	await RenderingServer.frame_post_draw
	var ship_path := output_directory.path_join("artifactrun_landing_ship_probe.png")
	get_viewport().get_texture().get_image().save_png(ship_path)
	var artifact_positions: Array[Vector2] = terrain.get_artifact_spawn_positions()
	if not artifact_positions.is_empty():
		camera.global_position = artifact_positions[0]
		await RenderingServer.frame_post_draw
		var artifact_path := output_directory.path_join("artifactrun_artifact_probe.png")
		get_viewport().get_texture().get_image().save_png(artifact_path)
		print("MISSION_SITES_ARTIFACT_PROBE=%s" % artifact_path)
	print("MISSION_SITES_SHIP_PROBE=%s" % ship_path)
	get_tree().quit(0)
