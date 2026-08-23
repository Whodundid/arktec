class_name RangedProjectile
extends Area2D

@export var direction := Vector2.RIGHT
@export var speed := 900.0
@export var damage := 20.0
@export var collision_radius := 6.0
var source: Entity
var target: Entity
var lifetime := 1.5

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not NetworkSession.is_simulation_authority():
		return
	if not is_instance_valid(target):
		queue_free()
		return
	var next_position := position + direction.normalized() * speed * delta
	var maps := get_tree().get_nodes_in_group("terrain_maps")
	if not maps.is_empty() and not (maps[0] as TerrainMap).has_line_of_sight(position, next_position, collision_radius, [target.get_rid()]):
		queue_free()
		return
	position = next_position
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body == source:
		return
	if body == target and body is Entity:
		var target_health := (body as Entity).get_component(HealthComponent) as HealthComponent
		if target_health != null:
			target_health.damage(damage, source)
		queue_free()
		return
	if body is CollisionObject2D and (body as CollisionObject2D).get_collision_layer_value(6):
		queue_free()
		return
	if not body is Entity:
		return
	var health := (body as Entity).get_component(HealthComponent) as HealthComponent
	if health == null:
		return
	health.damage(damage, source)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color("f4d58b"))
	draw_circle(Vector2.ZERO, 2.0, Color("fff2bd"))
