class_name CharacterEntity
extends Entity

## Minimal world entity used to prove that characters can exist on the map.
## Rendering is intentionally procedural until the visual direction is settled.

@export var display_name := "Mercenary"
@export var body_color := Color("d2a85a")
static var show_nameplates := true

func _ready() -> void:
	super._ready()
	queue_redraw()

func _draw() -> void:
	# Shadow, body, facing marker, and a tiny nameplate are enough for now.
	draw_selection_ring(20.0, 3.0)
	var team_color := _team_color()
	draw_filled_ellipse(Vector2(0, 10), Vector2(14, 6), Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(Vector2.ZERO, 12.0, body_color)
	draw_circle(Vector2.ZERO, 12.0, team_color.lightened(0.25), false, 2.0)
	draw_line(facing_direction * 5.0, facing_direction * 17.0, Color("f4d58b"), 3.0)
	draw_circle(facing_direction * 18.0, 3.0, Color("f4d58b"))
	_draw_carried_ore_indicator()
	if show_nameplates:
		draw_string(ThemeDB.fallback_font, Vector2(-38, 32), display_name, HORIZONTAL_ALIGNMENT_CENTER, 76, 12, Color("dce5df"))

func _draw_carried_ore_indicator() -> void:
	var alert := get_component(AlertComponent) as AlertComponent
	var harvest := get_component(HarvestComponent) as HarvestComponent
	if alert == null or alert.role != AlertComponent.Role.BUILDER or harvest == null or harvest.carried_ore <= 0.0:
		return
	# A gold pouch is deliberately offset from the unit body so it remains
	# readable even when several builders are standing close together.
	var pouch_center := Vector2(10.0, -10.0)
	draw_circle(pouch_center, 6.0, Color("17242b"))
	draw_circle(pouch_center, 4.5, Color("d9a83f"))
	draw_circle(pouch_center + Vector2(-1.5, -1.0), 1.3, Color("fff0a6"))
	var amount := str(roundi(harvest.carried_ore))
	draw_string(ThemeDB.fallback_font, Vector2(14, -13), amount, HORIZONTAL_ALIGNMENT_LEFT, 24, 10, Color("ffe39a"))

func _team_color() -> Color:
	var team := get_component(TeamComponent) as TeamComponent
	if team == null:
		return Color("d8dde2")
	match team.team:
		TeamComponent.Team.ENEMY:
			return Color("e45b61")
		TeamComponent.Team.ALLY:
			return Color("63d8e2")
		TeamComponent.Team.PLAYER:
			return Color("5ee27a")
		_:
			return Color("d8dde2")

func draw_filled_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
