extends Node

## Server-owned economy state. Clients will eventually receive this as a
## replicated snapshot; for now it also works in the offline sandbox.

const ORE := "ore"
var _balances: Dictionary = {}

func _ready() -> void:
	for team in TeamComponent.Team.values():
		# The opening garrison consumes the initial stock, so factions must mine
		# before they can sustain training or fund expansions.
		_balances[team] = 75

func get_ore(team: int) -> int:
	return int(_balances.get(team, 0))

func add_ore(team: int, amount: int) -> void:
	if amount <= 0:
		return
	_balances[team] = get_ore(team) + amount

func can_afford(team: int, amount: int) -> bool:
	return get_ore(team) >= maxi(amount, 0)

func spend_ore(team: int, amount: int) -> bool:
	if not can_afford(team, amount):
		return false
	_balances[team] = get_ore(team) - amount
	return true
