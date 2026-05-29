extends Control

@onready var vsync_check = $VBox/TabContainer/Graphics/Margin/VBox/VSyncCheck
@onready var fps_option = $VBox/TabContainer/Graphics/Margin/VBox/FpsOption
@onready var msaa_option = $VBox/TabContainer/Graphics/Margin/VBox/MsaaOption
@onready var window_mode_option = $VBox/TabContainer/Display/Margin/VBox/WindowModeOption
@onready var resolution_option = $VBox/TabContainer/Display/Margin/VBox/ResolutionOption
@onready var display_apply_btn = $VBox/TabContainer/Display/Margin/VBox/DisplayApply
@onready var graphics_apply_btn = $VBox/TabContainer/Graphics/Margin/VBox/GraphicsApply
@onready var reset_game_btn = $VBox/TabContainer/Player/Margin/VBox/ResetButton
@onready var reset_modal: Control = $ResetModal
@onready var reset_cancel_btn: Button = $ResetModal/Panel/VBox/Buttons/CancelButton
@onready var reset_confirm_btn: Button = $ResetModal/Panel/VBox/Buttons/ConfirmButton
@onready var device_option = $VBox/TabContainer/Sound/Margin/VBox/DeviceOption
@onready var master_vol_slider = $VBox/TabContainer/Sound/Margin/VBox/MasterVolHBox/Slider
@onready var master_vol_label = $VBox/TabContainer/Sound/Margin/VBox/MasterVolHBox/ValueLabel
@onready var music_vol_slider = $VBox/TabContainer/Sound/Margin/VBox/MusicVolHBox/Slider
@onready var music_vol_label = $VBox/TabContainer/Sound/Margin/VBox/MusicVolHBox/ValueLabel
@onready var sfx_vol_slider = $VBox/TabContainer/Sound/Margin/VBox/SfxVolHBox/Slider
@onready var sfx_vol_label = $VBox/TabContainer/Sound/Margin/VBox/SfxVolHBox/ValueLabel
@onready var bind_list: VBoxContainer = $VBox/TabContainer/Keybinds/Margin/VBox/Scroll/BindList
@onready var reset_binds_btn: Button = $VBox/TabContainer/Keybinds/Margin/VBox/ResetButton
@onready var back_btn = $VBox/TopBar/BackButton

var _capturing_action: String = ""
var _capturing_btn: Button = null

func _ready():
	back_btn.pressed.connect(_on_back)

	window_mode_option.select(PlayerSettings.get_window_mode_idx())
	window_mode_option.item_selected.connect(func(_idx): _update_resolution_enabled())

	_populate_resolutions()
	_update_resolution_enabled()
	display_apply_btn.pressed.connect(_on_display_apply)

	vsync_check.button_pressed = PlayerSettings.get_vsync()
	fps_option.select(PlayerSettings.get_fps_idx())
	msaa_option.select(PlayerSettings.get_msaa_idx())
	graphics_apply_btn.pressed.connect(_on_graphics_apply)

	reset_game_btn.pressed.connect(_on_reset_pressed)
	reset_cancel_btn.pressed.connect(func(): reset_modal.visible = false)
	reset_confirm_btn.pressed.connect(_on_reset_confirmed)

	var devices := AudioServer.get_output_device_list()
	var saved_device := PlayerSettings.get_device()
	for i in devices.size():
		device_option.add_item(devices[i])
		if devices[i] == saved_device:
			device_option.select(i)
	device_option.item_selected.connect(func(idx): PlayerSettings.set_device(device_option.get_item_text(idx)))

	_init_bus_slider("Master", master_vol_slider, master_vol_label)
	_init_bus_slider("Music", music_vol_slider, music_vol_label)
	_init_bus_slider("SFX", sfx_vol_slider, sfx_vol_label)

	master_vol_slider.value_changed.connect(func(v): _on_bus_changed("Master", v, master_vol_label))
	music_vol_slider.value_changed.connect(func(v): _on_bus_changed("Music", v, music_vol_label))
	sfx_vol_slider.value_changed.connect(func(v): _on_bus_changed("SFX", v, sfx_vol_label))

	reset_binds_btn.pressed.connect(_on_reset_binds)
	_build_keybind_rows()

func _populate_resolutions():
	resolution_option.clear()
	for i in PlayerSettings.RESOLUTIONS.size():
		var res: Vector2i = PlayerSettings.RESOLUTIONS[i]
		resolution_option.add_item("%d x %d" % [res.x, res.y], i)
	resolution_option.select(PlayerSettings.get_resolution_idx())

func _update_resolution_enabled():
	resolution_option.disabled = window_mode_option.selected != 0

func _on_display_apply():
	PlayerSettings.set_window_mode(window_mode_option.selected)
	PlayerSettings.set_resolution(resolution_option.selected)

func _on_graphics_apply():
	PlayerSettings.set_vsync(vsync_check.button_pressed)
	PlayerSettings.set_fps(fps_option.selected)
	PlayerSettings.set_msaa(msaa_option.selected)

func _on_reset_pressed():
	reset_modal.visible = true

func _on_reset_confirmed():
	PlayerData.reset_game()
	reset_modal.visible = false

func _init_bus_slider(bus_name: String, slider: HSlider, label: Label):
	var val: float = PlayerSettings.get_bus_volume(bus_name)
	slider.value = val
	label.text = "%d%%" % int(val)

func _on_bus_changed(bus_name: String, val: float, label: Label):
	label.text = "%d%%" % int(val)
	PlayerSettings.set_bus_volume(bus_name, val)

func _build_keybind_rows():
	for child in bind_list.get_children():
		child.queue_free()
	for action in PlayerSettings.DEFAULT_KEYBINDS.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := Label.new()
		name_label.text = PlayerSettings.KEYBIND_LABELS.get(action, action)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(180, 0)
		btn.text = _keycode_label(PlayerSettings.get_keybind(action))
		var act: String = action
		btn.pressed.connect(func(): _start_capture(act, btn))
		row.add_child(btn)
		bind_list.add_child(row)

func _keycode_label(keycode: int) -> String:
	if keycode == 0:
		return "Unbound"
	return OS.get_keycode_string(keycode)

func _start_capture(action: String, btn: Button):
	if _capturing_btn != null:
		_capturing_btn.text = _keycode_label(PlayerSettings.get_keybind(_capturing_action))
	_capturing_action = action
	_capturing_btn = btn
	btn.text = "Press a key…"

func _input(event: InputEvent):
	if _capturing_action == "" or _capturing_btn == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode
		accept_event()
		if kc == KEY_ESCAPE:
			_capturing_btn.text = _keycode_label(PlayerSettings.get_keybind(_capturing_action))
		else:
			PlayerSettings.set_keybind(_capturing_action, kc)
			_capturing_btn.text = _keycode_label(kc)
		_capturing_action = ""
		_capturing_btn = null

func _on_reset_binds():
	PlayerSettings.reset_keybinds()
	_build_keybind_rows()

func _on_back():
	get_tree().change_scene_to_file("res://levels/HomeScene.tscn")
