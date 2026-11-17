extends Node2D

const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")
const ARENA_GENERATOR := preload("res://levels/modes/match/MatchArenaGenerator.gd")
const PLAYER_STATE := preload("res://levels/modes/match/MatchPlayerState.gd")
const SIMULATION := preload("res://levels/modes/match/MatchSimulation.gd")
const REPLICA := preload("res://levels/modes/match/MatchReplica.gd")
const BACKDROP := preload("res://levels/modes/match/MatchBackdrop.gd")
const HOME_BASE := preload("res://levels/modes/match/HomeBase.gd")
const MINING_SITE := preload("res://levels/modes/match/MiningSite.gd")
const MATCH_CAMERA := preload("res://levels/modes/match/MatchCamera.gd")
const MATCH_HUD := preload("res://levels/modes/match/MatchHud.gd")
const PAUSE_MENU := preload("res://levels/modes/match/MatchPauseMenu.gd")
const FOG_OVERLAY := preload("res://levels/modes/match/FogOverlay.gd")
const RESULT_PANEL := preload("res://levels/modes/match/MatchResultPanel.gd")
const WORKSPACE_SCENE := preload("res://levels/modes/match/MatchWorkspace.tscn")
const PILOT_INPUT := preload("res://levels/modes/match/MatchPilotInput.gd")
const TUTORIAL := preload("res://ui/tutorial/BlobTutorial.gd")
const TUTORIAL_LINES := preload("res://levels/modes/match/MatchTutorialLines.gd")
const EXPLOSION := preload("res://entities/ship/Explosion.gd")
const DRAG_INDICATOR := preload("res://levels/components/DragIndicator.tscn")

const LOBBY_SCENE := "res://levels/menus/MatchLobbyScene.tscn"
const MIN_DRAG_LENGTH := 6.0

var mode: int = MATCH_CONFIG.Mode.REGULAR
var local_slot: int = 0
var is_host: bool = false

var _layout: Dictionary = {}
var _players: Array = []
var _homes: Array = []
var _sites: Array = []
var _authority
var _camera
var _hud
var _pause_menu
var _fog
var _result_panel
var _workspace_layer: CanvasLayer = null
var _tutorial: CanvasLayer = null
var _drag_indicator: Node2D
var _pilot
var _snapshot_timer: float = 0.0
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _discovered: Dictionary = {}
var _over: bool = false
var _music: AudioStreamPlayer

func _ready():
	get_tree().paused = false
	if not MatchNetwork.is_online:
		get_tree().change_scene_to_file.call_deferred(LOBBY_SCENE)
		return
	var settings: Dictionary = MatchNetwork.match_settings
	mode = int(settings.get("mode", MATCH_CONFIG.Mode.REGULAR))
	local_slot = MatchNetwork.local_slot
	is_host = MatchNetwork.is_host
	_layout = ARENA_GENERATOR.generate(int(settings.get("seed", 1)))
	var names: Array = settings.get("names", ["HOST", "GUEST"])
	for slot in 2:
		_players.append(PLAYER_STATE.new(slot, str(names[slot])))
	_build_world()
	_build_authority()
	_build_camera()
	_build_interface()
	_connect_network()
	_start_music()

func _build_world():
	var backdrop = BACKDROP.new()
	backdrop.setup(_layout)
	add_child(backdrop)
	for slot in 2:
		var home = HOME_BASE.new()
		home.setup(slot, _layout["homes"][slot], int(_layout["home_seeds"][slot]))
		home.show_ring = slot == local_slot
		add_child(home)
		_homes.append(home)
	var site_index: int = 0
	for site_data in _layout["sites"]:
		var site = MINING_SITE.new()
		site.setup(site_index, site_data)
		add_child(site)
		_sites.append(site)
		site_index += 1
	if mode == MATCH_CONFIG.Mode.FOG:
		_homes[1 - local_slot].visible = false
		for site in _sites:
			site.visible = false
	_drag_indicator = DRAG_INDICATOR.instantiate()
	_drag_indicator.z_index = 8
	add_child(_drag_indicator)

func _build_authority():
	if is_host:
		_authority = SIMULATION.new()
	else:
		_authority = REPLICA.new()
	add_child(_authority)
	_authority.setup(_players, _homes, _sites, _layout["arena"], self)
	_authority.ship_spawned.connect(_on_ship_spawned)
	if is_host:
		_authority.notice.connect(_on_sim_notice)
		_authority.explosion.connect(_on_sim_explosion)
		_authority.match_over.connect(_on_sim_match_over)

func _build_camera():
	_camera = MATCH_CAMERA.new()
	_camera.home_center = _homes[local_slot].position
	_camera.arena = _layout["arena"]
	_camera.can_pan = mode == MATCH_CONFIG.Mode.REGULAR
	add_child(_camera)
	_camera.make_current()
	_pilot = PILOT_INPUT.new()

func _build_interface():
	if mode == MATCH_CONFIG.Mode.FOG:
		var fog_layer := CanvasLayer.new()
		fog_layer.layer = 5
		add_child(fog_layer)
		_fog = FOG_OVERLAY.new()
		fog_layer.add_child(_fog)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	_hud = MATCH_HUD.new()
	hud_layer.add_child(_hud)
	_hud.build_store(_players[local_slot])
	_hud.minimap.setup(_layout["arena"], _homes, _sites, _authority, _camera, local_slot, mode == MATCH_CONFIG.Mode.REGULAR)
	_hud.buy_requested.connect(func(item_id): MatchNetwork.send_command("buy", {"item": item_id}))
	_hud.upgrade_requested.connect(func(upgrade_id): MatchNetwork.send_command("upgrade", {"id": upgrade_id}))
	_hud.ready_requested.connect(_toggle_ready)
	_hud.workspace_requested.connect(_open_workspace)
	_hud.menu_requested.connect(_request_pause)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 25
	add_child(menu_layer)
	_pause_menu = PAUSE_MENU.new()
	menu_layer.add_child(_pause_menu)
	_pause_menu.resume_requested.connect(func(): MatchNetwork.send_command("pause", {"on": false}))
	_pause_menu.tutorial_requested.connect(_show_tutorial)
	_pause_menu.forfeit_requested.connect(func(): MatchNetwork.send_command("forfeit"))
	_pause_menu.leave_requested.connect(_leave)
	var result_layer := CanvasLayer.new()
	result_layer.layer = 30
	add_child(result_layer)
	_result_panel = RESULT_PANEL.new()
	result_layer.add_child(_result_panel)
	_result_panel.leave_requested.connect(_leave)

func _connect_network():
	MatchNetwork.opponent_left.connect(_on_opponent_left)
	if is_host:
		MatchNetwork.command_received.connect(_authority.handle_command)
		MatchNetwork.pilot_received.connect(_authority.set_pilot)
	else:
		MatchNetwork.snapshot_received.connect(_authority.apply_snapshot)
		MatchNetwork.event_received.connect(_on_network_event)

func _exit_tree():
	var connections: Array = [
		[MatchNetwork.opponent_left, _on_opponent_left],
		[MatchNetwork.event_received, _on_network_event],
	]
	if _authority != null:
		connections.append([MatchNetwork.command_received, Callable(_authority, "handle_command")])
		connections.append([MatchNetwork.pilot_received, Callable(_authority, "set_pilot")])
		connections.append([MatchNetwork.snapshot_received, Callable(_authority, "apply_snapshot")])
	for connection in connections:
		if connection[0].is_connected(connection[1]):
			connection[0].disconnect(connection[1])

func _process(delta: float):
	if _authority == null:
		return
	var input: Vector2 = _pilot.read()
	if _workspace_layer != null or _authority.paused:
		input = Vector2.ZERO
	MatchNetwork.send_pilot(input.x, input.y)
	if is_host:
		_snapshot_timer -= delta
		if _snapshot_timer <= 0.0:
			_snapshot_timer = MATCH_CONFIG.SNAPSHOT_INTERVAL
			MatchNetwork.broadcast_snapshot(_authority.snapshot())
	_camera.scout = _authority.scout_of(local_slot)
	_hud.refresh(_players[local_slot], _players[1 - local_slot], _authority.phase, _authority.setup_left, _authority.match_left, mode)
	_refresh_pause_menu()
	if mode == MATCH_CONFIG.Mode.FOG:
		_update_fog()

func _refresh_pause_menu():
	if _authority.paused and not _over:
		_pause_menu.show_paused(_players[_authority.paused_by].display_name)
	elif _pause_menu.visible:
		_pause_menu.hide_menu()

func _update_fog():
	var circles: Array = [{"center": _homes[local_slot].position, "radius": MATCH_CONFIG.HOME_VISION}]
	for ship in _authority.ships.values():
		if is_instance_valid(ship) and ship.owner_slot == local_slot:
			circles.append({"center": ship.global_position, "radius": ship.vision_radius()})
	for ship in _authority.ships.values():
		if is_instance_valid(ship) and ship.owner_slot != local_slot:
			ship.visible = _inside_any(ship.global_position, 0.0, circles)
	for site in _sites:
		_reveal_if_seen(site, site.radius, circles)
	_reveal_if_seen(_homes[1 - local_slot], _homes[1 - local_slot].radius, circles)
	_fog.update_circles(_camera, circles)

func _reveal_if_seen(node: Node2D, radius: float, circles: Array):
	if not _discovered.has(node) and _inside_any(node.position, radius, circles):
		_discovered[node] = true
		if node in _sites:
			_hud.show_notice("ASTRODUST MOON DISCOVERED")
		else:
			_hud.show_notice("ENEMY PLANET FOUND")
	node.visible = _discovered.has(node)

func _inside_any(point: Vector2, radius: float, circles: Array) -> bool:
	for circle in circles:
		if point.distance_to(circle["center"]) <= float(circle["radius"]) + radius:
			return true
	return false

func _on_ship_spawned(ship):
	if mode == MATCH_CONFIG.Mode.FOG and ship.owner_slot != local_slot:
		ship.visible = false

func _unhandled_input(event: InputEvent):
	if _authority == null or _over:
		return
	if event is InputEventKey and event.pressed and not event.echo and _handle_key(event.keycode):
		get_viewport().set_input_as_handled()
		return
	if _authority.paused:
		return
	if _camera.handle_input(event):
		return
	_handle_deploy_input(event)

func _handle_key(keycode: int) -> bool:
	if keycode == KEY_ESCAPE:
		if _workspace_layer != null:
			_close_workspace()
		elif _authority.paused:
			MatchNetwork.send_command("pause", {"on": false})
		else:
			_request_pause()
		return true
	if _authority.paused or _workspace_layer != null:
		return false
	match keycode:
		KEY_TAB:
			_open_workspace()
		KEY_B:
			_hud.toggle_shop()
		KEY_U:
			_hud.toggle_upgrades()
		KEY_F:
			_camera.toggle_follow()
		KEY_H:
			_camera.center_on_home()
		KEY_R:
			_toggle_ready()
		_:
			return false
	return true

func _handle_deploy_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var world_point: Vector2 = _camera.screen_to_world(event.position)
		if event.pressed:
			if _players[local_slot].hangar_defenders > 0 and _homes[local_slot].can_deploy_at(world_point):
				_dragging = true
				_drag_start = world_point
				_drag_indicator.update_drag(true, "arrow", world_point, world_point, _players[local_slot].color())
			elif _homes[local_slot].can_deploy_at(world_point):
				_hud.show_notice("BUY A DEFENDER IN THE SHOP (B) FIRST")
		elif _dragging:
			_dragging = false
			_drag_indicator.update_drag(false)
			var facing: float = _homes[local_slot].position.angle_to_point(_drag_start)
			if _drag_start.distance_to(world_point) > MIN_DRAG_LENGTH:
				facing = _drag_start.angle_to_point(world_point)
			MatchNetwork.send_command("deploy", {"x": _drag_start.x, "y": _drag_start.y, "rot": facing})
	elif event is InputEventMouseMotion and _dragging:
		_drag_indicator.update_drag(true, "arrow", _drag_start, _camera.screen_to_world(event.position), _players[local_slot].color())

func _toggle_ready():
	if _authority.phase == MATCH_CONFIG.Phase.SETUP:
		MatchNetwork.send_command("ready")

func _request_pause():
	if _authority.phase != MATCH_CONFIG.Phase.OVER:
		MatchNetwork.send_command("pause", {"on": true})

func _show_tutorial():
	if is_instance_valid(_tutorial):
		return
	_tutorial = TUTORIAL.new()
	_tutorial.lines = TUTORIAL_LINES.lines()
	_tutorial.voice_dir = TUTORIAL_LINES.VOICE_DIR
	_tutorial.show_visuals = false
	_tutorial.final_hint = "CLICK TO CLOSE"
	add_child(_tutorial)

func _open_workspace():
	if _workspace_layer != null or _over:
		return
	_hud.close_panels()
	_workspace_layer = CanvasLayer.new()
	_workspace_layer.layer = 20
	add_child(_workspace_layer)
	var editor = WORKSPACE_SCENE.instantiate()
	editor.embedded = true
	editor.programs = _players[local_slot].programs
	editor.program_changed.connect(_on_program_changed)
	editor.closed.connect(_close_workspace)
	_workspace_layer.add_child(editor)

func _close_workspace():
	if _workspace_layer != null:
		_workspace_layer.queue_free()
		_workspace_layer = null

func _on_program_changed(role: int, scripts: Array):
	_players[local_slot].programs[role] = scripts
	MatchNetwork.send_command("program", {"role": role, "scripts": scripts})

func _on_sim_notice(slot: int, text: String):
	if slot == local_slot:
		_hud.show_notice(text)
	else:
		MatchNetwork.broadcast_event("notice", {"text": text})

func _on_sim_explosion(point: Vector2, blast_size: float):
	_spawn_explosion(point, blast_size)
	MatchNetwork.broadcast_event("explosion", {"x": point.x, "y": point.y, "size": blast_size})

func _on_sim_match_over(result: Dictionary):
	MatchNetwork.broadcast_event("over", result)
	_show_result(result)

func _on_network_event(kind: String, payload: Dictionary):
	match kind:
		"notice":
			_hud.show_notice(str(payload.get("text", "")))
		"explosion":
			_spawn_explosion(Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0))), float(payload.get("size", 48.0)))
		"over":
			_show_result(payload)

func _spawn_explosion(point: Vector2, blast_size: float):
	if mode == MATCH_CONFIG.Mode.FOG and not _point_visible(point):
		return
	var blast = EXPLOSION.new()
	blast.display_size = blast_size
	blast.position = point
	add_child(blast)

func _point_visible(point: Vector2) -> bool:
	if point.distance_to(_homes[local_slot].position) <= MATCH_CONFIG.HOME_VISION:
		return true
	for ship in _authority.ships.values():
		if is_instance_valid(ship) and ship.owner_slot == local_slot and point.distance_to(ship.global_position) <= ship.vision_radius():
			return true
	return false

func _show_result(result: Dictionary):
	if _over:
		return
	_over = true
	_close_workspace()
	_pause_menu.hide_menu()
	_hud.close_panels()
	_result_panel.show_result(result, local_slot)

func _on_opponent_left():
	if _over:
		return
	if is_host:
		_authority.finish(local_slot, "left")
		return
	var stats: Array = []
	for player in _players:
		stats.append(player.to_dict())
	_show_result({"winner": local_slot, "reason": "left", "players": stats})

func _leave():
	_over = true
	MatchNetwork.close()
	if is_instance_valid(_music):
		_music.stop()
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _start_music():
	var stream := load("res://assets/music/RIDLEY_4.mp3") as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.bus = "Music"
	add_child(_music)
	_music.play()
