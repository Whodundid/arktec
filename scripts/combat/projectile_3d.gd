class_name Projectile3D
extends Node3D

@export var speed := 40.0
@export var damage := 20.0
@export var projectile_color := Color("f4d58b")

var target: SignpostUnit3D

func _ready() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.075
	mesh.height = 0.15
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = projectile_color
	material.emission_enabled = true
	material.emission = projectile_color
	material.emission_energy_multiplier = 2.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _process(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_alive():
		queue_free()
		return
	var target_position := target.global_position + Vector3(0.0, 0.84, 0.0)
	var distance := global_position.distance_to(target_position)
	if distance <= maxf(speed * delta, 0.08):
		target.take_damage(damage)
		queue_free()
		return
	global_position = global_position.move_toward(target_position, speed * delta)
