extends Control

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(20, 20)
	resized.connect(queue_redraw)

func _draw():
	var r: float = min(size.x, size.y) * 0.5
	if r <= 0.0:
		return
	var c: Vector2 = size * 0.5
	draw_circle(c, r, Color(0.45, 0.32, 0.05, 1))
	draw_circle(c, r - 2.0, Color(1.0, 0.78, 0.2, 1))
	draw_circle(c, r - 4.0, Color(1.0, 0.88, 0.4, 1))
	draw_circle(c - Vector2(r * 0.3, r * 0.3), r * 0.18, Color(1.0, 0.97, 0.82, 1))
