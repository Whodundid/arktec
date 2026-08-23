class_name CharacterEntity
extends Entity

## Minimal world entity used to prove that characters can exist on the map.
## Rendering is intentionally procedural until the visual direction is settled.

@export var display_name := "Mercenary"
@export var body_color := Color("d2a85a")
static var show_nameplates := true
static var show_team_markers := true

func _ready() -> void:
	super._ready()
	queue_redraw()

func _draw() -> void:
	# Shadow, body, facing marker, and a tiny nameplate are enough for now.
	draw_selection_ring(20.0, 3.0)
	var team_color := _team_color()
	if show_team_markers:
		# The ring and pennant stay faction-colored while the body color can vary
		# by role, making team identity readable even when units overlap.
		draw_arc(Vector2.ZERO, 15.5, 0.0, TAU, 32, team_color, 3.0)
		draw_rect(Rect2(-5.0, -22.0, 10.0, 4.0), team_color, true)
	draw_filled_ellipse(Vector2(0, 10), Vector2(14, 6), Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(Vector2.ZERO, 12.0, body_color)
	draw_circle(Vector2.ZERO, 12.0, team_color.lightened(0.25), false, 2.0)
	draw_line(facing_direction * 5.0, facing_direction * 17.0, Color("f4d58b"), 3.0)
	draw_circle(facing_direction * 18.0, 3.0, Color("f4d58b"))
	if show_nameplates:
		draw_string(ThemeDB.fallback_font, Vector2(-38, 32), display_name, HORIZONTAL_ALIGNMENT_CENTER, 76, 12, Color("dce5df"))

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
