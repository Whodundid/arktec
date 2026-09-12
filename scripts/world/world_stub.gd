extends Node2D

## World landmarks layered over the procedural terrain map.
## Terrain itself lives in TerrainMap; this node is reserved for mission props.

@export var draw_mission_mockup := true

func _ready() -> void:
	RuntimeLogger.debug("World landmarks loading")
	queue_redraw()

func _draw() -> void:
	if not draw_mission_mockup:
		return
	var center := Vector2.ZERO

	var outpost := Rect2(center + Vector2(-112, -72), Vector2(224, 144))
	draw_rect(outpost, Color("182b38"), true)
	draw_rect(outpost, Color("6b9a9d"), false, 3.0)
	draw_circle(center, 22.0, Color("d2a85a"))
	draw_circle(center, 9.0, Color("f4d58b"))

	var rail_start := center + Vector2(112, 0)
	var rail_end := center + Vector2(440, 0)
	draw_line(rail_start, rail_end, Color("a58e71"), 8.0)
	draw_line(rail_start, rail_end, Color("e0c895"), 2.0)

	for marker in [center + Vector2(230, -34), center + Vector2(230, 34), center + Vector2(390, -34), center + Vector2(390, 34)]:
		draw_line(marker - Vector2(0, 10), marker + Vector2(0, 10), Color("a58e71"), 3.0)

	var artifact_site := center + Vector2(520, 0)
	draw_circle(artifact_site, 30.0, Color("7e4f8f"))
	draw_circle(artifact_site, 18.0, Color("c181d2"))
	draw_line(artifact_site - Vector2(0, 42), artifact_site + Vector2(0, 42), Color("d5a7df"), 2.0)
	draw_line(artifact_site - Vector2(42, 0), artifact_site + Vector2(42, 0), Color("d5a7df"), 2.0)
