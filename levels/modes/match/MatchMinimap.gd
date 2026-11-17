extends Control

const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")

const MAP_WIDTH := 240.0
const C_BACKGROUND := Color(0.05, 0.05, 0.09, 0.9)
const C_BORDER := Color(0.318, 0.306, 0.463, 1.0)
const C_VIEW := Color(1.0, 1.0, 1.0, 0.7)
const C_LIMIT := Color(1.0, 1.0, 1.0, 0.15)
const SHIP_DOT := 3.0

var arena: Vector2 = Vector2(1.0, 1.0)
var homes: Array = []
var sites: Array = []
var authority
var camera: Camera2D
var local_slot: int = 0
var shows_pan_limit: bool = true

func setup(arena_size: Vector2, home_bases: Array, mining_sites: Array, match_authority, match_camera: Camera2D, slot: int, pan_limited: bool):
	arena = arena_size
	homes = home_bases
	sites = mining_sites
	authority = match_authority
	camera = match_camera
	local_slot = slot
	shows_pan_limit = pan_limited
	custom_minimum_size = Vector2(MAP_WIDTH, MAP_WIDTH * arena.y / arena.x)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float):
	queue_redraw()

func _map_scale() -> float:
	return size.x / arena.x

func _to_map(world_point: Vector2) -> Vector2:
	return world_point * _map_scale()

func _gui_input(event: InputEvent):
	if camera == null:
		return
	var pressed_left: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var dragging_left: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if pressed_left or dragging_left:
		camera.look_at_point(event.position / _map_scale())
		accept_event()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), C_BACKGROUND)
	for site in sites:
		if is_instance_valid(site) and site.visible:
			var fraction: float = clampf(site.dust / site.max_dust, 0.0, 1.0)
			var dust_color: Color = MATCH_CONFIG.DUST_COLOR
			draw_circle(_to_map(site.position), maxf(2.0, site.radius * _map_scale()), Color(dust_color.r, dust_color.g, dust_color.b, 0.35 + 0.65 * fraction))
	for home in homes:
		if home.visible:
			draw_circle(_to_map(home.position), maxf(4.0, home.radius * _map_scale()), home.color)
	if shows_pan_limit and not homes.is_empty():
		draw_arc(_to_map(homes[local_slot].position), MATCH_CONFIG.PAN_LIMIT * _map_scale(), 0.0, TAU, 40, C_LIMIT, 1.0)
	if authority != null:
		for ship in authority.ships.values():
			if is_instance_valid(ship) and ship.visible:
				var dot: float = SHIP_DOT + (1.0 if ship.owner_slot == local_slot else 0.0)
				draw_rect(Rect2(_to_map(ship.global_position) - Vector2(dot, dot) * 0.5, Vector2(dot, dot)), MATCH_CONFIG.PLAYER_COLORS[ship.owner_slot])
	if camera != null:
		var view_size: Vector2 = camera.get_viewport_rect().size / camera.zoom
		var view_rect := Rect2(_to_map(camera.get_screen_center_position() - view_size * 0.5), view_size * _map_scale())
		draw_rect(view_rect, C_VIEW, false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), C_BORDER, false, 2.0)
