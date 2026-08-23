class_name PassiveHealthRegenComponent
extends EntityComponent

## Slowly restores an entity's health while it remains alive.
## The rate belongs to the entity so different unit types can tune it without
## needing a different regeneration component or scene script.

func _physics_process(delta: float) -> void:
	if entity == null or entity.health_regen_per_second <= 0.0:
		return
	var health := entity.get_component(HealthComponent) as HealthComponent
	if health == null:
		return
	health.heal(entity.health_regen_per_second * delta)
