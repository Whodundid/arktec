extends Node

const BATTLE_SANDBOX_SCENE = preload("res://scenes/battle_sandbox.tscn")

var _started_count := 0
var _interrupted_count := 0
var _completed_count := 0
var _rail_ready_count := 0
var _rail_required_count := 0

func _ready() -> void:
	get_node("/root/WorldSeed").set("active_seed", 123456789)
	var sandbox := BATTLE_SANDBOX_SCENE.instantiate() as BattleSandbox
	sandbox.starting_spawn_jitter = 0.0
	add_child(sandbox)
	for _frame in range(5):
		await get_tree().process_frame

	var builder := _find_player_builder()
	var artifact := _find_artifact()
	var artifact_field := sandbox.get_node("ArtifactField") as Node2D
	var network := sandbox.get_node("RailNetwork") as Node2D
	assert(builder != null)
	assert(artifact != null)
	assert(artifact_field != null)
	assert(network != null)
	var expected_duration: float = [10.0, 15.0, 22.0][int(artifact.get("rarity"))]
	assert(is_equal_approx(float(artifact.call("get_excavation_duration")), expected_duration))
	artifact.set("common_excavation_duration", 0.35)
	artifact.set("rare_excavation_duration", 0.35)
	artifact.set("exotic_excavation_duration", 0.35)
	artifact_field.connect("artifact_excavation_started", _on_excavation_started)
	artifact_field.connect("artifact_excavation_interrupted", _on_excavation_interrupted)
	artifact_field.connect("artifact_excavation_completed", _on_excavation_completed)
	artifact.connect("rail_readiness_changed", _on_rail_readiness_changed)

	var movement := builder.get_component(MovementComponent) as MovementComponent
	if movement != null:
		movement.stop()
	var work_position: Vector2 = artifact.call("get_excavation_work_position", builder.global_position, builder.collision_radius)
	builder.global_position = work_position
	var buried_health: float = artifact.get("current_health")
	artifact.call("damage", 20.0)
	assert(is_equal_approx(float(artifact.get("current_health")), buried_health))

	assert(sandbox.request_player_artifact_excavation(builder, artifact))
	assert(sandbox.has_player_excavation_order(builder))
	for _frame in range(6):
		await get_tree().physics_frame
	var partial_progress: float = artifact.get("excavation_progress")
	assert(partial_progress > 0.0 and partial_progress < 1.0)
	artifact.call("damage", 20.0)
	assert(is_equal_approx(float(artifact.get("current_health")), buried_health))

	NetworkSession.submit_command(&"context_order", [builder.network_entity_id], {"destination": builder.global_position + Vector2.RIGHT * 128.0, "formation": false})
	assert(not sandbox.has_player_excavation_order(builder))
	assert(is_equal_approx(float(artifact.get("excavation_progress")), partial_progress))
	assert(str(artifact.call("status_text")).begins_with("EXCAVATION PAUSED"))
	for _frame in range(6):
		await get_tree().physics_frame
	assert(is_equal_approx(float(artifact.get("excavation_progress")), partial_progress))

	if movement != null:
		movement.stop()
	builder.global_position = work_position
	assert(sandbox.request_player_artifact_excavation(builder, artifact))
	for _frame in range(6):
		await get_tree().physics_frame
	var progress_before_attack_move: float = artifact.get("excavation_progress")
	assert(progress_before_attack_move > partial_progress)
	builder.set_selected(true)
	var controller := sandbox.get_node("GroupMovementController") as GroupMovementController
	controller.arm_attack_move()
	controller.confirm_attack_move(builder.global_position + Vector2.RIGHT * 128.0)
	assert(not sandbox.has_player_excavation_order(builder))
	assert(is_equal_approx(float(artifact.get("excavation_progress")), progress_before_attack_move))
	assert(str(artifact.call("status_text")).begins_with("EXCAVATION PAUSED"))
	builder.set_selected(false)

	if movement != null:
		movement.stop()
	builder.global_position = work_position
	assert(sandbox.request_player_artifact_excavation(builder, artifact))
	for _frame in range(30):
		await get_tree().physics_frame
	assert(bool(artifact.call("is_excavation_complete")))
	assert(not sandbox.has_player_excavation_order(builder))
	assert(str(artifact.call("status_text")) == "RAIL REQUIRED")
	assert(_started_count == 3)
	assert(_interrupted_count == 2)
	assert(_completed_count == 1)

	artifact.call("damage", 20.0)
	assert(is_equal_approx(float(artifact.get("current_health")), buried_health - 20.0))
	var diagonal_cell := _find_buildable_diagonal_cell(artifact, network)
	assert(diagonal_cell != Vector2i(-1, -1))
	var diagonal_segment := network.call("create_construction_site", diagonal_cell, 60.0) as Node2D
	assert(diagonal_segment != null)
	diagonal_segment.call("complete_construction")
	await get_tree().physics_frame
	assert(not bool(artifact.call("is_rail_ready")))
	var adjacent_cell := _find_buildable_adjacent_cell(artifact, network)
	assert(adjacent_cell != Vector2i(-1, -1))
	var segment := network.call("create_construction_site", adjacent_cell, 60.0) as Node2D
	assert(segment != null)
	await get_tree().physics_frame
	assert(not bool(artifact.call("is_rail_ready")))
	segment.call("complete_construction")
	await get_tree().physics_frame
	assert(bool(artifact.call("is_rail_ready")))
	assert(_rail_ready_count == 1)
	segment.call("damage", float(segment.get("maximum_health")))
	await get_tree().physics_frame
	assert(not bool(artifact.call("is_rail_ready")))
	assert(str(artifact.call("status_text")) == "RAIL REQUIRED")
	assert(_rail_required_count == 1)
	artifact.call("damage", 20.0)
	assert(is_equal_approx(float(artifact.get("current_health")), buried_health - 40.0))

	print("ARTIFACT_EXCAVATION_TEST_PASS")
	get_tree().quit(0)

func _find_player_builder() -> Entity:
	for candidate in get_tree().get_nodes_in_group("entities"):
		if not candidate is Entity or (candidate as Entity).grounded:
			continue
		var entity := candidate as Entity
		var team := entity.get_component(TeamComponent) as TeamComponent
		var alert := entity.get_component(AlertComponent) as AlertComponent
		if team != null and team.team == TeamComponent.Team.PLAYER and alert != null and alert.role == AlertComponent.Role.BUILDER:
			return entity
	return null

func _find_artifact() -> Node2D:
	var artifacts := get_tree().get_nodes_in_group("artifacts")
	return null if artifacts.is_empty() else artifacts[0] as Node2D

func _find_buildable_adjacent_cell(artifact: Node2D, network: Node2D) -> Vector2i:
	var artifact_cell: Vector2i = artifact.get("grid_cell")
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var candidate: Vector2i = artifact_cell + direction
		if bool(network.call("can_place_rail_cell", candidate)):
			return candidate
	return Vector2i(-1, -1)

func _find_buildable_diagonal_cell(artifact: Node2D, network: Node2D) -> Vector2i:
	var artifact_cell: Vector2i = artifact.get("grid_cell")
	for direction in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		var candidate: Vector2i = artifact_cell + direction
		if bool(network.call("can_place_rail_cell", candidate)):
			return candidate
	return Vector2i(-1, -1)

func _on_excavation_started(_artifact: Node2D) -> void:
	_started_count += 1

func _on_excavation_interrupted(_artifact: Node2D, _progress: float) -> void:
	_interrupted_count += 1

func _on_excavation_completed(_artifact: Node2D) -> void:
	_completed_count += 1

func _on_rail_readiness_changed(_artifact: Node2D, ready: bool) -> void:
	if ready:
		_rail_ready_count += 1
	else:
		_rail_required_count += 1
