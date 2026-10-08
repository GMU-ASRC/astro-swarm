extends Control

const BAR_COLOR := Color(0.93, 0.94, 1.0, 0.85)
const NARROW := 2.0
const WIDE := 4.0

var code: String = ""

func _ready():
	custom_minimum_size = Vector2(220, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw():
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(code)
	var x := 0.0
	var draw_bar := true
	while x < size.x:
		var width: float = WIDE if rng.randf() < 0.35 else NARROW
		if draw_bar:
			draw_rect(Rect2(x, 0.0, width, size.y), BAR_COLOR)
		x += width
		draw_bar = not draw_bar
