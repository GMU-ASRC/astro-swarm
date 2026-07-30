extends Node2D

const EDGE_THICKNESS := 16.0

var arena: Vector2 = Vector2(2400.0, 1350.0)
var background: Color = Color(0.04, 0.04, 0.07, 1.0)
var stars: Array = []
var planet_centers: Array = []
var planet_colors: Array = []
var base_radius: float = 300.0
var edge_top: Texture2D
var edge_bottom: Texture2D
var edge_left: Texture2D
var edge_right: Texture2D

func _ready():
	queue_redraw()

func _draw():
	var bleed := Vector2(2400.0, 2400.0)
	draw_rect(Rect2(-bleed, arena + bleed * 2.0), background)
	for star in stars:
		draw_rect(Rect2(star["pos"], Vector2(star["sz"], star["sz"])), Color(1, 1, 1, star["a"]))
	for i in planet_centers.size():
		var col: Color = planet_colors[i]
		_draw_dashed_circle(planet_centers[i], base_radius, Color(col.r, col.g, col.b, 0.35), 2.0)
	draw_line(Vector2(arena.x * 0.5, 0.0), Vector2(arena.x * 0.5, arena.y), Color(1, 1, 1, 0.05), 2.0)
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
	var segments := 60
	for i in segments:
		if i % 3 == 0:
			continue
		var a0: float = float(i) / float(segments) * TAU
		var a1: float = float(i + 1) / float(segments) * TAU
		draw_line(center + Vector2(radius, 0.0).rotated(a0),
			center + Vector2(radius, 0.0).rotated(a1), color, width, true)
