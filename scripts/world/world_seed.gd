extends Node

## One seed for all procedural world decisions made during this run.
##
## The simulation authority owns this value. A future multiplayer handshake can
## replace it with the server-provided seed before generating the map.
var active_seed: int = 0

func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.randomize()
	active_seed = random.randi()
	RuntimeLogger.info("World seed initialized: %d" % active_seed)

func get_seed() -> int:
	return active_seed
