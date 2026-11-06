extends Node2D

const TERRAN := preload("res://entities/planet/PlanetTerran.tscn")
const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")
const BAR_WIDTH := 160.0
const BAR_HEIGHT := 8.0

var slot: int = 0
var color: Color = Color.WHITE
var hp: float = MATCH_CONFIG.PLANET_MAX_HP
var show_ring: bool = false
var radius: float = MATCH_CONFIG.PLANET_RADIUS

func setup(player_slot: int, center: Vector2, planet_seed: int):
	slot = player_slot
	position = center
	color = MATCH_CONFIG.PLAYER_COLORS[player_slot]
	var planet := TERRAN.instantiate() as Control
	add_child(planet)
	planet.generate(planet_seed, MATCH_CONFIG.PLANET_PIXELS)
	var display_scale: float = MATCH_CONFIG.PLANET_DISPLAY / MATCH_CONFIG.PLANET_PIXELS
	planet.scale = Vector2(display_scale, display_scale)
	planet.position = -Vector2(radius, radius)
	_ignore_mouse(planet)
	z_index = 2

func can_deploy_at(world_point: Vector2) -> bool:
	var distance: float = world_point.distance_to(position)
	return distance >= MATCH_CONFIG.RING_INNER and distance <= MATCH_CONFIG.RING_OUTER

func _process(_delta: float):
	queue_redraw()

func _draw():
	if show_ring:
		draw_circle(Vector2.ZERO, MATCH_CONFIG.RING_OUTER, Color(color.r, color.g, color.b, 0.05))
		_draw_dashed_circle(MATCH_CONFIG.RING_OUTER, Color(color.r, color.g, color.b, 0.4), 2.0)
		_draw_dashed_circle(MATCH_CONFIG.RING_INNER, Color(0.6, 0.62, 0.74, 0.25), 1.0)
	var bar_top: float = radius + 18.0
	var fraction: float = clampf(hp / MATCH_CONFIG.PLANET_MAX_HP, 0.0, 1.0)
	var bar_color: Color = Color(0.40, 0.85, 0.45, 1.0) if fraction > 0.35 else Color(1.0, 0.42, 0.32, 1.0)
	draw_rect(Rect2(-BAR_WIDTH * 0.5 - 2.0, bar_top - 2.0, BAR_WIDTH + 4.0, BAR_HEIGHT + 4.0), Color(0.05, 0.05, 0.08, 0.9), true)
	draw_rect(Rect2(-BAR_WIDTH * 0.5, bar_top, BAR_WIDTH * fraction, BAR_HEIGHT), bar_color, true)
	draw_rect(Rect2(-BAR_WIDTH * 0.5 - 2.0, bar_top - 2.0, BAR_WIDTH + 4.0, BAR_HEIGHT + 4.0), color, false, 2.0)

func _draw_dashed_circle(circle_radius: float, line_color: Color, width: float):
	var segments := 72
	for i in segments:
		if i % 3 == 0:
			continue
		var start_angle: float = float(i) / float(segments) * TAU
		var end_angle: float = float(i + 1) / float(segments) * TAU
		draw_line(Vector2(circle_radius, 0.0).rotated(start_angle), Vector2(circle_radius, 0.0).rotated(end_angle), line_color, width, true)

func _ignore_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
