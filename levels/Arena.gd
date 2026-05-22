extends Node2D

@export var robot_scene: PackedScene
@onready var drag_indicator: Node2D = $DragIndicator

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

const SIDEBAR_RIGHT_X := 140.0
const TOPBAR_BOTTOM_Y := 68.0

const SETTINGS_MODAL_SCENE = preload("res://ui/modal/SettingsModal.tscn")
const EXPORT_MODAL_SCRIPT = preload("res://ui/modal/ExportProgressModal.gd")
var settings_modal: CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena_camera = Camera2D.new()
	add_child(arena_camera)
	arena_camera.make_current()

	drag_indicator.update_drag(false)

	settings_modal = SETTINGS_MODAL_SCENE.instantiate()
	add_child(settings_modal)

	_fit_to_viewport()
	_restore_placements()

	$Sidebar.settings_btn.pressed.connect(func(): settings_modal.open())
	$Sidebar.open_workspace.connect(_goto_workspace)
	$Sidebar.request_clear.connect(_clear_arena)
	$TopBar.request_stop.connect(_stop_arena)
	$RadialMenu.action_selected.connect(_on_radial_action)
	$RadialMenu.menu_closed.connect(func(): _selected_robot = null)
	get_viewport().size_changed.connect(_on_viewport_resized)
	SimulationManager.settings_changed.connect(_on_settings_changed)
	get_tree().paused = true
	queue_redraw()

	if SimulationManager.is_exporting:
		_run_video_export.call_deferred()

func _on_settings_changed():
	_fit_to_viewport()
	queue_redraw()

func _on_viewport_resized():
	_fit_to_viewport()
	queue_redraw()

func _draw():
	var s = Vector2(SimulationManager.settings.arena_width, SimulationManager.settings.arena_height)
	draw_rect(Rect2(Vector2.ZERO, s), BG_COLOR)

	var line_width := 1.0
	if arena_camera and arena_camera.zoom.x > 0.0:
		line_width = max(1.0, 1.0 / arena_camera.zoom.x)

	var x := 0.0
	while x <= s.x:
		draw_line(Vector2(x, 0.0), Vector2(x, s.y), GRID_COLOR, line_width)
		x += GRID_STEP
	var y := 0.0
	while y <= s.y:
		draw_line(Vector2(0.0, y), Vector2(s.x, y), GRID_COLOR, line_width)
		y += GRID_STEP

	var border_width := 4.0 * line_width
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.9, 0.2, 0.2, 1.0), false, border_width)
	_draw_ruler_h(s)
	_draw_ruler_v(s)

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
	var w = SimulationManager.settings.arena_width
	var h = SimulationManager.settings.arena_height
	var s = Vector2(w, h)
	var t := 50.0

	if arena_camera:
		arena_camera.position = s / 2.0
		var vp = get_viewport_rect().size
		var zoom_x = vp.x / w
		var zoom_y = vp.y / h
		var zoom_min = min(zoom_x, zoom_y)
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
var _controlled_robot: Node2D = null

func _restore_placements():
	for p in SimulationManager.placements:
		var robot := robot_scene.instantiate()
		robot.type_id = p.type_id
		robot.robot_name = p.get("name", SimulationManager.get_random_name())
		robot.global_position = p.position
		robot.rotation = p.rotation
		robot.clicked.connect(_on_robot_clicked)
		add_child(robot)

func _is_in_ui_zone(pos: Vector2) -> bool:
	var s := get_viewport_rect().size
	if pos.x < SIDEBAR_RIGHT_X + 12.0:
		return true
	if pos.y < TOPBAR_BOTTOM_Y and pos.x > s.x - 360.0:
		return true
	return false

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and Input.is_action_just_pressed("release_control") and _controlled_robot != null:
		_release_control()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if arena_camera:
				arena_camera.zoom *= 1.1
				queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if arena_camera:
				arena_camera.zoom *= 0.9
				queue_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
	elif event is InputEventMouseMotion and is_panning:
		if arena_camera:
			arena_camera.position -= event.relative / arena_camera.zoom.x
			queue_redraw()

	if SimulationManager.has_started and not get_tree().paused:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if _is_in_ui_zone(event.position):
				return
			is_dragging = true
			drag_start_pos = get_global_mouse_position()
			var type_color: Color = SimulationManager.get_type(SimulationManager.selected_type_id).color
			drag_indicator.update_drag(true, drag_start_pos, drag_start_pos, type_color)
		elif not event.pressed and is_dragging:
			is_dragging = false
			drag_indicator.update_drag(false)
			_spawn_robot(drag_start_pos, get_global_mouse_position())
	elif event is InputEventMouseMotion and is_dragging:
		var type_color: Color = SimulationManager.get_type(SimulationManager.selected_type_id).color
		drag_indicator.update_drag(true, drag_start_pos, get_global_mouse_position(), type_color)

func _spawn_robot(start_pos: Vector2, end_pos: Vector2):
	if robot_scene == null:
		push_error("robot_scene is not assigned in Arena!")
		return
	var robot := robot_scene.instantiate()
	robot.type_id = SimulationManager.selected_type_id
	robot.robot_name = SimulationManager.get_random_name()
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
		"position": robot.global_position,
		"rotation": robot.rotation
	})

func _on_robot_clicked(robot: Node2D):
	_selected_robot = robot
	var playing := SimulationManager.has_started and not get_tree().paused
	var replaying := SimulationManager.is_replaying
	var actions: Array = []
	if not replaying:
		if _controlled_robot == robot:
			actions.append({"id": "release", "label": "Release", "color": Color(0.85, 0.5, 0.2, 1.0)})
		else:
			actions.append({"id": "take_over", "label": "Take Over", "color": Color(0.176, 0.341, 0.714, 1.0)})
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
	$RadialMenu.open(get_global_mouse_position(), actions, _robot_title(robot))

func _robot_title(robot: Node2D) -> String:
	var meters: Vector2 = robot.global_position / SimulationManager.PX_PER_METER
	return "%s\n(%.1fm, %.1fm)" % [robot.robot_name, meters.x, meters.y]

func _on_radial_action(action_id: String):
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
			if _controlled_robot == _selected_robot:
				_controlled_robot = null
			_selected_robot.queue_free()
		"take_over":
			_take_over(_selected_robot)
		"release":
			_release_control()
		"toggle_trail":
			_selected_robot.toggle_trail()
		"toggle_coords":
			_selected_robot.toggle_pin_coords()
	_selected_robot = null

func _take_over(robot: Node2D):
	if _controlled_robot != null and _controlled_robot != robot:
		_controlled_robot.set_controlled(false)
	_controlled_robot = robot
	robot.set_controlled(true)

func _release_control():
	if _controlled_robot != null:
		_controlled_robot.set_controlled(false)
		_controlled_robot = null

func _clear_arena():
	_controlled_robot = null
	SimulationManager.stop_recording_and_save()
	SimulationManager.has_started = false
	SimulationManager.is_replaying = false
	SimulationManager.simulation_time = 0.0
	for r in get_tree().get_nodes_in_group("robots"):
		r.queue_free()
	SimulationManager.clear_placements()
	get_tree().paused = true

func _stop_arena():
	_controlled_robot = null
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
	$Sidebar.visible = false
	$DragIndicator.visible = false
	$RadialMenu.visible = false
	$TopBar.set_minimal_for_export(true)

	var overlay = EXPORT_MODAL_SCRIPT.new()
	add_child(overlay)

	await get_tree().process_frame
	await get_tree().process_frame

	var frames: Array = SimulationManager.current_replay
	var robots: Array = get_tree().get_nodes_in_group("robots")
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
		var frame: Array = frames[i]
		for j in range(min(frame.size(), robots.size())):
			robots[j].global_position = frame[j].pos
			robots[j].rotation = frame[j].rot
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
