class_name EntityComponent
extends Node

## Base behavior module for an Entity.
## Components should own one focused responsibility and communicate through
## signals or well-defined methods instead of reaching into sibling internals.

var entity: Entity

func attach_to_entity(target: Entity) -> void:
	entity = target

func on_entity_ready() -> void:
	pass
