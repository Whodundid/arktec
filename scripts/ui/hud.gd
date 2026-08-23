extends Control

var title_font := ThemeDB.fallback_font
var small_font := ThemeDB.fallback_font

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var panel := Rect2(28, 28, 330, 132)
	draw_style_box(_panel(Color("101b25d9"), Color("4d6f78")), panel)
	draw_string(title_font, Vector2(48, 66), "ARTIFACT RUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("f4d58b"))
	draw_string(small_font, Vector2(48, 94), "VERTICAL SLICE // FIELD BOOTSTRAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9cb5b5"))
	draw_string(small_font, Vector2(48, 128), "DAY 01    10:42    OUTPOST SECURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dce5df"))

	draw_string(small_font, Vector2(48, size.y - 60), "WASD / ARROWS   MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("dce5df"))
	draw_string(small_font, Vector2(size.x - 300, size.y - 60), "EXCAVATION SITE   ◈", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d5a7df"))

func _panel(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
