extends Node2D

## Application entry point. Mission flow and global systems will be added here.

func _ready() -> void:
	get_tree().paused = false
	RuntimeLogger.info("Main scene ready; gameplay tree unpaused")
