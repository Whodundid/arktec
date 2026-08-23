class_name EnemySpawner
extends Node2D

## Small combat test harness. Production wave logic can listen to the same
## spawn/death signals later without changing EnemyEntity.

signal enemy_spawned(enemy: Entity)
signal enemy_removed(enemy: Entity)

@export var enemy_scene: PackedScene
@export var spawn_positions := [Vector2(360, 0), Vector2(430, 80), Vector2(430, -80)]
@export var respawn_delay := 2.0

var _next_spawn_index := 0
var _active_enemies: Array[Entity] = []

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1:
		spawn_enemy()
	elif event.keycode == KEY_F2:
		for index in range(3):
			spawn_enemy()
	elif event.keycode == KEY_F3:
		_clear_enemies()

func spawn_enemy() -> Entity:
	if enemy_scene == null:
		return null
	var enemy := enemy_scene.instantiate() as Entity
	if enemy == null:
		return null
	enemy.position = spawn_positions[_next_spawn_index % spawn_positions.size()]
	_next_spawn_index += 1
	enemy.set("display_name", "Stalker")
	enemy.set("body_color", Color("c94f59"))
	enemy.collision_layer = 4
	enemy.collision_mask = 15
	var team := enemy.get_component(TeamComponent) as TeamComponent
	team.team = TeamComponent.Team.ENEMY
	var health := enemy.get_component(HealthComponent) as HealthComponent
	health.died.connect(_on_enemy_died.bind(enemy))
	get_tree().current_scene.add_child(enemy)
	_active_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	return enemy

func _on_enemy_died(enemy: Entity) -> void:
	if not _active_enemies.has(enemy):
		return
	_active_enemies.erase(enemy)
	enemy_removed.emit(enemy)
	var timer := get_tree().create_timer(respawn_delay, false)
	timer.timeout.connect(spawn_enemy)
	call_deferred("_remove_dead_enemy", enemy)

func _remove_dead_enemy(enemy: Entity) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()

func _clear_enemies() -> void:
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
