extends Node2D

const ARTIFACT_SITE_SCRIPT = preload("res://scripts/world/artifact_site.gd")

signal artifact_excavation_started(artifact: Node2D)
signal artifact_excavation_interrupted(artifact: Node2D, progress: float)
signal artifact_excavation_completed(artifact: Node2D)

@export_range(0.0, 1.0, 0.01) var common_weight := 0.60
@export_range(0.0, 1.0, 0.01) var rare_weight := 0.30

var _random := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("artifact_fields")
	if not NetworkSession.is_simulation_authority():
		return
	_random.seed = _get_active_world_seed() ^ 0x415246
	var terrain_map := _find_terrain_map()
	if terrain_map == null or not terrain_map.has_method("get_artifact_spawn_cells"):
		return
	var cells: Array[Vector2i] = terrain_map.call("get_artifact_spawn_cells")
	if cells.is_empty():
		return
	var objective_count := _random.randi_range(1, cells.size())
	for index in range(cells.size()):
		var artifact := ARTIFACT_SITE_SCRIPT.new() as StaticBody2D
		artifact.set("grid_cell", cells[index])
		artifact.set("tile_size", terrain_map.tile_size)
		artifact.set("rarity", _choose_rarity())
		artifact.set("mission_objective", index < objective_count)
		artifact.position = terrain_map.cell_center(cells[index])
		add_child(artifact)
		artifact.connect("excavation_started", _on_artifact_excavation_started)
		artifact.connect("excavation_interrupted", _on_artifact_excavation_interrupted)
		artifact.connect("excavation_completed", _on_artifact_excavation_completed)

func _on_artifact_excavation_started(artifact: Node2D) -> void:
	artifact_excavation_started.emit(artifact)

func _on_artifact_excavation_interrupted(artifact: Node2D, progress: float) -> void:
	artifact_excavation_interrupted.emit(artifact, progress)

func _on_artifact_excavation_completed(artifact: Node2D) -> void:
	artifact_excavation_completed.emit(artifact)

func _choose_rarity() -> int:
	var roll := _random.randf()
	if roll < common_weight:
		return 0
	if roll < common_weight + rare_weight:
		return 1
	return 2

func _find_terrain_map() -> TerrainMap:
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	return null if maps.is_empty() else maps[0] as TerrainMap

func _get_active_world_seed() -> int:
	var seed_provider := get_node_or_null("/root/WorldSeed")
	return 0 if seed_provider == null else int(seed_provider.call("get_seed"))
