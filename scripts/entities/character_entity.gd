class_name CharacterEntity
extends Entity

## Minimal world entity used to prove that characters can exist on the map.
## Rendering is intentionally procedural until the visual direction is settled.

@export var display_name := "Mercenary"
@export var body_color := Color("d2a85a")

func _ready() -> void:
	super._ready()
	queue_redraw()

func _draw() -> void:
	# Shadow, body, facing marker, and a tiny nameplate are enough for now.
	draw_selection_ring(20.0, 3.0)
	draw_filled_ellipse(Vector2(0, 10), Vector2(14, 6), Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(Vector2.ZERO, 12.0, body_color)
	draw_circle(Vector2.ZERO, 12.0, Color("f4d58b"), false, 2.0)
	draw_line(facing_direction * 5.0, facing_direction * 17.0, Color("f4d58b"), 3.0)
	draw_circle(facing_direction * 18.0, 3.0, Color("f4d58b"))
	draw_string(ThemeDB.fallback_font, Vector2(-38, 32), display_name, HORIZONTAL_ALIGNMENT_CENTER, 76, 12, Color("dce5df"))

func draw_filled_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
