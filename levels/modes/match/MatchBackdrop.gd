extends Node2D

const EDGE_THICKNESS := 16.0
const BLEED := 2400.0
const NEBULA_LAYERS := 4
const NEBULA_ALPHA := 0.035
const BG_COLOR := Color(0.04, 0.04, 0.07, 1.0)

var arena: Vector2 = Vector2.ZERO
var stars: Array = []
var nebulae: Array = []
var asteroids: Array = []

var _edge_top: Texture2D
var _edge_bottom: Texture2D
var _edge_left: Texture2D
var _edge_right: Texture2D

func setup(layout: Dictionary):
	arena = layout["arena"]
	stars = layout["stars"]
	nebulae = layout.get("nebulae", [])
	asteroids = layout.get("asteroids", [])
	z_index = -5
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_edge_top = load("res://assets/space_edge_top.png")
	_edge_bottom = load("res://assets/space_edge_bottom.png")
	_edge_left = load("res://assets/space_edge_left.png")
	_edge_right = load("res://assets/space_edge_right.png")
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2(-BLEED, -BLEED), arena + Vector2(BLEED, BLEED) * 2.0), BG_COLOR)
	_draw_nebulae()
	for star in stars:
		draw_rect(Rect2(star["pos"], Vector2(star["sz"], star["sz"])), Color(1, 1, 1, star["a"]))
	for rock in asteroids:
		var shade: float = rock["shade"]
		var rock_size: float = rock["sz"]
		draw_rect(Rect2(rock["pos"], Vector2(rock_size, rock_size)), Color(shade, shade * 0.95, shade * 1.1, 1.0))
		draw_rect(Rect2(rock["pos"], Vector2(rock_size * 0.5, rock_size * 0.5)), Color(shade + 0.12, shade + 0.12, shade + 0.14, 1.0))
	_draw_edges()

func _draw_nebulae():
	for nebula in nebulae:
		var tint: Color = nebula["color"]
		for puff in nebula["puffs"]:
			for layer in NEBULA_LAYERS:
				var fraction: float = 1.0 - float(layer) / float(NEBULA_LAYERS)
				draw_circle(nebula["position"] + puff["offset"], float(puff["radius"]) * fraction, Color(tint.r, tint.g, tint.b, NEBULA_ALPHA))

func _draw_edges():
	if _edge_top == null or _edge_bottom == null or _edge_left == null or _edge_right == null:
		return
	draw_texture_rect(_edge_top, Rect2(0.0, 0.0, arena.x, EDGE_THICKNESS), true)
	draw_texture_rect(_edge_bottom, Rect2(0.0, arena.y - EDGE_THICKNESS, arena.x, EDGE_THICKNESS), true)
	draw_texture_rect(_edge_left, Rect2(0.0, 0.0, EDGE_THICKNESS, arena.y), true)
	draw_texture_rect(_edge_right, Rect2(arena.x - EDGE_THICKNESS, 0.0, EDGE_THICKNESS, arena.y), true)
