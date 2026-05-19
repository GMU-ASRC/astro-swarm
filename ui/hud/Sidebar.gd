extends CanvasLayer

signal open_workspace
signal request_clear

@onready var panel: PanelContainer = $Panel
@onready var type_box: VBoxContainer = $Panel/VBox/TypeBox
@onready var workspace_btn: Button = $Panel/VBox/WorkspaceButton
@onready var clear_btn: Button = $Panel/VBox/ClearButton
@onready var add_species_btn: Button = $Panel/VBox/AddSpeciesButton
@onready var setup_btn: Button = $Panel/VBox/SetupButton
@onready var settings_btn: Button = $Panel/VBox/SettingsButton
@onready var back_btn: Button = $Panel/VBox/BackButton

func _ready():
	_build_type_palette()
	workspace_btn.pressed.connect(func(): open_workspace.emit())
	clear_btn.pressed.connect(func(): request_clear.emit())
	add_species_btn.pressed.connect(_on_add_species)
	setup_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/SaveManagerScene.tscn"))
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/HomeScene.tscn"))
	SimulationManager.species_list_changed.connect(_build_type_palette)

func _process(_delta):
	var should_hide: bool = SimulationManager.has_started and not get_tree().paused
	panel.visible = not should_hide

func _build_type_palette():
	for child in type_box.get_children():
		child.queue_free()
	var group := ButtonGroup.new()
	for t in SimulationManager.robot_types:
		var btn := Button.new()
		btn.text = t.name
		btn.toggle_mode = true
		btn.button_group = group
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_color_override("font_color", t.color)
		btn.add_theme_color_override("font_hover_color", t.color)
		btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		var sb := StyleBoxFlat.new()
		sb.bg_color = t.color
		sb.border_color = t.color
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("hover_pressed", sb)
		var type_id: String = t.id
		btn.pressed.connect(func(): SimulationManager.set_selected_type(type_id))
		if t.id == SimulationManager.selected_type_id:
			btn.button_pressed = true
		type_box.add_child(btn)

func _on_add_species():
	var n: int = SimulationManager.robot_types.size() + 1
	var hue: float = fmod(n * 0.618033988, 1.0)
	var color := Color.from_hsv(hue, 0.55, 0.70)
	var new_id := SimulationManager.add_species("Species %d" % n, color)
	SimulationManager.set_selected_type(new_id)
