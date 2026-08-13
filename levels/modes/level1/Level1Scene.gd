extends "res://levels/modes/FARPBase.gd"

static var persisted_placements: Array = []

var _radial: CanvasLayer
var _radial_target: Node2D = null
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _spawn_rng := RandomNumberGenerator.new()

func _level_id() -> String:
	return "farp1"

func _level_title() -> String:
	return "LEVEL 1 - PLACE YOUR DEFENDERS"

func _level_subtitle() -> String:
	return "Drag inside the blue ring to place a defender and aim it. Place %d to %d. Right-click a defender to remove it. Program them in WORKSPACE, then LAUNCH." % [MIN_DEFENDERS, MAX_DEFENDERS]

func _walkthrough_lines() -> Array:
	return [
		"GOAL: keep the red evader from reaching the center planet.",
		"1.  Drag inside the blue ring to drop a defender. The drag direction sets the vision cone it starts facing.",
		"2.  Place between %d and %d defenders. Right-click one to remove it." % [MIN_DEFENDERS, MAX_DEFENDERS],
		"3.  Open WORKSPACE to program how every defender moves and scans. All defenders run the same algorithm.",
		"4.  Press LAUNCH EVADER. A red evader spawns on the outer ring and drives straight at the planet.",
		"5.  DETECTION is logged the first time any defender sees the evader in its vision cone.",
		"6.  CAPTURE is the first time a defender physically touches the evader. Capture ends the run and you win.",
		"7.  The GOAL TIME is when the evader reaches the planet. If that happens first, the planet is breached.",
		"8.  Every run is submitted automatically and benchmarked over many trials on the server.",
		"Scroll to zoom, middle-drag to pan.",
	]

func _hint_lines() -> Array:
	return [
		"Seeing the evader is not enough - a defender has to touch it to capture it.",
		"A wide FOV finds the evader sooner, a long vision range finds it further out. You cannot max both, so trade them off.",
		"Spread defenders around the ring so no approach angle is uncovered.",
		"Use WHEN SEES ENEMY with DO FACE so a defender charges the evader once it spots it - that turns a detection into a capture.",
		"Speed matters for interception. A slow defender can see the evader and still never catch it.",
		"Defenders that patrol (turn while moving) sweep more area than defenders that sit still.",
	]

func _setup_level():
	_spawn_rng.randomize()
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
	_launch_btn.text = "LAUNCH EVADER (S) >"
	_restore_placements()

func _restart_level():
	for placement in persisted_placements:
		var p: Dictionary = {"pos": placement.pos, "rot": placement.rot}
		_placements.append(p)
		_spawn_defender(p, PlayerData.ship_blocks)
	_launch_btn.text = "LAUNCH EVADER (S) >"
	_phase_label.text = _level_title()
	_hint_label.text = _level_subtitle()

func _restore_placements():
	var source: Array = persisted_placements if not persisted_placements.is_empty() else _placements_from_disk()
	for placement in source:
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

func _leave():
	_save_placements_to_disk()
	persisted_placements = []
	super()

func _launch():
	if _placements.size() < MIN_DEFENDERS:
		_hint_label.text = "Place at least %d defender first." % MIN_DEFENDERS
		return
	_start_active()
	var angle: float = _spawn_rng.randf() * TAU
	_spawn_scripted_evader(_planet + Vector2(EVADER_SPAWN_RADIUS, 0.0).rotated(angle))
	_phase_label.text = "EVADER INBOUND"
	_hint_label.text = "Your defenders run their workspace program. Touch the evader to capture it before it reaches the planet."

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
	return dist >= PLACE_MIN and dist <= PLACE_MAX

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
	if _count_label != null:
		_count_label.text = "DEFENDERS: %d / %d" % [_placements.size(), MAX_DEFENDERS]

func _draw_level():
	if _phase != Phase.SETUP:
		return
	draw_circle(_planet, PLACE_MAX, ZONE_FILL)
	_draw_dashed_circle(_planet, PLACE_MAX, Color(0.451, 0.616, 1.0, 0.35), 1.5)
	_draw_dashed_circle(_planet, PLACE_MIN, Color(0.6, 0.62, 0.74, 0.25), 1.0)
