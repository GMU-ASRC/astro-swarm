extends Control

@onready var vsync_check = $VBox/TabContainer/Graphics/Margin/VBox/VSyncCheck
@onready var fps_option = $VBox/TabContainer/Graphics/Margin/VBox/FpsOption
@onready var msaa_option = $VBox/TabContainer/Graphics/Margin/VBox/MsaaOption
@onready var window_mode_option = $VBox/TabContainer/Display/Margin/VBox/WindowModeOption
@onready var device_option = $VBox/TabContainer/Sound/Margin/VBox/DeviceOption
@onready var master_vol_slider = $VBox/TabContainer/Sound/Margin/VBox/MasterVolHBox/Slider
@onready var master_vol_label = $VBox/TabContainer/Sound/Margin/VBox/MasterVolHBox/ValueLabel
@onready var music_vol_slider = $VBox/TabContainer/Sound/Margin/VBox/MusicVolHBox/Slider
@onready var music_vol_label = $VBox/TabContainer/Sound/Margin/VBox/MusicVolHBox/ValueLabel
@onready var sfx_vol_slider = $VBox/TabContainer/Sound/Margin/VBox/SfxVolHBox/Slider
@onready var sfx_vol_label = $VBox/TabContainer/Sound/Margin/VBox/SfxVolHBox/ValueLabel
@onready var back_btn = $VBox/TopBar/BackButton

func _ready():
	back_btn.pressed.connect(_on_back)

	var is_fullscreen = get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	window_mode_option.select(1 if is_fullscreen else 0)
	window_mode_option.item_selected.connect(_on_window_mode)

	var vsync = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	vsync_check.button_pressed = vsync
	vsync_check.toggled.connect(_on_vsync_toggled)

	var max_fps = Engine.max_fps
	if max_fps == 0:
		fps_option.select(0)
	elif max_fps == 60:
		fps_option.select(1)
	elif max_fps == 120:
		fps_option.select(2)
	elif max_fps == 144:
		fps_option.select(3)
	fps_option.item_selected.connect(_on_fps_mode)

	var msaa = get_viewport().msaa_2d
	if msaa == Viewport.MSAA_DISABLED:
		msaa_option.select(0)
	elif msaa == Viewport.MSAA_2X:
		msaa_option.select(1)
	elif msaa == Viewport.MSAA_4X:
		msaa_option.select(2)
	elif msaa == Viewport.MSAA_8X:
		msaa_option.select(3)
	msaa_option.item_selected.connect(_on_msaa_mode)

	var devices = AudioServer.get_output_device_list()
	var current_device = AudioServer.output_device
	for i in devices.size():
		device_option.add_item(devices[i])
		if devices[i] == current_device:
			device_option.select(i)
	device_option.item_selected.connect(_on_device_mode)

	_init_bus_slider("Master", master_vol_slider, master_vol_label)
	_init_bus_slider("Music", music_vol_slider, music_vol_label)
	_init_bus_slider("SFX", sfx_vol_slider, sfx_vol_label)

	master_vol_slider.value_changed.connect(_on_master_vol)
	music_vol_slider.value_changed.connect(_on_music_vol)
	sfx_vol_slider.value_changed.connect(_on_sfx_vol)

func _init_bus_slider(bus_name: String, slider: HSlider, label: Label):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		var current_db = AudioServer.get_bus_volume_db(bus_idx)
		var current_linear = db_to_linear(current_db) * 100.0
		slider.value = current_linear
		label.text = "%d%%" % int(current_linear)

func _on_window_mode(idx: int):
	if idx == 0:
		get_window().mode = Window.MODE_WINDOWED
	else:
		get_window().mode = Window.MODE_FULLSCREEN

func _on_vsync_toggled(toggled_on: bool):
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if toggled_on else DisplayServer.VSYNC_DISABLED)

func _on_fps_mode(idx: int):
	if idx == 0:
		Engine.max_fps = 0
	elif idx == 1:
		Engine.max_fps = 60
	elif idx == 2:
		Engine.max_fps = 120
	elif idx == 3:
		Engine.max_fps = 144

func _on_msaa_mode(idx: int):
	if idx == 0:
		get_viewport().msaa_2d = Viewport.MSAA_DISABLED
	elif idx == 1:
		get_viewport().msaa_2d = Viewport.MSAA_2X
	elif idx == 2:
		get_viewport().msaa_2d = Viewport.MSAA_4X
	elif idx == 3:
		get_viewport().msaa_2d = Viewport.MSAA_8X

func _on_device_mode(idx: int):
	AudioServer.output_device = device_option.get_item_text(idx)

func _on_master_vol(val: float):
	_set_bus_volume("Master", val, master_vol_label)

func _on_music_vol(val: float):
	_set_bus_volume("Music", val, music_vol_label)

func _on_sfx_vol(val: float):
	_set_bus_volume("SFX", val, sfx_vol_label)

func _set_bus_volume(bus_name: String, val: float, label: Label):
	label.text = "%d%%" % int(val)
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val / 100.0))

func _on_back():
	get_tree().change_scene_to_file("res://levels/HomeScene.tscn")
