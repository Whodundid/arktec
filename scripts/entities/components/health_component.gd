class_name HealthComponent
extends EntityComponent

signal health_changed(current_health: float, maximum_health: float)
signal damaged(amount: float, current_health: float)
signal died

@export var maximum_health := 100.0
var current_health := 0.0

func on_entity_ready() -> void:
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)

func damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, maximum_health)
	damaged.emit(amount, current_health)
	if current_health == 0.0:
		if entity != null:
			var mouse_control := entity.get_component(MouseControlComponent) as MouseControlComponent
			if mouse_control != null:
				mouse_control.set_selected(false)
			else:
				entity.set_selected(false)
		died.emit()
		# Emit first so spawners, score systems, and other listeners can react
		# before the entity is removed from the scene tree.
		if entity != null and is_instance_valid(entity):
			entity.queue_free()

func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0 or current_health >= maximum_health:
		return
	current_health = minf(current_health + amount, maximum_health)
	health_changed.emit(current_health, maximum_health)
