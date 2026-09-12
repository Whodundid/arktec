extends Node

const BATTLE_SANDBOX_SCENE = preload("res://scenes/battle_sandbox.tscn")

func _ready() -> void:
	get_node("/root/WorldSeed").set("active_seed", 123456789)
	var sandbox := BATTLE_SANDBOX_SCENE.instantiate()
	sandbox.set("starting_spawn_jitter", 0.0)
	sandbox.set("rail_construction_duration", 0.1)
	sandbox.set("rail_repair_duration", 0.1)
	add_child(sandbox)
	for _frame in range(5):
		await get_tree().process_frame
	var terrain := sandbox.get_node("TerrainMap") as TerrainMap
	var network := sandbox.get_node("RailNetwork") as Node2D
	var builder := _find_player_builder()
	assert(builder != null)
	var landing_ship := _find_player_landing_ship()
	assert(landing_ship != null)
	var ship_half_size := Vector2(landing_ship.landing_ship_grid_size) * landing_ship.landing_ship_tile_size * 0.5
	var ship_rect := Rect2(landing_ship.global_position - ship_half_size, ship_half_size * 2.0)
	assert(not ship_rect.grow(builder.collision_radius).has_point(builder.global_position))

	var receiver_cell := terrain.get_landing_ship_rail_receiver_cell()
	assert(network.call("can_place_rail_cell", receiver_cell))
	var ore_before := ResourceLedger.get_ore(TeamComponent.Team.PLAYER)
	assert(sandbox.call("request_player_rail_construction", builder, terrain.cell_center(receiver_cell)))
	assert(ResourceLedger.get_ore(TeamComponent.Team.PLAYER) == ore_before - int(sandbox.get("rail_cost")))
	var receiver_segment := network.call("get_segment_at_cell", receiver_cell) as Node2D
	assert(receiver_segment != null)
	assert(receiver_segment.global_position == terrain.cell_center(receiver_cell))
	assert(bool(receiver_segment.get("under_construction")))
	for _frame in range(120):
		await get_tree().physics_frame
	assert(not bool(receiver_segment.get("under_construction")))
	assert(bool(receiver_segment.call("is_operational")))
	assert((int(receiver_segment.get("connection_mask")) & 1) != 0)

	receiver_segment.call("damage", float(receiver_segment.get("maximum_health")))
	assert(not bool(receiver_segment.call("is_operational")))
	assert(sandbox.call("request_player_rail_work", builder, receiver_segment))
	for _frame in range(120):
		await get_tree().physics_frame
	assert(is_equal_approx(float(receiver_segment.get("current_health")), float(receiver_segment.get("maximum_health"))))
	assert(bool(receiver_segment.call("is_operational")))

	var plus_center := _find_open_plus_cell(terrain, network)
	assert(plus_center != Vector2i(-1, -1))
	var cells := [plus_center, plus_center + Vector2i.UP, plus_center + Vector2i.RIGHT, plus_center + Vector2i.DOWN, plus_center + Vector2i.LEFT]
	for cell in cells:
		var segment := network.call("create_construction_site", cell, 60.0) as Node2D
		assert(segment != null)
		segment.call("complete_construction")
	var junction := network.call("get_segment_at_cell", plus_center) as Node2D
	assert(int(junction.get("connection_mask")) == 15)
	assert(int((network.call("get_segment_at_cell", plus_center + Vector2i.UP) as Node2D).get("connection_mask")) == 4)
	assert(int((network.call("get_segment_at_cell", plus_center + Vector2i.RIGHT) as Node2D).get("connection_mask")) == 8)
	assert(int((network.call("get_segment_at_cell", plus_center + Vector2i.DOWN) as Node2D).get("connection_mask")) == 1)
	assert(int((network.call("get_segment_at_cell", plus_center + Vector2i.LEFT) as Node2D).get("connection_mask")) == 2)

	var artifact_cells: Array[Vector2i] = terrain.get_artifact_spawn_cells()
	assert(not bool(network.call("can_place_rail_cell", artifact_cells[0])))
	var has_adjacent_buildable_cell := false
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if bool(network.call("can_place_rail_cell", artifact_cells[0] + direction)):
			has_adjacent_buildable_cell = true
			break
	assert(has_adjacent_buildable_cell)

	print("RAIL_CONSTRUCTION_TEST_PASS")
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

func _find_player_landing_ship() -> EnemySpawnerBuilding:
	for candidate in get_tree().get_nodes_in_group("territory_owners"):
		if candidate is EnemySpawnerBuilding and (candidate as EnemySpawnerBuilding).is_landing_ship:
			return candidate as EnemySpawnerBuilding
	return null

func _find_open_plus_cell(terrain: TerrainMap, network: Node2D) -> Vector2i:
	for y in range(2, terrain.rows - 2):
		for x in range(2, terrain.columns - 2):
			var center := Vector2i(x, y)
			var valid := true
			for offset in [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				if not bool(network.call("can_place_rail_cell", center + offset)):
					valid = false
					break
			if valid:
				return center
	return Vector2i(-1, -1)
