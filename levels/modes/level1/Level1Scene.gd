extends "res://levels/modes/FARPBase.gd"

const EVADER_COUNT := 10
const SPAWN_INTERVAL := 3.0

static var persisted_placements: Array = []

var _radial: CanvasLayer
var _radial_target: Node2D = null
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

func _level_id() -> String:
	return "farp1"

func _level_title() -> String:
	return "LEVEL 1 - PLACE YOUR DEFENDERS"

func _level_subtitle() -> String:
	return "Drag inside the blue ring to place a defender and aim it. Place %d to %d. Right-click a defender to remove it. Program them in WORKSPACE, then LAUNCH." % [MIN_DEFENDERS, MAX_DEFENDERS]

func _shows_hint_text() -> bool:
	return false

func _tutorial_final_hint() -> String:
	return "CLICK TO OPEN THE WORKSPACE"

func _after_tutorial():
	_open_workspace()

func _setup_level():
	_use_evader_stream(EVADER_COUNT, SPAWN_INTERVAL, 0.0)
	_radial = RADIAL_MENU.instantiate()
	add_child(_radial)
	_radial.PANEL_BG     = C_PANEL
	_radial.PANEL_BORDER = C_BORDER
	_radial.SLICE_BG     = Color(0.09, 0.085, 0.145, 1.0)
	_radial.SEP_COLOR    = C_BORDER
	_radial.TEXT_DARK    = C_TEXT
	_radial.TEXT_MUTED   = C_DIM
	_radial.label_font   = FONT_REG
	_radial.action_selected.connect(_on_radial_action)
	_radial.menu_closed.connect(func(): _radial_target = null)

	_add_top_button("CLEAR", _clear_defenders)
	_launch_btn.text = _launch_label()
	_restore_placements()

func _restart_level():
	for placement in persisted_placements:
		var p: Dictionary = {"pos": placement.pos, "rot": placement.rot}
		_placements.append(p)
		_spawn_defender(p, PlayerData.ship_blocks)
	_launch_btn.text = _launch_label()
	_phase_label.text = _level_title()

func _launch_label() -> String:
	return "LAUNCH EVADERS (S) >"

func _restore_placements():
	var source: Array = persisted_placements if not persisted_placements.is_empty() else _placements_from_disk()
	for placement in source:
		if not _can_place(placement.pos):
			continue
		var p: Dictionary = {"pos": placement.pos, "rot": placement.rot}
		_placements.append(p)
		_spawn_defender(p, PlayerData.ship_blocks)

func _placements_from_disk() -> Array:
	var out: Array = []
	for p in PlayerData.get_farp_placements():
		out.append({"pos": Vector2(p.get("x", 0.0), p.get("y", 0.0)), "rot": p.get("rot", 0.0)})
	return out

func _save_placements_to_disk():
	PlayerData.set_farp_placements(_placements_payload())

func _open_workspace():
	persisted_placements = _placements.duplicate(true)
	super()

func _exit_level(scene_path: String):
	_save_placements_to_disk()
	persisted_placements = []
	super(scene_path)

func _launch():
	if _placements.size() < MIN_DEFENDERS:
		_phase_label.text = "PLACE AT LEAST %d DEFENDER FIRST" % MIN_DEFENDERS
		return
	_start_active()
	_stream.start()
	_phase_label.text = "EVADERS INBOUND"

func _on_stream_result(held: bool):
	ACHIEVEMENTS.check_level_one_result(held, _stream.circliness.average())

func _level_input(event: InputEvent):
	if _phase != Phase.SETUP:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var ship := _defender_at(get_global_mouse_position())
		if ship != null:
			_radial_target = ship
			var actions: Array = [{"id": "remove", "label": "Remove", "color": Color(0.8, 0.25, 0.25, 1.0)}]
			_radial.open(get_viewport().get_mouse_position(), actions, "Defender")
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p: Vector2 = get_global_mouse_position()
			if _can_place(p) and _placements.size() < MAX_DEFENDERS:
				_dragging = true
				_drag_start = p
				_drag_indicator.update_drag(true, "arrow", p, p, ACCENT)
		elif _dragging:
			_dragging = false
			_drag_indicator.update_drag(false)
			_place_defender(_drag_start, get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		_drag_indicator.update_drag(true, "arrow", _drag_start, get_global_mouse_position(), ACCENT)

func _can_place(p: Vector2) -> bool:
	var dist: float = p.distance_to(_planet)
	return dist >= PLACE_MIN and dist <= SCATTER_MAX

func _place_defender(start: Vector2, end: Vector2):
	if _placements.size() >= MAX_DEFENDERS:
		return
	var rot: float = start.angle_to_point(end) if start.distance_to(end) > 6.0 else 0.0
	var placement := {"pos": start, "rot": rot}
	_placements.append(placement)
	_spawn_defender(placement, PlayerData.ship_blocks)
	_update_count()
	queue_redraw()

func _defender_at(world_pos: Vector2) -> Node2D:
	for ship in _defender_ships:
		if is_instance_valid(ship) and ship.global_position.distance_to(world_pos) <= 16.0:
			return ship
	return null

func _on_radial_action(action_id: String):
	if action_id == "remove" and is_instance_valid(_radial_target):
		_placements.erase(_radial_target.get_meta("placement"))
		_defender_ships.erase(_radial_target)
		_radial_target.queue_free()
		_update_count()
		queue_redraw()
	_radial_target = null

func _clear_defenders():
	if _phase != Phase.SETUP:
		return
	_clear_ships()
	_placements.clear()
	_radial_target = null
	if _radial != null:
		_radial.visible = false
	_update_count()
	queue_redraw()

func _update_count():
	if _phase_label != null and _phase == Phase.SETUP:
		_phase_label.text = _level_title()
	if _count_label != null:
		_count_label.text = "DEFENDERS: %d / %d" % [_placements.size(), MAX_DEFENDERS]

func _draw_level():
	if _phase != Phase.SETUP:
		return
	draw_circle(_planet, SCATTER_MAX, ZONE_FILL)
	_draw_dashed_circle(_planet, SCATTER_MAX, Color(0.451, 0.616, 1.0, 0.35), 1.5)
	_draw_dashed_circle(_planet, PLACE_MIN, Color(0.6, 0.62, 0.74, 0.25), 1.0)
