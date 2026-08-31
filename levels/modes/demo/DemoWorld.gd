extends Node2D

const EDGE_THICKNESS := 16.0

var arena: Vector2 = Vector2(1920.0, 1080.0)
var background: Color = Color(0.04, 0.04, 0.07, 1.0)
var stars: Array = []
var planet_center: Vector2 = Vector2.ZERO
var orbit_radius: float = 0.0
var orbit_color: Color = Color(0.45, 0.62, 1.0, 0.28)
var edge_top: Texture2D
var edge_bottom: Texture2D
var edge_left: Texture2D
var edge_right: Texture2D

func _ready():
	z_index = -10
	queue_redraw()

func _draw():
	var bleed := Vector2(2400.0, 2400.0)
	draw_rect(Rect2(-bleed, arena + bleed * 2.0), background)
	for star in stars:
		draw_rect(Rect2(star["pos"], Vector2(star["sz"], star["sz"])), Color(1, 1, 1, star["a"]))
	if orbit_radius > 0.0:
		_draw_dashed_circle(planet_center, orbit_radius, orbit_color, 2.0)
	_draw_edges()

func _draw_edges():
	if edge_top == null or edge_bottom == null or edge_left == null or edge_right == null:
		return
	var t: float = EDGE_THICKNESS
	draw_texture_rect(edge_top, Rect2(0.0, 0.0, arena.x, t), true)
	draw_texture_rect(edge_bottom, Rect2(0.0, arena.y - t, arena.x, t), true)
	draw_texture_rect(edge_left, Rect2(0.0, 0.0, t, arena.y), true)
	draw_texture_rect(edge_right, Rect2(arena.x - t, 0.0, t, arena.y), true)

func _draw_dashed_circle(center: Vector2, radius: float, color: Color, width: float):
	var segments := 72
	for i in segments:
		if i % 3 == 0:
			continue
		var a0: float = float(i) / float(segments) * TAU
		var a1: float = float(i + 1) / float(segments) * TAU
		draw_line(center + Vector2(radius, 0.0).rotated(a0),
			center + Vector2(radius, 0.0).rotated(a1), color, width, true)
