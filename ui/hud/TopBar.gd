extends CanvasLayer

signal request_stop
signal request_clear
signal open_workspace

@onready var panel: PanelContainer = $Panel
@onready var back_btn:    Button = $Panel/HBox/BackBtn
@onready var setup_btn:   Button = $Panel/HBox/SetupBtn
@onready var workspace_btn:Button = $Panel/HBox/WorkspaceBtn
@onready var clear_btn:   Button = $Panel/HBox/ClearBtn
@onready var settings_btn: Button = $Panel/HBox/SettingsBtn
@onready var tool_box:    HBoxContainer = $Panel/HBox/ToolBox
@onready var species_box: HBoxContainer = $Panel/HBox/SpeciesBox
@onready var add_species_btn: Button = $Panel/HBox/AddSpeciesBtn
@onready var time_label:  Label = $Panel/HBox/TimeLabel
@onready var replay_slider: HSlider = $Panel/HBox/ReplaySlider
@onready var count_label: Label = $Panel/HBox/CountLabel
@onready var play_btn:    Button = $Panel/HBox/PlayButton
@onready var stop_btn:    Button = $Panel/HBox/StopButton
@onready var speed_1x:    Button = $Panel/HBox/SpeedBox/Speed1x
@onready var speed_2x:    Button = $Panel/HBox/SpeedBox/Speed2x
@onready var speed_3x:    Button = $Panel/HBox/SpeedBox/Speed3x

var _last_paused: bool = true
var _last_started: bool = false
var _is_slider_dragging: bool = false
var _export_mode: bool = false
var _tool_buttons: Dictionary = {}
var _species_buttons: Dictionary = {}

const TOOLS := [
	{"id": "place_robot", "icon": "☰", "tip": "Place Robots"},
	{"id": "measure",     "icon": "📏", "tip": "Measure"},
	{"id": "wall",        "icon": "▢", "tip": "Wall"},
	{"id": "obstacle",    "icon": "◯", "tip": "Obstacle"},
]

func _ready():
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/HomeScene.tscn"))
	setup_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/SaveManagerScene.tscn"))
	workspace_btn.pressed.connect(func(): open_workspace.emit())
	clear_btn.pressed.connect(func(): request_clear.emit())
	settings_btn.pressed.connect(_on_settings)
	add_species_btn.pressed.connect(_on_add_species)

	play_btn.pressed.connect(_on_play_pressed)
	stop_btn.pressed.connect(func(): request_stop.emit())
	speed_1x.pressed.connect(func(): _set_speed(1.0))
	speed_2x.pressed.connect(func(): _set_speed(2.0))
	speed_3x.pressed.connect(func(): _set_speed(3.0))

	replay_slider.drag_started.connect(func(): _is_slider_dragging = true)
	replay_slider.drag_ended.connect(func(_vc): _is_slider_dragging = false)
	replay_slider.value_changed.connect(_on_slider_changed)

	SimulationManager.species_list_changed.connect(_build_species_swatches)
	SimulationManager.selected_type_changed.connect(_on_selected_type_changed)
	SimulationManager.tool_changed.connect(_on_tool_changed)

	_build_tool_buttons()
	_build_species_swatches()
	_refresh_play_text()
	_refresh_speed_buttons()

func _on_settings():
	var arena = get_tree().current_scene
	if arena and arena.has_node("ArenaSettingsModal"):
		arena.get_node("ArenaSettingsModal").open()
	elif arena and arena.has_method("open_settings_modal"):
		arena.open_settings_modal()

func _process(_delta):
	if SimulationManager.is_replaying:
		time_label.text = _fmt(SimulationManager.replay_time)
		if not _export_mode:
			replay_slider.visible = true
			count_label.visible = false
			if not _is_slider_dragging:
				var max_time: float = SimulationManager.current_replay.size() * SimulationManager.RECORD_INTERVAL
				replay_slider.max_value = max_time
				replay_slider.value = SimulationManager.replay_time
	else:
		time_label.text = _fmt(SimulationManager.simulation_time)
		if not _export_mode:
			replay_slider.visible = false
			count_label.visible = true

	if _export_mode:
		return

	count_label.text = "%d" % get_tree().get_nodes_in_group("robots").size()
	if get_tree().paused != _last_paused or SimulationManager.has_started != _last_started:
		_last_paused = get_tree().paused
		_last_started = SimulationManager.has_started
		_refresh_play_text()

func _build_tool_buttons():
	for child in tool_box.get_children():
		child.queue_free()
	_tool_buttons.clear()
	for t in TOOLS:
		var btn := _make_toolbar_btn(t.icon, t.tip)
		var tool_id: String = t.id
		btn.toggle_mode = true
		btn.button_pressed = (tool_id == SimulationManager.active_tool)
		btn.pressed.connect(func(): SimulationManager.set_active_tool(tool_id))
		tool_box.add_child(btn)
		_tool_buttons[tool_id] = btn

func _on_tool_changed(tool_id: String):
	for id in _tool_buttons.keys():
		_tool_buttons[id].set_pressed_no_signal(id == tool_id)
	for id in _species_buttons.keys():
		var is_selected: bool = (tool_id == "place_robot" and id == SimulationManager.selected_type_id)
		_species_buttons[id].set_pressed_no_signal(is_selected)

func _on_selected_type_changed(type_id: String):
	for id in _species_buttons.keys():
		_species_buttons[id].set_pressed_no_signal(id == type_id and SimulationManager.active_tool == "place_robot")

func _build_species_swatches():
	for child in species_box.get_children():
		child.queue_free()
	_species_buttons.clear()
	for t in SimulationManager.robot_types:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(22, 22)
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.tooltip_text = t.name
		btn.text = ""
		var color: Color = t.color
		_style_species_btn(btn, color, false)
		var type_id: String = t.id
		btn.toggled.connect(func(pressed):
			if pressed:
				SimulationManager.set_selected_type(type_id)
				SimulationManager.set_active_tool("place_robot")
			_style_species_btn(btn, color, pressed)
		)
		var should_press: bool = (SimulationManager.active_tool == "place_robot" and t.id == SimulationManager.selected_type_id)
		btn.button_pressed = should_press
		_style_species_btn(btn, color, should_press)
		species_box.add_child(btn)
		_species_buttons[t.id] = btn

func _style_species_btn(btn: Button, color: Color, pressed: bool):
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	sb.set_border_width_all(2 if pressed else 1)
	sb.border_color = Color(0.137, 0.137, 0.196, 1.0) if pressed else color.darkened(0.25)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("hover_pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)

func _make_toolbar_btn(icon: String, tip: String) -> Button:
	var btn := Button.new()
	btn.text = icon
	btn.tooltip_text = tip
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 13)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.945, 0.945, 0.957, 1.0)
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.722, 0.722, 0.745, 1.0)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	var sb_hov := sb.duplicate() as StyleBoxFlat
	sb_hov.bg_color = Color(0.918, 0.937, 0.969, 1.0)
	sb_hov.border_color = Color(0.251, 0.447, 0.835, 1.0)
	var sb_press := sb.duplicate() as StyleBoxFlat
	sb_press.bg_color = Color(0.176, 0.341, 0.714, 1.0)
	sb_press.border_color = Color(0.118, 0.247, 0.58, 1.0)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hov)
	btn.add_theme_stylebox_override("pressed", sb_press)
	btn.add_theme_stylebox_override("hover_pressed", sb_press)
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_pressed_color", Color(1, 1, 1, 1))
	return btn

func _on_add_species():
	var n: int = SimulationManager.robot_types.size() + 1
	var hue: float = fmod(n * 0.618033988, 1.0)
	var color := Color.from_hsv(hue, 0.55, 0.70)
	var new_id := SimulationManager.add_species("Species %d" % n, color)
	SimulationManager.set_selected_type(new_id)
	SimulationManager.set_active_tool("place_robot")

func _on_slider_changed(val: float):
	if _is_slider_dragging:
		SimulationManager.replay_time = val

func _on_play_pressed():
	if not SimulationManager.has_started:
		SimulationManager.has_started = true
		if not SimulationManager.is_replaying:
			SimulationManager.start_recording()
	get_tree().paused = not get_tree().paused

func _set_speed(scale: float):
	SimulationManager.update_setting("time_scale", scale)
	_refresh_speed_buttons()

func _refresh_speed_buttons():
	var ts: float = SimulationManager.settings.time_scale
	speed_1x.disabled = is_equal_approx(ts, 1.0)
	speed_2x.disabled = is_equal_approx(ts, 2.0)
	speed_3x.disabled = is_equal_approx(ts, 3.0)

func _refresh_play_text():
	stop_btn.visible = SimulationManager.has_started and not get_tree().paused
	if not SimulationManager.has_started or get_tree().paused:
		play_btn.text = "▶"
		play_btn.tooltip_text = "Start" if not SimulationManager.has_started else "Resume"
	else:
		play_btn.text = "⏸"
		play_btn.tooltip_text = "Pause"

func _fmt(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%02d:%02d" % [m, s]

func set_minimal_for_export(enabled: bool):
	_export_mode = enabled
	for child in $Panel/HBox.get_children():
		if child == time_label or child == play_btn or child == stop_btn:
			continue
		child.visible = not enabled
	replay_slider.visible = not enabled
	count_label.visible = not enabled
