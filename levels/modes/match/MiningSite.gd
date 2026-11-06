extends Node2D

const MOON := preload("res://entities/planet/PlanetMoon.tscn")
const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")
const DUST_ICON_PATH := "res://assets/sprites/match/astrodust.svg"
const MOON_PIXELS := 48.0
const ICON_SIZE := 22.0

var site_index: int = 0
var radius: float = 60.0
var dust: float = MATCH_CONFIG.SITE_MAX_DUST
var max_dust: float = MATCH_CONFIG.SITE_MAX_DUST
var regenerates: bool = true

var _dust_icon: Texture2D

func setup(index: int, site: Dictionary):
	site_index = index
	radius = float(site["radius"])
	position = site["position"]
	var moon := MOON.instantiate() as Control
	add_child(moon)
	moon.generate(int(site["seed"]), MOON_PIXELS)
	var display_scale: float = radius * 2.0 / MOON_PIXELS
	moon.scale = Vector2(display_scale, display_scale)
	moon.position = -Vector2(radius, radius)
	_ignore_mouse(moon)
	z_index = 2
	_dust_icon = load(DUST_ICON_PATH)

func take(amount: float) -> float:
	var taken: float = clampf(amount, 0.0, dust)
	dust -= taken
	return taken

func has_dust() -> bool:
	return dust >= 1.0

func _process(delta: float):
	if regenerates and dust < max_dust:
		dust = minf(max_dust, dust + MATCH_CONFIG.SITE_REGEN * delta)
	queue_redraw()

func _draw():
	var fraction: float = clampf(dust / max_dust, 0.0, 1.0)
	var ring_radius: float = radius + 10.0
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(0.2, 0.18, 0.3, 0.6), 4.0)
	if fraction > 0.0:
		draw_arc(Vector2.ZERO, ring_radius, -PI / 2.0, -PI / 2.0 + TAU * fraction, 48, MATCH_CONFIG.DUST_COLOR, 4.0)
	if _dust_icon != null:
		var icon_rect := Rect2(Vector2(-ICON_SIZE * 0.5, -ring_radius - ICON_SIZE - 6.0), Vector2(ICON_SIZE, ICON_SIZE))
		draw_texture_rect(_dust_icon, icon_rect, false)

func _ignore_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
