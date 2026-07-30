extends Control

const FONT_REG := preload("res://assets/fonts/Silkscreen-Regular.ttf")

const SPRITE_PATHS := {
	"purple":    "res://assets/sprites/spaceship/spaceship_purple.png",
	"blue":      "res://assets/sprites/spaceship/spaceship_blue.png",
	"gold":      "res://assets/sprites/spaceship/spaceship_gold.png",
	"green":     "res://assets/sprites/spaceship/spaceship_green.png",
	"red":       "res://assets/sprites/spaceship/spaceship_red.png",
	"explosion": "res://assets/sprites/effects/explosion.png",
	"freeze":    "res://assets/sprites/effects/freeze.png",
}

const SHIP_PX  := 34.0
const WILD_FOV := 140.0
const BLUE_FOV := 50.0
const C_LABEL  := Color(0.74, 0.76, 0.88, 1.0)
const C_PURPLE := Color(0.65, 0.45, 0.95, 1.0)
const C_PLANET := Color(0.32, 0.58, 0.48, 1.0)
const C_RING   := Color(0.55, 0.80, 0.68, 0.5)
const C_BEAM   := Color(0.55, 0.85, 1.0, 1.0)
const C_GOLD   := Color(1.0, 0.80, 0.25, 1.0)
const C_BLUE   := Color(0.45, 0.62, 1.0, 1.0)

var visual: String = "swarm"

var _time: float = 0.0
var _textures: Dictionary = {}
var _herd_last_cycle: float = 0.0
var _herd_second_seen: bool = false

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for key in SPRITE_PATHS:
		_textures[key] = load(SPRITE_PATHS[key])

func show_visual(id: String):
	visual = id
	_time = 0.0
	queue_redraw()

func _process(delta: float):
	_time += delta
	queue_redraw()

func _draw():
	match visual:
		"title":
			_draw_title()
		"pilots":
			_draw_pilots()
		"herd":
			_draw_herd()
		"cluster":
			_draw_cluster()
		"waves":
			_draw_waves()
		"laser":
			_draw_laser()
		"freeze":
			_draw_freeze()
		"score":
			_draw_score()
		_:
			_draw_swarm()

func _draw_title():
	var left := Vector2(size.x * 0.16, size.y * 0.44)
	var right := Vector2(size.x * 0.84, size.y * 0.44)
	_planet(left, 26.0)
	_planet(right, 26.0)
	for i in 6:
		var phase: float = float(i) * 1.05
		var x: float = size.x * 0.5 + sin(_time * 0.5 + phase) * size.x * 0.2
		var y: float = size.y * (0.24 + 0.42 * absf(sin(phase + _time * 0.4)))
		_ship("purple", Vector2(x, y), sin(_time * 0.7 + phase) * 0.7, SHIP_PX * 0.9)
	_ship("gold", left + Vector2(48.0, -34.0), 0.4, SHIP_PX)
	_ship("green", right - Vector2(48.0, 34.0), PI + 0.4, SHIP_PX)
	_caption("TWO PLANETS  ·  ONE SWARM  ·  THREE MINUTES")

func _draw_swarm():
	for i in 7:
		var phase: float = float(i) * 0.9
		var x: float = fposmod(_time * 26.0 + float(i) * 96.0, size.x + 70.0) - 35.0
		var y: float = size.y * (0.22 + 0.46 * absf(sin(phase + _time * 0.35)))
		_ship("purple", Vector2(x, y), sin(_time * 0.8 + phase) * 0.6, SHIP_PX)
	_caption("TWENTY FOUR PURPLE SHIPS DRIFT ON THEIR OWN")

func _draw_pilots():
	var bob: float = sin(_time * 2.2) * 6.0
	var left := Vector2(size.x * 0.20, size.y * 0.42)
	var right := Vector2(size.x * 0.80, size.y * 0.42)
	_planet(left, 26.0)
	_planet(right, 26.0)
	_ship("gold", left + Vector2(size.x * 0.14, bob), 0.0, SHIP_PX * 1.6)
	_ship("green", right - Vector2(size.x * 0.14, bob), PI, SHIP_PX * 1.6)
	_label("P1  ·  W A S D", Vector2(size.x * 0.27, size.y * 0.80), 12, C_GOLD)
	_label("P2  ·  ARROW KEYS", Vector2(size.x * 0.73, size.y * 0.80), 12, Color(0.35, 0.90, 0.45, 1.0))
	_caption("ONE PLANET EACH  ·  OR THE LEFT STICK WITH TWO CONTROLLERS")

func _draw_herd():
	var cycle: float = fposmod(_time, 7.0)
	var reach: float = size.x * 0.30
	var lane: float = size.y * 0.26

	var first := Vector2(size.x * 0.50, lane)
	var second: Vector2 = first + Vector2(reach * 0.72, 0.0).rotated(deg_to_rad(45.0))
	var first_facing: float = PI
	var second_facing: float = (first - second).angle()

	var sweep: float = deg_to_rad(150.0) * (1.0 - clampf((cycle - 3.4) / 1.4, 0.0, 1.0))
	second_facing += sweep

	var travel: float = clampf(cycle / 3.0, 0.0, 1.0)
	var pilot: Vector2 = Vector2(size.x * 0.04, lane).lerp(Vector2(size.x * 0.30, lane), travel)

	if cycle < _herd_last_cycle:
		_herd_second_seen = false
	_herd_last_cycle = cycle
	if _in_cone(second, second_facing, WILD_FOV, reach, first):
		_herd_second_seen = true

	var first_blue: bool = _in_cone(first, first_facing, WILD_FOV, reach, pilot)
	var second_blue: bool = _herd_second_seen

	_cone(first, first_facing, reach, BLUE_FOV if first_blue else WILD_FOV, _cone_tint(first_blue))
	_cone(second, second_facing, reach, BLUE_FOV if second_blue else WILD_FOV, _cone_tint(second_blue))
	_ship("gold", pilot, 0.0, SHIP_PX * 1.2)
	_ship("blue" if first_blue else "purple", first, first_facing, SHIP_PX * 1.2)
	_ship("blue" if second_blue else "purple", second, second_facing, SHIP_PX * 1.2)
	_caption("A PURPLE SHIP TURNS BLUE THE MOMENT IT SEES ANY OTHER SHIP")

func _in_cone(at: Vector2, angle: float, fov_degrees: float, radius: float, point: Vector2) -> bool:
	var to: Vector2 = point - at
	if to.length() > radius:
		return false
	return absf(angle_difference(angle, to.angle())) <= deg_to_rad(fov_degrees) * 0.5

func _cone_tint(is_blue: bool) -> Color:
	if is_blue:
		return Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.16)
	return Color(C_PURPLE.r, C_PURPLE.g, C_PURPLE.b, 0.14)

func _draw_cluster():
	var center := Vector2(size.x * 0.5, size.y * 0.42)
	_planet(center, 24.0)
	for i in 5:
		var angle: float = _time * 0.9 + TAU * float(i) / 5.0
		var radius: float = 66.0 + sin(_time * 1.6 + float(i)) * 8.0
		var pos: Vector2 = center + Vector2(radius, 0.0).rotated(angle)
		_cone(pos, angle + PI * 0.5, 46.0, BLUE_FOV, Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.12))
		_ship("blue", pos, angle + PI * 0.5, SHIP_PX)
	_caption("BLUE SHIPS CLUSTER AND HOLD POSITION")

func _draw_waves():
	var planet := Vector2(size.x * 0.22, size.y * 0.44)
	_planet(planet, 24.0)
	for i in 3:
		var cycle: float = fposmod(_time * 0.45 + float(i) * 0.34, 1.0)
		var start := Vector2(size.x * 0.96, size.y * (0.18 + 0.26 * float(i)))
		var pos: Vector2 = start.lerp(planet, cycle)
		if cycle > 0.9:
			_effect("explosion", pos, 56.0, (1.0 - cycle) / 0.1, 0.0)
		else:
			_ship("red", pos, (planet - start).angle(), SHIP_PX)
	_caption("FOURTEEN EVADERS, SEVEN AT EACH PLANET")

func _draw_laser():
	var cycle: float = fposmod(_time, 3.0)
	var defender := Vector2(size.x * 0.30, size.y * 0.46)
	var evader := Vector2(size.x * 0.70, size.y * 0.38)
	var aim: float = (evader - defender).angle()
	if cycle < 1.6:
		_cone(defender, aim, size.x * 0.34, BLUE_FOV, Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.16))
		_ship("blue", defender, aim, SHIP_PX * 1.3)
		_ship("red", evader, PI, SHIP_PX * 1.3)
	elif cycle < 2.0:
		var fade: float = 1.0 - (cycle - 1.6) / 0.4
		draw_line(defender, evader, Color(C_BEAM.r, C_BEAM.g, C_BEAM.b, 0.4 * fade), 8.0, true)
		draw_line(defender, evader, Color(1.0, 1.0, 1.0, fade), 2.0, true)
		_ship("blue", defender, aim, SHIP_PX * 1.3)
		_ship("red", evader, PI, SHIP_PX * 1.3)
	else:
		var burn: float = 1.0 - (cycle - 2.0)
		_effect("explosion", defender, 60.0, burn, 0.0)
		_effect("explosion", evader, 60.0, burn, 1.2)
	_caption("ONE BLUE TRADES ITSELF FOR ONE RED")

func _draw_freeze():
	var pos := Vector2(size.x * 0.5, size.y * 0.42)
	_ship("green", pos, 0.0, SHIP_PX * 1.6)
	_effect("freeze", pos, SHIP_PX * 2.4, 0.7 + sin(_time * 4.0) * 0.3, _time * 1.4)
	_label("2 CHARGES  ·  15 SECONDS  ·  Q  AND  /", Vector2(size.x * 0.5, size.y * 0.82), 12, C_BEAM)

func _draw_score():
	var left := Vector2(size.x * 0.3, size.y * 0.40)
	var right := Vector2(size.x * 0.7, size.y * 0.40)
	_planet(left, 24.0)
	_planet(right, 24.0)
	_label("P1  ·  2 THROUGH", Vector2(left.x, size.y * 0.74), 12, C_GOLD)
	_label("P2  ·  5 THROUGH", Vector2(right.x, size.y * 0.74), 12, Color(0.35, 0.90, 0.45, 1.0))
	_caption("FEWEST EVADERS ON YOUR PLANET WINS")

func _ship(key: String, at: Vector2, angle: float, px: float, alpha: float = 1.0):
	_effect(key, at, px, alpha, angle + PI * 0.5)

func _effect(key: String, at: Vector2, px: float, alpha: float, angle: float):
	var tex: Texture2D = _textures.get(key)
	if tex == null:
		return
	draw_set_transform(at, angle, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-px * 0.5, -px * 0.5, px, px), false, Color(1, 1, 1, clampf(alpha, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _cone(at: Vector2, angle: float, radius: float, fov_degrees: float, color: Color):
	var points := PackedVector2Array([at])
	var fov: float = deg_to_rad(fov_degrees)
	for i in 15:
		var a: float = angle - fov * 0.5 + fov * float(i) / 14.0
		points.append(at + Vector2(radius, 0.0).rotated(a))
	draw_colored_polygon(points, color)

func _planet(at: Vector2, radius: float):
	draw_circle(at, radius, C_PLANET)
	draw_arc(at, radius + 5.0, 0.0, TAU, 42, C_RING, 1.5, true)

func _label(text: String, at: Vector2, font_size: int = 11, color: Color = C_LABEL):
	draw_string(FONT_REG, Vector2(at.x - size.x * 0.5, at.y), text,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)

func _caption(text: String):
	_label(text, Vector2(size.x * 0.5, size.y - 12.0), 10, C_LABEL)
