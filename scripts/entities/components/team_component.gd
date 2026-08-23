class_name TeamComponent
extends EntityComponent

enum Team {
	PLAYER,
	ENEMY,
	ALLY,
	NEUTRAL,
}

@export var team: Team = Team.PLAYER

func is_player_controlled() -> bool:
	return team == Team.PLAYER
