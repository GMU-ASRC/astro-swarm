extends Node2D

const LASER_PATH := "res://assets/sprites/effects/laser.svg"

const WALL_MARGIN := 8.0
const GLOW_WIDTH  := 12.0
const CORNER_SIZE := 9.0
const PULSE_RATE  := 5.0
const PULSE_DEPTH := 0.18
const DASH_LENGTH := 48.0

const BEAM_COLOR   := Color(0.55, 0.90, 1.0, 1.0)
const IDLE_COLOR   := Color(0.55, 0.90, 1.0, 0.20)

var active: bool = false
var corners: PackedVector2Array = PackedVector2Array()

var _texture: Texture2D
var _pulse: float = 0.0

func _ready():
	z_index = 4
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_texture = load(LASER_PATH)

func _process(delta: float):
	_pulse += delta * PULSE_RATE
	queue_redraw()

func update_box(points: Array, is_active: bool):
	active = is_active and points.size() >= 3
	corners = _sort_around_centroid(points)

func contains(point: Vector2) -> bool:
	if not active or corners.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(point, corners)

func confine(ship: Node2D):
	_hold_on_side(ship, true)

func repel(ship: Node2D):
	_hold_on_side(ship, false)

func _hold_on_side(ship: Node2D, keep_inside: bool):
	if not active or corners.size() < 3:
		return
	var position_now: Vector2 = ship.global_position
	var wall: Dictionary = _nearest_wall(position_now)
	if wall.is_empty():
		return
	var inside: bool = Geometry2D.is_point_in_polygon(position_now, corners)
	if inside == keep_inside and position_now.distance_to(wall["point"]) >= WALL_MARGIN:
		return
	var normal: Vector2 = wall["normal"]
	var push: Vector2 = normal if keep_inside else -normal
	ship.global_position = wall["point"] + push * WALL_MARGIN
	var heading: Vector2 = Vector2.RIGHT.rotated(ship.rotation)
	if heading.dot(push) < 0.0:
		ship.rotation = heading.bounce(normal).angle()

func centroid() -> Vector2:
	if corners.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for point in corners:
		total += point
	return total / float(corners.size())

func _sort_around_centroid(points: Array) -> PackedVector2Array:
	var middle := Vector2.ZERO
	for point in points:
		middle += point
	if not points.is_empty():
		middle /= float(points.size())
	var ordered: Array = points.duplicate()
	ordered.sort_custom(func(a, b): return (a - middle).angle() < (b - middle).angle())
	var out := PackedVector2Array()
	for point in ordered:
		out.append(point)
	return out

func _nearest_wall(point: Vector2) -> Dictionary:
	var middle: Vector2 = centroid()
	var best: Dictionary = {}
	var best_distance: float = INF
	for i in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		if a.distance_to(b) < 0.001:
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, b)
		var distance: float = point.distance_to(closest)
		if distance >= best_distance:
			continue
		var normal: Vector2 = (b - a).orthogonal().normalized()
		if normal.dot(middle - (a + b) * 0.5) < 0.0:
			normal = -normal
		best_distance = distance
		best = {"point": closest, "normal": normal}
	return best

func _draw():
	if corners.size() < 3:
		return
	if not active:
		_draw_idle_outline()
		return
	var brightness: float = 1.0 - PULSE_DEPTH + sin(_pulse) * PULSE_DEPTH
	for i in corners.size():
		_draw_wall(corners[i], corners[(i + 1) % corners.size()], brightness)
	for corner in corners:
		draw_circle(corner, CORNER_SIZE, Color(1.0, 1.0, 1.0, 0.85 * brightness))
		draw_circle(corner, CORNER_SIZE * 1.8, Color(BEAM_COLOR.r, BEAM_COLOR.g, BEAM_COLOR.b, 0.25))

func _draw_wall(from_point: Vector2, to_point: Vector2, brightness: float):
	var span: Vector2 = to_point - from_point
	var length: float = span.length()
	if length < 1.0:
		return
	draw_line(from_point, to_point, Color(BEAM_COLOR.r, BEAM_COLOR.g, BEAM_COLOR.b, 0.22 * brightness), GLOW_WIDTH, true)
	if _texture == null:
		draw_line(from_point, to_point, Color(BEAM_COLOR.r, BEAM_COLOR.g, BEAM_COLOR.b, brightness), 3.0, true)
		return
	var thickness: float = float(_texture.get_height())
	draw_set_transform(from_point, span.angle(), Vector2.ONE)
	draw_texture_rect(_texture, Rect2(0.0, -thickness * 0.5, length, thickness), true, Color(1.0, 1.0, 1.0, brightness))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_idle_outline():
	for i in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		var steps: int = maxi(2, int(a.distance_to(b) / DASH_LENGTH))
		for step in steps:
			if step % 2 == 1:
				continue
			var t0: float = float(step) / float(steps)
			var t1: float = float(step + 1) / float(steps)
			draw_line(a.lerp(b, t0), a.lerp(b, t1), IDLE_COLOR, 2.0, true)
