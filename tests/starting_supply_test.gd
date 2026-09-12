extends Node

const BATTLE_SANDBOX_SCENE := preload("res://scenes/battle_sandbox.tscn")

func _ready() -> void:
	var sandbox := BATTLE_SANDBOX_SCENE.instantiate() as BattleSandbox
	sandbox.starting_spawn_jitter = 0.0
	add_child(sandbox)
	for _frame in range(5):
		await get_tree().process_frame

	var supply := sandbox.get_faction_supply(TeamComponent.Team.PLAYER)
	assert(int(supply.get("current", -1)) == sandbox.starting_units_per_faction)
	assert(int(supply.get("maximum", -1)) == 5)
	print("STARTING_SUPPLY_TEST_PASS")
	get_tree().quit(0)
