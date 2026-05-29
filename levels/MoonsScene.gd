extends Control

const MOON := preload("res://entities/planet/PlanetMoon.tscn")

const WORKSPACE_MOON_SEED := 424242
const MOON_VIS_PIXELS := 52.0
const MOON_DISP := 124.0
const CARD_WIDTH := 210.0

@onready var viewport: Control = $Viewport
@onready var moon_row: HBoxContainer = $Viewport/MoonRow
@onready var moon_slider: HSlider = $MoonSlider
@onready var back_btn: Button = $BackButton

func _ready():
	get_tree().paused = false
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/PlayerBaseScene.tscn"))
	moon_slider.value_changed.connect(_on_slider)
	get_viewport().size_changed.connect(_relayout)
	_build_moons()
	_relayout()

func _build_moons():
	for c in moon_row.get_children():
		c.queue_free()
	_add_card(WORKSPACE_MOON_SEED, "Workspace Moon", "Program your spaceship", true)
	for sd in PlayerData.moon_seeds:
		_add_card(int(sd), "Outpost Moon", "Coming soon", false)

func _relayout():
	await get_tree().process_frame
	if not is_instance_valid(viewport):
		return
	var content: Vector2 = moon_row.get_combined_minimum_size()
	moon_row.size = content
	var view_w: float = viewport.size.x
	var view_h: float = viewport.size.y
	moon_row.position.y = max(0.0, (view_h - content.y) * 0.5)
	if content.x <= view_w:
		moon_slider.visible = false
		moon_row.position.x = (view_w - content.x) * 0.5
	else:
		moon_slider.visible = true
		moon_slider.min_value = 0.0
		moon_slider.max_value = content.x - view_w
		moon_slider.value = clampf(moon_slider.value, 0.0, moon_slider.max_value)
		moon_row.position.x = -moon_slider.value

func _on_slider(value: float):
	moon_row.position.x = -value

func _add_card(moon_seed: int, title: String, desc: String, is_workspace: bool):
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_theme_stylebox_override("panel", _card_style())

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(0, MOON_DISP)
	center.add_child(_make_moon_visual(moon_seed))
	vbox.add_child(center)

	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.93, 0.94, 1, 1))
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.74, 1))
	vbox.add_child(desc_label)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	if is_workspace:
		btn.text = "OPEN"
		btn.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/workspace/ShipWorkspace.tscn"))
	else:
		btn.text = "LOCKED"
		btn.disabled = true
	vbox.add_child(btn)

	moon_row.add_child(card)

func _make_moon_visual(moon_seed: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(MOON_DISP, MOON_DISP)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var moon := MOON.instantiate() as Control
	holder.add_child(moon)
	moon.generate(moon_seed, MOON_VIS_PIXELS)
	var sc: float = MOON_DISP / MOON_VIS_PIXELS
	moon.scale = Vector2(sc, sc)
	moon.position = Vector2.ZERO
	_disable_mouse(moon)
	return holder

func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.094, 0.16, 1)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.318, 0.306, 0.463, 1)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb

func _disable_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_disable_mouse(c)
