extends Control

signal closed

var embedded: bool = false

@onready var vsync_check = $VBox/TabContainer/Graphics/Margin/Scroll/VBox/VSyncCheck
@onready var fps_option = $VBox/TabContainer/Graphics/Margin/Scroll/VBox/FpsOption
@onready var msaa_option = $VBox/TabContainer/Graphics/Margin/Scroll/VBox/MsaaOption
@onready var window_mode_option = $VBox/TabContainer/Display/Margin/Scroll/VBox/WindowModeOption
@onready var resolution_option = $VBox/TabContainer/Display/Margin/Scroll/VBox/ResolutionOption
@onready var display_apply_btn = $VBox/TabContainer/Display/Margin/Scroll/VBox/DisplayApply
@onready var graphics_apply_btn = $VBox/TabContainer/Graphics/Margin/Scroll/VBox/GraphicsApply
@onready var player_vbox: VBoxContainer = $VBox/TabContainer/Player/Margin/Scroll/VBox
@onready var reset_game_btn = $VBox/TabContainer/Player/Margin/Scroll/VBox/ResetButton
@onready var reset_modal: Control = $ResetModal
@onready var reset_cancel_btn: Button = $ResetModal/Panel/VBox/Buttons/CancelButton
@onready var reset_confirm_btn: Button = $ResetModal/Panel/VBox/Buttons/ConfirmButton
@onready var device_option = $VBox/TabContainer/Sound/Margin/Scroll/VBox/DeviceOption
@onready var master_vol_slider = $VBox/TabContainer/Sound/Margin/Scroll/VBox/MasterVolHBox/Slider
@onready var master_vol_label = $VBox/TabContainer/Sound/Margin/Scroll/VBox/MasterVolHBox/ValueLabel
@onready var music_vol_slider = $VBox/TabContainer/Sound/Margin/Scroll/VBox/MusicVolHBox/Slider
@onready var music_vol_label = $VBox/TabContainer/Sound/Margin/Scroll/VBox/MusicVolHBox/ValueLabel
@onready var sfx_vol_slider = $VBox/TabContainer/Sound/Margin/Scroll/VBox/SfxVolHBox/Slider
@onready var sfx_vol_label = $VBox/TabContainer/Sound/Margin/Scroll/VBox/SfxVolHBox/ValueLabel
@onready var bind_list: VBoxContainer = $VBox/TabContainer/Keybinds/Margin/VBox/Scroll/BindList
@onready var reset_binds_btn: Button = $VBox/TabContainer/Keybinds/Margin/VBox/ResetButton
@onready var back_btn = $VBox/TopBar/BackButton

var _capturing_action: String = ""
var _capturing_btn: Button = null

var _callsign_edit: LineEdit
var _callsign_info: Label
var _planet_edit: LineEdit
var _planet_info: Label

func _ready():
	back_btn.pressed.connect(_on_back)
	_build_callsign_ui()
	_build_planet_name_ui()
	_build_dev_mode_ui()
	_build_text_size_ui()

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

func _build_text_size_ui():
	var display_vbox: VBoxContainer = window_mode_option.get_parent()
	var title := Label.new()
	title.text = "Text Size"

	var text_size_option := OptionButton.new()
	for i in PlayerSettings.TEXT_SIZES.size():
		text_size_option.add_item(PlayerSettings.TEXT_SIZES[i]["label"], i)
	text_size_option.select(PlayerSettings.get_text_size_idx())
	text_size_option.item_selected.connect(PlayerSettings.set_text_size)

	var hint := Label.new()
	hint.text = "Changes the size of text across the game. Applies right away."
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.51, 1))
	hint.add_theme_font_size_override("font_size", 11)

	var insert_index: int = display_vbox.get_node("DisplaySpacer").get_index()
	var nodes: Array = [title, text_size_option, hint]
	for i in nodes.size():
		display_vbox.add_child(nodes[i])
		display_vbox.move_child(nodes[i], insert_index + i)

func _on_display_apply():
	PlayerSettings.set_window_mode(window_mode_option.selected)
	PlayerSettings.set_resolution(resolution_option.selected)

func _on_graphics_apply():
	PlayerSettings.set_vsync(vsync_check.button_pressed)
	PlayerSettings.set_fps(fps_option.selected)
	PlayerSettings.set_msaa(msaa_option.selected)

func _build_callsign_ui():
	var title := Label.new()
	title.text = "Callsign"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.93, 0.94, 1, 1))

	var info := Label.new()
	info.text = "Change your callsign. Your player ID stays the same."
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.6, 0.62, 0.74, 1))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_callsign_edit = LineEdit.new()
	_callsign_edit.text = PlayerData.username
	_callsign_edit.placeholder_text = "Enter callsign"
	_callsign_edit.max_length = 30
	_callsign_edit.custom_minimum_size = Vector2(260, 0)
	_callsign_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_callsign_edit.text_submitted.connect(func(_text): _on_save_callsign())

	var save_btn := Button.new()
	save_btn.text = " Save Callsign "
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	save_btn.pressed.connect(_on_save_callsign)

	_callsign_info = Label.new()
	_callsign_info.text = "ID: %s" % PlayerData.player_id
	_callsign_info.add_theme_font_size_override("font_size", 11)
	_callsign_info.add_theme_color_override("font_color", Color(0.5, 0.52, 0.62, 1))

	var separator := HSeparator.new()

	var nodes: Array = [title, info, _callsign_edit, save_btn, _callsign_info, separator]
	for i in nodes.size():
		player_vbox.add_child(nodes[i])
		player_vbox.move_child(nodes[i], i)

func _build_dev_mode_ui():
	var title := Label.new()
	title.text = "Developer"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.93, 0.94, 1, 1))

	var info := Label.new()
	info.text = "Dev mode unlocks every level. With it off, each level unlocks after you finish the one before it."
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.6, 0.62, 0.74, 1))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var dev_mode_toggle := CheckButton.new()
	dev_mode_toggle.text = "Dev mode"
	dev_mode_toggle.focus_mode = Control.FOCUS_NONE
	dev_mode_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dev_mode_toggle.button_pressed = PlayerSettings.is_dev_mode()
	dev_mode_toggle.toggled.connect(PlayerSettings.set_dev_mode)

	var separator := HSeparator.new()

	var first_index: int = player_vbox.get_node("ResetTitle").get_index()
	var nodes: Array = [title, info, dev_mode_toggle, separator]
	for i in nodes.size():
		player_vbox.add_child(nodes[i])
		player_vbox.move_child(nodes[i], first_index + i)

func _build_planet_name_ui():
	var title := Label.new()
	title.text = "Planet Name"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.93, 0.94, 1, 1))

	var info := Label.new()
	info.text = "Name your home planet. Dr. Blob's voice lines use this name for your planet."
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.6, 0.62, 0.74, 1))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_planet_edit = LineEdit.new()
	_planet_edit.text = PlayerData.planet_name
	_planet_edit.placeholder_text = "Enter planet name"
	_planet_edit.max_length = PlayerData.PLANET_NAME_MAX_LENGTH
	_planet_edit.custom_minimum_size = Vector2(260, 0)
	_planet_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_planet_edit.text_submitted.connect(func(_text): _on_save_planet_name())

	var save_btn := Button.new()
	save_btn.text = " Save Planet Name "
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	save_btn.pressed.connect(_on_save_planet_name)

	_planet_info = Label.new()
	_planet_info.add_theme_font_size_override("font_size", 11)
	_planet_info.add_theme_color_override("font_color", Color(0.5, 0.52, 0.62, 1))

	var separator := HSeparator.new()

	var first_index: int = _callsign_info.get_index() + 2
	var nodes: Array = [title, info, _planet_edit, save_btn, _planet_info, separator]
	for i in nodes.size():
		player_vbox.add_child(nodes[i])
		player_vbox.move_child(nodes[i], first_index + i)

func _on_save_planet_name():
	var new_name: String = _planet_edit.text.strip_edges()
	if new_name == "":
		_planet_info.add_theme_color_override("font_color", Color(1, 0.55, 0.5, 1))
		_planet_info.text = "Planet name cannot be empty."
		return
	PlayerData.set_planet_name(new_name)
	_planet_edit.text = PlayerData.planet_name
	_planet_info.add_theme_color_override("font_color", Color(0.4, 0.85, 0.45, 1))
	_planet_info.text = "Saved as %s" % PlayerData.planet_name

func _on_save_callsign():
	var new_name: String = _callsign_edit.text.strip_edges()
	if new_name == "":
		_callsign_info.add_theme_color_override("font_color", Color(1, 0.55, 0.5, 1))
		_callsign_info.text = "Callsign cannot be empty."
		return
	PlayerData.set_username(new_name)
	_callsign_edit.text = PlayerData.username
	_callsign_info.add_theme_color_override("font_color", Color(0.4, 0.85, 0.45, 1))
	_callsign_info.text = "Saved as %s  (ID unchanged: %s)" % [PlayerData.username, PlayerData.player_id]

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
	if embedded:
		closed.emit()
		return
	get_tree().change_scene_to_file("res://levels/menus/HomeScene.tscn")
