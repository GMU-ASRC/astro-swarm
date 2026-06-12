extends Node2D

@export var robot_scene: PackedScene
@onready var drag_indicator: Node2D = $DragIndicator
@onready var obstacles_root: Node2D = $Obstacles
@onready var top_bar: CanvasLayer = $TopBar

var is_dragging: bool = false
var is_panning: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var arena_camera: Camera2D

const BG_COLOR   := Color(0.835, 0.835, 0.859, 1.0)
const GRID_COLOR := Color(0.741, 0.741, 0.769, 1.0)
const GRID_STEP  := 40.0
const RULER_COLOR := Color(0.420, 0.420, 0.475, 1.0)
const RULER_TEXT  := Color(0.320, 0.320, 0.400, 1.0)
const PX_PER_M   := 40.0

const WALL_FILL := Color(0.45, 0.45, 0.52, 1.0)
const WALL_BORDER := Color(0.22, 0.22, 0.28, 1.0)
const OBSTACLE_FILL := Color(0.55, 0.40, 0.30, 1.0)
const OBSTACLE_BORDER := Color(0.30, 0.20, 0.15, 1.0)
const MEASURE_COLOR := Color(0.176, 0.341, 0.714, 1.0)
const TOOL_PREVIEW_COLOR := Color(0.176, 0.341, 0.714, 1.0)

const SETTINGS_MODAL_SCENE = preload("res://ui/modal/SettingsModal.tscn")
const EXPORT_MODAL_SCRIPT = preload("res://ui/modal/ExportProgressModal.gd")
var settings_modal: CanvasLayer

var _measure_anchor: Vector2 = Vector2.ZERO
var _has_measure_anchor: bool = false
var _measure_committed: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena_camera = Camera2D.new()
	add_child(arena_camera)
	arena_camera.make_current()

	drag_indicator.update_drag(false)

	settings_modal = SETTINGS_MODAL_SCENE.instantiate()
	settings_modal.name = "ArenaSettingsModal"
	add_child(settings_modal)

	_fit_to_viewport()
	_restore_placements()
	_restore_obstacles()

	top_bar.open_workspace.connect(_goto_workspace)
	top_bar.request_clear.connect(_clear_arena)
	top_bar.request_stop.connect(_stop_arena)
	$RadialMenu.action_selected.connect(_on_radial_action)
	$RadialMenu.menu_closed.connect(func():
		_selected_robot = null
		_selected_obstacle = -1
	)
	get_viewport().size_changed.connect(_on_viewport_resized)
	SimulationManager.settings_changed.connect(_on_settings_changed)
	SimulationManager.obstacles_changed.connect(_on_obstacles_changed)
	SimulationManager.tool_changed.connect(_on_tool_changed)
	Input.joy_connection_changed.connect(_on_joy_changed)
	get_tree().paused = true
	queue_redraw()

	if SimulationManager.is_exporting:
		_run_video_export.call_deferred()

func open_settings_modal():
	if settings_modal:
		settings_modal.open()

func _on_settings_changed():
	_fit_to_viewport()
	_reconcile_controls()
	queue_redraw()

func _reconcile_controls():
	var controller_mode: bool = SimulationManager.settings.get("controller_mode", false)
	var is_multiplayer: bool = SimulationManager.settings.get("multiplayer", false)
	var max_slots: int = (2 if is_multiplayer else 1) if controller_mode else 1
	var to_release: Array = []
	for r in _controlled_robots:
		if controller_mode and r.controller_index < 0:
			to_release.append(r)
		elif controller_mode and r.controller_index >= max_slots:
			to_release.append(r)
		elif not controller_mode and r.controller_index >= 0:
			to_release.append(r)
	for r in to_release:
		_release_robot(r)

func _on_obstacles_changed():
	_restore_obstacles()

func _on_tool_changed(_tool_id: String):
	is_dragging = false
	drag_indicator.update_drag(false)
	_has_measure_anchor = false
	queue_redraw()

func _on_viewport_resized():
	_fit_to_viewport()
	queue_redraw()

func _draw():
	var s: Vector2 = Vector2(SimulationManager.settings.arena_width, SimulationManager.settings.arena_height)
	draw_rect(Rect2(Vector2.ZERO, s), BG_COLOR)

	var line_width: float = 1.0
	if arena_camera and arena_camera.zoom.x > 0.0:
		line_width = max(1.0, 1.0 / arena_camera.zoom.x)

	var x: float = 0.0
	while x <= s.x:
		draw_line(Vector2(x, 0.0), Vector2(x, s.y), GRID_COLOR, line_width)
		x += GRID_STEP
	var y: float = 0.0
	while y <= s.y:
		draw_line(Vector2(0.0, y), Vector2(s.x, y), GRID_COLOR, line_width)
		y += GRID_STEP

	for ob in SimulationManager.obstacles:
		_draw_obstacle(ob)

	for m in _measure_committed:
		_draw_measure_marks(m.start, m.end, line_width)

	var border_width: float = 4.0 * line_width
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.9, 0.2, 0.2, 1.0), false, border_width)
	_draw_ruler_h(s)
	_draw_ruler_v(s)

func _draw_obstacle(ob: Dictionary):
	if ob.get("type", "") == "wall":
		var pos: Vector2 = ob.get("position", Vector2.ZERO)
		var size: Vector2 = ob.get("size", Vector2.ZERO)
		var rect: Rect2 = Rect2(pos - size * 0.5, size)
		draw_rect(rect, WALL_FILL, true)
		draw_rect(rect, WALL_BORDER, false, 2.0)
	elif ob.get("type", "") == "circle":
		var pos: Vector2 = ob.get("position", Vector2.ZERO)
		var r: float = ob.get("radius", 0.0)
		draw_circle(pos, r, OBSTACLE_FILL)
		draw_arc(pos, r, 0.0, TAU, 64, OBSTACLE_BORDER, 2.0, true)

func _draw_measure_marks(p1: Vector2, p2: Vector2, line_width: float):
	draw_line(p1, p2, MEASURE_COLOR, max(2.0, line_width * 2.0), true)
	var meters: float = p1.distance_to(p2) / PX_PER_M
	var txt: String = "%.2f m" % meters
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 12
	var size: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var mid: Vector2 = (p1 + p2) * 0.5
	var pad: float = 4.0
	var bg_rect: Rect2 = Rect2(mid - Vector2(size.x * 0.5 + pad, size.y * 0.5 + pad), size + Vector2(pad * 2.0, pad * 2.0))
	draw_rect(bg_rect, Color(0.965, 0.965, 0.973, 1.0), true)
	draw_rect(bg_rect, MEASURE_COLOR, false, 1.0)
	draw_string(font, mid + Vector2(-size.x * 0.5, size.y * 0.3), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.137, 0.137, 0.196, 1.0))

func _draw_ruler_h(s: Vector2):
	var ruler_y: float = s.y - 18.0
	var max_m: int = int(s.x / PX_PER_M)
	for m in range(0, max_m + 1):
		var px: float = m * PX_PER_M
		var tick_h: float = 6.0 if m % 5 != 0 else 10.0
		draw_line(Vector2(px, ruler_y), Vector2(px, ruler_y + tick_h), RULER_COLOR, 1.0)
		if m % 5 == 0:
			draw_string(ThemeDB.fallback_font, Vector2(px + 2, ruler_y - 2), "%dm" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RULER_TEXT)

func _draw_ruler_v(s: Vector2):
	var ruler_x: float = 6.0
	var max_m: int = int(s.y / PX_PER_M)
	for m in range(0, max_m + 1):
		var py: float = s.y - m * PX_PER_M
		var tick_w: float = 6.0 if m % 5 != 0 else 10.0
		draw_line(Vector2(ruler_x, py), Vector2(ruler_x + tick_w, py), RULER_COLOR, 1.0)
		if m % 5 == 0 and m > 0:
			draw_string(ThemeDB.fallback_font, Vector2(ruler_x + tick_w + 2, py + 4), "%dm" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, RULER_TEXT)

func _fit_to_viewport():
	var w: float = SimulationManager.settings.arena_width
	var h: float = SimulationManager.settings.arena_height
	var s: Vector2 = Vector2(w, h)
	var t: float = 50.0

	if arena_camera:
		arena_camera.position = s / 2.0
		var vp: Vector2 = get_viewport_rect().size
		var zoom_x: float = vp.x / w
		var zoom_y: float = vp.y / h
		var zoom_min: float = min(zoom_x, zoom_y)
		arena_camera.zoom = Vector2(zoom_min, zoom_min)

	$Walls.collision_layer = 1
	$Walls.collision_mask = 1

	var top: CollisionShape2D = $Walls/TopWall
	var top_shape := RectangleShape2D.new()
	top_shape.size = Vector2(s.x + t * 2.0, t)
	top.shape = top_shape
	top.position = Vector2(s.x / 2.0, -t / 2.0)

	var bottom: CollisionShape2D = $Walls/BottomWall
	var bottom_shape := RectangleShape2D.new()
	bottom_shape.size = Vector2(s.x + t * 2.0, t)
	bottom.shape = bottom_shape
	bottom.position = Vector2(s.x / 2.0, s.y + t / 2.0)

	var left: CollisionShape2D = $Walls/LeftWall
	var left_shape := RectangleShape2D.new()
	left_shape.size = Vector2(t, s.y + t * 2.0)
	left.shape = left_shape
	left.position = Vector2(-t / 2.0, s.y / 2.0)

	var right: CollisionShape2D = $Walls/RightWall
	var right_shape := RectangleShape2D.new()
	right_shape.size = Vector2(t, s.y + t * 2.0)
	right.shape = right_shape
	right.position = Vector2(s.x + t / 2.0, s.y / 2.0)

var _selected_robot: Node2D = null
var _selected_obstacle: int = -1
var _controlled_robot: Node2D = null
var _controlled_robots: Array = []

func _restore_placements():
	for i in SimulationManager.placements.size():
		var p = SimulationManager.placements[i]
		var robot := robot_scene.instantiate()
		robot.type_id = p.type_id
		robot.robot_name = p.get("name", SimulationManager.get_random_name())
		robot.spawn_id = int(p.get("id", i))
		robot.global_position = p.position
		robot.rotation = p.rotation
		robot.clicked.connect(_on_robot_clicked)
		add_child(robot)

func _restore_obstacles():
	for child in obstacles_root.get_children():
		child.queue_free()
	for ob in SimulationManager.obstacles:
		_spawn_obstacle_body(ob)
	queue_redraw()

func _spawn_obstacle_body(ob: Dictionary):
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("obstacles")
	body.input_pickable = true
	var ob_id: int = ob.get("id", -1)
	body.set_meta("ob_id", ob_id)
	body.input_event.connect(func(_viewport, event, _shape_idx): _on_obstacle_input(event, ob_id))
	var shape_node := CollisionShape2D.new()
	if ob.get("type", "") == "wall":
		var sh := RectangleShape2D.new()
		sh.size = ob.get("size", Vector2.ZERO)
		shape_node.shape = sh
	elif ob.get("type", "") == "circle":
		var sh := CircleShape2D.new()
		sh.radius = ob.get("radius", 0.0)
		shape_node.shape = sh
	body.add_child(shape_node)
	body.position = ob.get("position", Vector2.ZERO)
	obstacles_root.add_child(body)

func _on_obstacle_input(event: InputEvent, ob_id: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if SimulationManager.has_started and not get_tree().paused:
			return
		_selected_robot = null
		_selected_obstacle = ob_id
		var actions: Array = [{"id": "remove_obstacle", "label": "Remove", "color": Color(0.8, 0.25, 0.25, 1.0)}]
		$RadialMenu.open(get_viewport().get_mouse_position(), actions, "Obstacle")
		get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if event.is_action_pressed("release_control") and _controlled_robot != null:
		_release_control()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _has_measure_anchor or not _measure_committed.is_empty():
			_has_measure_anchor = false
			_measure_committed.clear()
			drag_indicator.update_drag(false)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if arena_camera:
				arena_camera.zoom *= 1.1
				queue_redraw()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if arena_camera:
				arena_camera.zoom *= 0.9
				queue_redraw()
			return
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			return
	elif event is InputEventMouseMotion and is_panning:
		if arena_camera:
			arena_camera.position -= event.relative / arena_camera.zoom.x
			queue_redraw()
		return

	if SimulationManager.has_started and not get_tree().paused:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_in_ui_zone(event.position):
				return
			_on_left_press(get_global_mouse_position())
		elif is_dragging:
			_on_left_release(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		if is_dragging:
			_on_drag_update(get_global_mouse_position())
		elif _has_measure_anchor and SimulationManager.active_tool == "measure":
			drag_indicator.update_drag(true, "measure", _measure_anchor, get_global_mouse_position(), MEASURE_COLOR)

func _on_left_press(pos: Vector2):
	match SimulationManager.active_tool:
		"measure":
			if not _has_measure_anchor:
				_measure_anchor = pos
				_has_measure_anchor = true
				drag_indicator.update_drag(true, "measure", _measure_anchor, pos, MEASURE_COLOR)
			else:
				_measure_committed = [{"start": _measure_anchor, "end": pos}]
				_has_measure_anchor = false
				drag_indicator.update_drag(false)
				queue_redraw()
		"wall":
			is_dragging = true
			drag_start_pos = pos
			drag_indicator.update_drag(true, "rect", pos, pos, TOOL_PREVIEW_COLOR)
		"obstacle":
			is_dragging = true
			drag_start_pos = pos
			drag_indicator.update_drag(true, "circle", pos, pos, TOOL_PREVIEW_COLOR)
		_:
			is_dragging = true
			drag_start_pos = pos
			var type_color: Color = SimulationManager.get_type(SimulationManager.selected_type_id).color
			drag_indicator.update_drag(true, "arrow", pos, pos, type_color)

func _on_drag_update(pos: Vector2):
	match SimulationManager.active_tool:
		"wall":
			drag_indicator.update_drag(true, "rect", drag_start_pos, pos, TOOL_PREVIEW_COLOR)
		"obstacle":
			drag_indicator.update_drag(true, "circle", drag_start_pos, pos, TOOL_PREVIEW_COLOR)
		_:
			var type_color: Color = SimulationManager.get_type(SimulationManager.selected_type_id).color
			drag_indicator.update_drag(true, "arrow", drag_start_pos, pos, type_color)

func _on_left_release(pos: Vector2):
	is_dragging = false
	drag_indicator.update_drag(false)
	match SimulationManager.active_tool:
		"wall":
			var rect: Rect2 = Rect2(drag_start_pos, pos - drag_start_pos).abs()
			if rect.size.x >= 6.0 and rect.size.y >= 6.0:
				SimulationManager.add_obstacle({
					"type": "wall",
					"position": rect.position + rect.size * 0.5,
					"size": rect.size,
				})
		"obstacle":
			var radius: float = drag_start_pos.distance_to(pos)
			if radius >= 6.0:
				SimulationManager.add_obstacle({
					"type": "circle",
					"position": drag_start_pos,
					"radius": radius,
				})
		"place_robot":
			_spawn_robot(drag_start_pos, pos)

func _is_in_ui_zone(pos: Vector2) -> bool:
	if pos.y < 76.0:
		return true
	return false

func _spawn_robot(start_pos: Vector2, end_pos: Vector2):
	if robot_scene == null:
		push_error("robot_scene is not assigned in Arena!")
		return
	var robot := robot_scene.instantiate()
	var spawn_id := SimulationManager.next_robot_id()
	robot.type_id = SimulationManager.selected_type_id
	robot.robot_name = SimulationManager.get_random_name()
	robot.spawn_id = spawn_id
	robot.global_position = start_pos
	if start_pos.distance_to(end_pos) > 4.0:
		robot.rotation = start_pos.angle_to_point(end_pos)
	else:
		robot.rotation = randf_range(0.0, TAU)
	robot.clicked.connect(_on_robot_clicked)
	add_child(robot)
	SimulationManager.placements.append({
		"type_id": robot.type_id,
		"name": robot.robot_name,
		"id": spawn_id,
		"position": robot.global_position,
		"rotation": robot.rotation
	})

func _on_robot_clicked(robot: Node2D):
	_selected_robot = robot
	var playing := SimulationManager.has_started and not get_tree().paused
	var replaying := SimulationManager.is_replaying
	var actions: Array = []
	if not replaying:
		if _controlled_robots.has(robot):
			var label: String = "Release"
			if SimulationManager.settings.get("controller_mode", false) and robot.controller_index >= 0:
				label = "Release P%d" % (robot.controller_index + 1)
			actions.append({"id": "release", "label": label, "color": Color(0.85, 0.5, 0.2, 1.0)})
		else:
			var take_label: String = "Take Over"
			var controller_mode: bool = SimulationManager.settings.get("controller_mode", false)
			var is_multiplayer: bool = SimulationManager.settings.get("multiplayer", false)
			var max_slots: int = (2 if is_multiplayer else 1) if controller_mode else 1
			if controller_mode and _controlled_robots.size() < max_slots:
				var preview_slot: int = _next_free_controller_slot(max_slots)
				if preview_slot >= 0:
					take_label = "Take Over P%d" % (preview_slot + 1)
			if controller_mode and _controlled_robots.size() >= max_slots:
				pass
			else:
				actions.append({"id": "take_over", "label": take_label, "color": Color(0.176, 0.341, 0.714, 1.0)})
	actions.append({
		"id": "toggle_trail",
		"label": "Trail Off" if robot.trail_enabled else "Trail On",
		"color": Color(0.482, 0.302, 0.686, 1.0)
	})
	actions.append({
		"id": "toggle_coords",
		"label": "Unpin XY" if robot.pin_coords else "Pin XY",
		"color": Color(0.255, 0.463, 0.843, 1.0)
	})
	if not playing and not replaying:
		actions.append({"id": "remove", "label": "Remove", "color": Color(0.8, 0.25, 0.25, 1.0)})
	$RadialMenu.open(robot.get_global_transform_with_canvas().origin, actions, _robot_title(robot))

func _robot_title(robot: Node2D) -> String:
	var meters: Vector2 = robot.global_position / SimulationManager.PX_PER_METER
	return "%s\n(%.1fm, %.1fm)" % [robot.robot_name, meters.x, meters.y]

func _on_radial_action(action_id: String):
	if action_id == "remove_obstacle":
		if _selected_obstacle >= 0:
			SimulationManager.remove_obstacle(_selected_obstacle)
			_selected_obstacle = -1
		return
	if _selected_robot == null:
		return
	match action_id:
		"remove":
			var placements = SimulationManager.placements
			for i in range(placements.size()):
				var p = placements[i]
				if p.type_id == _selected_robot.type_id and p.position.is_equal_approx(_selected_robot.global_position):
					placements.remove_at(i)
					break
			if _controlled_robots.has(_selected_robot):
				_release_robot(_selected_robot)
			_selected_robot.queue_free()
		"take_over":
			_take_over(_selected_robot)
		"release":
			_release_robot(_selected_robot)
		"toggle_trail":
			_selected_robot.toggle_trail()
		"toggle_coords":
			_selected_robot.toggle_pin_coords()
	_selected_robot = null

func _take_over(robot: Node2D):
	if _controlled_robots.has(robot):
		return
	var controller_mode: bool = SimulationManager.settings.get("controller_mode", false)
	var is_multiplayer: bool = SimulationManager.settings.get("multiplayer", false)
	var max_slots: int = (2 if is_multiplayer else 1) if controller_mode else 1

	if not controller_mode:
		_release_all_controlled()
		robot.assign_controller(-1)
		_attach_controlled(robot)
		_controlled_robot = robot
		return

	if _controlled_robots.size() >= max_slots:
		return
	var slot: int = _next_free_controller_slot(max_slots)
	if slot < 0:
		return
	robot.assign_controller(slot)
	_attach_controlled(robot)
	if _controlled_robot == null:
		_controlled_robot = robot

func _attach_controlled(robot: Node2D):
	_controlled_robots.append(robot)
	robot.set_controlled(true)
	if not robot.release_requested.is_connected(_on_release_requested):
		robot.release_requested.connect(_on_release_requested)

func _next_free_controller_slot(max_slots: int) -> int:
	var used: Array = []
	for r in _controlled_robots:
		used.append(r.controller_index)
	for i in range(max_slots):
		if not used.has(i):
			return i
	return -1

func _on_release_requested(robot: Node2D):
	_release_robot(robot)

func _on_joy_changed(device: int, connected: bool):
	if connected:
		return
	for r in _controlled_robots.duplicate():
		if r.controller_index == device:
			_release_robot(r)

func _release_robot(robot: Node2D):
	if robot == null:
		return
	if _controlled_robots.has(robot):
		_controlled_robots.erase(robot)
	robot.set_controlled(false)
	if _controlled_robot == robot:
		_controlled_robot = _controlled_robots.back() if not _controlled_robots.is_empty() else null

func _release_all_controlled():
	for r in _controlled_robots.duplicate():
		r.set_controlled(false)
	_controlled_robots.clear()
	_controlled_robot = null

func _release_control():
	var keyboard_robot: Node2D = null
	for r in _controlled_robots:
		if r.controller_index < 0:
			keyboard_robot = r
			break
	if keyboard_robot != null:
		_release_robot(keyboard_robot)
	elif _controlled_robot != null:
		_release_robot(_controlled_robot)

func _clear_arena():
	_release_all_controlled()
	SimulationManager.stop_recording_and_save()
	SimulationManager.has_started = false
	SimulationManager.is_replaying = false
	SimulationManager.simulation_time = 0.0
	for r in get_tree().get_nodes_in_group("robots"):
		r.queue_free()
	SimulationManager.clear_all_arena()
	_measure_committed.clear()
	_has_measure_anchor = false
	drag_indicator.update_drag(false)
	get_tree().paused = true
	queue_redraw()

func _stop_arena():
	_release_all_controlled()
	SimulationManager.stop_recording_and_save()
	SimulationManager.has_started = false
	SimulationManager.is_replaying = false
	SimulationManager.simulation_time = 0.0
	for r in get_tree().get_nodes_in_group("robots"):
		r.queue_free()
	_restore_placements()
	get_tree().paused = true

func _exit_tree():
	SimulationManager.stop_recording_and_save()
	SimulationManager.has_started = false

func _goto_workspace():
	get_tree().change_scene_to_file("res://ui/workspace/Workspace.tscn")


const _EXPORT_FRAMES_DIR := "user://export_frames"
const _EXPORT_OUTPUT_DIR := "user://exports"

func _run_video_export() -> void:
	top_bar.set_minimal_for_export(true)
	$DragIndicator.visible = false
	$RadialMenu.visible = false

	var overlay = EXPORT_MODAL_SCRIPT.new()
	add_child(overlay)

	await get_tree().process_frame
	await get_tree().process_frame

	var frames: Array = SimulationManager.current_replay
	var fps := int(round(1.0 / SimulationManager.RECORD_INTERVAL))
	var total := frames.size()

	if total == 0:
		overlay.show_error("This run contains no recorded frames.")
		await overlay.dismissed
		_finish_export()
		return

	DirAccess.make_dir_recursive_absolute(_EXPORT_FRAMES_DIR)
	for fname in DirAccess.get_files_at(_EXPORT_FRAMES_DIR):
		DirAccess.remove_absolute(_EXPORT_FRAMES_DIR + "/" + fname)

	var original_title := get_window().title
	overlay.visible = false

	for i in range(total):
		SimulationManager._apply_replay_frame(frames[i])
		SimulationManager.replay_time = i * SimulationManager.RECORD_INTERVAL
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s/frame_%05d.png" % [_EXPORT_FRAMES_DIR, i])
		DisplayServer.window_set_title("AstroSwarm — Exporting %d / %d" % [i + 1, total])

	DisplayServer.window_set_title(original_title)
	overlay.visible = true
	overlay.set_progress(total, total)

	DirAccess.make_dir_recursive_absolute(_EXPORT_OUTPUT_DIR)
	var dt := Time.get_datetime_dict_from_system()
	var out_name := "replay_%04d%02d%02d_%02d%02d%02d.mp4" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	var out_path := ProjectSettings.globalize_path(_EXPORT_OUTPUT_DIR + "/" + out_name)
	var input_pattern := ProjectSettings.globalize_path(_EXPORT_FRAMES_DIR + "/frame_%05d.png")

	overlay.set_status("Encoding video with ffmpeg…")
	await get_tree().process_frame

	var ffmpeg_path := _resolve_ffmpeg()
	var ffmpeg_output: Array = []
	var exit_code := OS.execute(ffmpeg_path, [
		"-y",
		"-loglevel", "error",
		"-framerate", str(fps),
		"-i", input_pattern,
		"-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
		"-c:v", "libopenh264",
		"-pix_fmt", "yuv420p",
		out_path
	], ffmpeg_output, true)

	if exit_code == 0:
		for fname in DirAccess.get_files_at(_EXPORT_FRAMES_DIR):
			DirAccess.remove_absolute(_EXPORT_FRAMES_DIR + "/" + fname)
		if SimulationManager.pending_upload:
			overlay.set_status("Uploading to website…")
			await get_tree().process_frame
			RunUploader.upload(SimulationManager.pending_upload_run, out_path, SimulationManager.get_setup_data())
			var result = await RunUploader.upload_finished
			SimulationManager.pending_upload = false
			SimulationManager.pending_upload_run = ""
			if result[0]:
				overlay.show_success(out_path)
			else:
				overlay.show_error("Upload failed (%s). Video saved at:" % result[1], out_path)
		else:
			overlay.show_success(out_path)
	else:
		var pngs_path := ProjectSettings.globalize_path(_EXPORT_FRAMES_DIR)
		var msg := "ffmpeg was not found or failed (exit %d). Install ffmpeg, or use the captured PNG frames left at:" % exit_code
		overlay.show_error(msg, pngs_path)

	await overlay.dismissed
	_finish_export()

func _finish_export() -> void:
	SimulationManager.is_exporting = false
	SimulationManager.is_replaying = false
	SimulationManager.replay_time = 0.0
	SimulationManager.current_replay = []
	SimulationManager.pending_upload = false
	SimulationManager.pending_upload_run = ""
	get_tree().change_scene_to_file("res://levels/SaveManagerScene.tscn")

func _resolve_ffmpeg() -> String:
	var platform := _ffmpeg_platform_subdir()
	if platform.is_empty():
		return "ffmpeg"

	var exe_name := "ffmpeg.exe" if platform == "windows" else "ffmpeg"
	var bundled_resource := "res://bin/%s/%s" % [platform, exe_name]
	if not FileAccess.file_exists(bundled_resource):
		return "ffmpeg"

	var bundled_global := ProjectSettings.globalize_path(bundled_resource)
	if not OS.has_feature("editor"):
		var extracted := "user://bin/" + exe_name
		if not FileAccess.file_exists(extracted):
			DirAccess.make_dir_recursive_absolute("user://bin")
			var src := FileAccess.open(bundled_resource, FileAccess.READ)
			var dst := FileAccess.open(extracted, FileAccess.WRITE)
			if src != null and dst != null:
				dst.store_buffer(src.get_buffer(src.get_length()))
		bundled_global = ProjectSettings.globalize_path(extracted)
		if platform != "windows":
			OS.execute("chmod", ["+x", bundled_global])

	return bundled_global

func _ffmpeg_platform_subdir() -> String:
	match OS.get_name():
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return "linux"
		"Windows", "UWP":
			return "windows"
		"macOS":
			return "macos"
	return ""
