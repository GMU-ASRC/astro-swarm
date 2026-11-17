extends Camera2D

const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")

const ZOOM_MIN := 0.35
const ZOOM_MAX := 1.6
const ZOOM_START := 0.6
const FOLLOW_RATE := 6.0

var home_center: Vector2 = Vector2.ZERO
var arena: Vector2 = Vector2.ZERO
var can_pan: bool = true
var follow_scout: bool = true
var scout: Node2D = null

var _panning: bool = false

func _ready():
	zoom = Vector2(ZOOM_START, ZOOM_START)
	position = home_center

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.1)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(0.9)
			return true
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed and can_pan
			return true
	elif event is InputEventMouseMotion and _panning:
		follow_scout = false
		position -= event.relative / zoom.x
		_clamp_position()
		return true
	return false

func toggle_follow():
	follow_scout = not follow_scout

func center_on_home():
	follow_scout = false
	position = home_center
	_clamp_position()

func is_following() -> bool:
	return follow_scout and is_instance_valid(scout)

func _process(delta: float):
	if is_following():
		position = position.lerp(scout.global_position, clampf(delta * FOLLOW_RATE, 0.0, 1.0))
	elif not can_pan:
		position = position.lerp(home_center, clampf(delta * FOLLOW_RATE, 0.0, 1.0))
	_clamp_position()

func _zoom_by(factor: float):
	var level: float = clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(level, level)
	_clamp_position()

func look_at_point(world_point: Vector2):
	if not can_pan:
		return
	follow_scout = false
	position = world_point
	_clamp_position()

func _clamp_position():
	if not is_following():
		var from_home: Vector2 = position - home_center
		if from_home.length() > MATCH_CONFIG.PAN_LIMIT:
			position = home_center + from_home.normalized() * MATCH_CONFIG.PAN_LIMIT
	var half: Vector2 = get_viewport_rect().size * 0.5 / zoom
	position.x = _clamp_axis(position.x, half.x, arena.x)
	position.y = _clamp_axis(position.y, half.y, arena.y)

func _clamp_axis(value: float, half_view: float, arena_length: float) -> float:
	if half_view * 2.0 >= arena_length:
		return arena_length * 0.5
	return clampf(value, half_view, arena_length - half_view)

func screen_to_world(screen_point: Vector2) -> Vector2:
	return get_screen_center_position() + (screen_point - get_viewport_rect().size * 0.5) / zoom.x
