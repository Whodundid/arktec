class_name HealthComponent
extends EntityComponent

signal health_changed(current_health: float, maximum_health: float)
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
	if current_health == 0.0:
		died.emit()

func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = minf(current_health + amount, maximum_health)
	health_changed.emit(current_health, maximum_health)
