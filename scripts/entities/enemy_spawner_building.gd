class_name EnemySpawnerBuilding
extends Entity

## Enemy structure that maintains a small, bounded group of attackers.

signal enemy_spawned(enemy: Entity)
signal building_destroyed

@export var enemy_scene: PackedScene
@export var display_name := "Enemy Spawner"
@export var spawn_positions := [Vector2(-48, -32), Vector2(48, -32), Vector2(0, 48)]
@export var max_active_enemies := 3
@export var respawn_delay := 4.0

var _active_enemies: Array[Entity] = []
var _next_spawn_index := 0
var _destroyed := false

func _ready() -> void:
	super._ready()
	var health := get_component(HealthComponent) as HealthComponent
	if health != null:
		health.died.connect(_on_building_died)
	call_deferred("_spawn_initial_enemies")
	queue_redraw()

func _spawn_initial_enemies() -> void:
	for index in range(max_active_enemies):
		_spawn_enemy()

func _spawn_enemy() -> void:
	if _destroyed or enemy_scene == null or _active_enemies.size() >= max_active_enemies:
		return
	var enemy := enemy_scene.instantiate() as Entity
	if enemy == null:
		return
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = global_position + spawn_positions[_next_spawn_index % spawn_positions.size()]
	_next_spawn_index += 1
	enemy.set("display_name", "Stalker")
	enemy.set("body_color", Color("c94f59"))
	enemy.collision_layer = 4
	enemy.collision_mask = 1
	var team := enemy.get_component(TeamComponent) as TeamComponent
	if team != null:
		team.team = TeamComponent.Team.ENEMY
	var health := enemy.get_component(HealthComponent) as HealthComponent
	if health != null:
		health.died.connect(_on_enemy_died.bind(enemy))
	_active_enemies.append(enemy)
	enemy_spawned.emit(enemy)

func _on_enemy_died(enemy: Entity) -> void:
	_active_enemies.erase(enemy)
	if _destroyed:
		return
	var timer := get_tree().create_timer(respawn_delay, false)
	timer.timeout.connect(_spawn_enemy)

func _on_building_died() -> void:
	_destroyed = true
	_active_enemies.clear()
	building_destroyed.emit()

func _draw() -> void:
	draw_selection_ring(40.0, 3.0)
	draw_rect(Rect2(-30, -24, 60, 48), Color("293b46"), true)
	draw_rect(Rect2(-30, -24, 60, 48), Color("d5a7df"), false, 3.0)
	draw_circle(Vector2.ZERO, 13.0, Color("7e4f8f"))
	draw_circle(Vector2.ZERO, 6.0, Color("d5a7df"))
	draw_string(ThemeDB.fallback_font, Vector2(-52, 48), "Spawner", HORIZONTAL_ALIGNMENT_CENTER, 104, 12, Color("dce5df"))
