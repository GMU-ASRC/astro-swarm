extends Node

const SETTINGS_PATH := "user://player_settings.cfg"

const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _cfg: ConfigFile = ConfigFile.new()
var _loaded: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg.load(SETTINGS_PATH)
	_loaded = true
	_apply_all()

func _apply_all():
	var mode_idx: int = _cfg.get_value("display", "window_mode", 0)
	apply_window_mode(mode_idx)
	apply_resolution(get_resolution_idx())

	var vsync_on: bool = _cfg.get_value("graphics", "vsync", true)
	apply_vsync(vsync_on)

	var fps_idx: int = _cfg.get_value("graphics", "fps_idx", 0)
	apply_fps(fps_idx)

	var msaa_idx: int = _cfg.get_value("graphics", "msaa_idx", 0)
	apply_msaa(msaa_idx)

	var device: String = _cfg.get_value("sound", "device", "Default")
	if device != "":
		AudioServer.output_device = device

	for bus_name in ["Master", "Music", "SFX"]:
		var val: float = _cfg.get_value("sound", bus_name.to_lower() + "_vol", 100.0)
		apply_bus_volume(bus_name, val)

	_apply_keybinds()

func _apply_keybinds():
	var actions = DEFAULT_KEYBINDS.keys()
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var stored: Array = _cfg.get_value("keybinds", action, [])
		if stored.is_empty():
			stored = DEFAULT_KEYBINDS[action]
		InputMap.action_erase_events(action)
		for keycode in stored:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)

const DEFAULT_KEYBINDS := {
	"robot_forward":   [KEY_W],
	"robot_backward":  [KEY_S],
	"robot_turn_left": [KEY_A],
	"robot_turn_right":[KEY_D],
	"release_control": [KEY_ESCAPE],
	"pan_camera":      [KEY_SPACE],
}

const KEYBIND_LABELS := {
	"robot_forward":   "Drive Forward",
	"robot_backward":  "Drive Backward",
	"robot_turn_left": "Turn Left",
	"robot_turn_right":"Turn Right",
	"release_control": "Release Controlled Robot",
	"pan_camera":      "Pan Camera (hold)",
}

func get_window_mode_idx() -> int:
	return _cfg.get_value("display", "window_mode", 0)

func get_resolution_idx() -> int:
	return _cfg.get_value("display", "resolution_idx", 0)

func get_vsync() -> bool:
	return _cfg.get_value("graphics", "vsync", true)

func get_fps_idx() -> int:
	return _cfg.get_value("graphics", "fps_idx", 0)

func get_msaa_idx() -> int:
	return _cfg.get_value("graphics", "msaa_idx", 0)

func get_device() -> String:
	return _cfg.get_value("sound", "device", AudioServer.output_device)

func get_bus_volume(bus_name: String) -> float:
	return _cfg.get_value("sound", bus_name.to_lower() + "_vol", 100.0)

func get_keybind(action: String) -> int:
	var arr: Array = _cfg.get_value("keybinds", action, DEFAULT_KEYBINDS.get(action, []))
	if arr.is_empty():
		return 0
	return arr[0]

func set_window_mode(idx: int):
	_cfg.set_value("display", "window_mode", idx)
	apply_window_mode(idx)
	apply_resolution(get_resolution_idx())
	_save()

func set_resolution(idx: int):
	_cfg.set_value("display", "resolution_idx", idx)
	apply_resolution(idx)
	_save()

func set_vsync(on: bool):
	_cfg.set_value("graphics", "vsync", on)
	apply_vsync(on)
	_save()

func set_fps(idx: int):
	_cfg.set_value("graphics", "fps_idx", idx)
	apply_fps(idx)
	_save()

func set_msaa(idx: int):
	_cfg.set_value("graphics", "msaa_idx", idx)
	apply_msaa(idx)
	_save()

func set_device(name: String):
	_cfg.set_value("sound", "device", name)
	AudioServer.output_device = name
	_save()

func set_bus_volume(bus_name: String, val: float):
	_cfg.set_value("sound", bus_name.to_lower() + "_vol", val)
	apply_bus_volume(bus_name, val)
	_save()

func set_keybind(action: String, keycode: int):
	_cfg.set_value("keybinds", action, [keycode])
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
	_save()

func reset_keybinds():
	for action in DEFAULT_KEYBINDS.keys():
		_cfg.set_value("keybinds", action, DEFAULT_KEYBINDS[action])
	_apply_keybinds()
	_save()

func apply_window_mode(idx: int):
	if idx == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif idx == 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

func apply_resolution(idx: int):
	if idx < 0 or idx >= RESOLUTIONS.size():
		return
	if get_window_mode_idx() != 0:
		return
	var size: Vector2i = RESOLUTIONS[idx]
	DisplayServer.window_set_size(size)
	var screen: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
	var screen_pos: Vector2i = DisplayServer.screen_get_position(screen)
	DisplayServer.window_set_position(screen_pos + (screen_size - size) / 2)

func apply_vsync(on: bool):
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

func apply_fps(idx: int):
	match idx:
		0: Engine.max_fps = 0
		1: Engine.max_fps = 60
		2: Engine.max_fps = 120
		3: Engine.max_fps = 144
		_: Engine.max_fps = 0

func apply_msaa(idx: int):
	var mode: int = Viewport.MSAA_DISABLED
	match idx:
		1: mode = Viewport.MSAA_2X
		2: mode = Viewport.MSAA_4X
		3: mode = Viewport.MSAA_8X
		_: mode = Viewport.MSAA_DISABLED
	get_tree().root.msaa_2d = mode
	get_tree().root.msaa_3d = mode

func apply_bus_volume(bus_name: String, val: float):
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	if val <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val / 100.0))

func get_flag(key: String, default_value: bool = false) -> bool:
	return _cfg.get_value("progress", key, default_value)

func set_flag(key: String, value: bool):
	_cfg.set_value("progress", key, value)
	_save()

func _save():
	if not _loaded:
		return
	_cfg.save(SETTINGS_PATH)
