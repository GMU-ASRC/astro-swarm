extends Control

const MOON := preload("res://entities/planet/PlanetMoon.tscn")
const SHIP_WORKSPACE := preload("res://ui/workspace/ShipWorkspace.gd")

const MOON_VIS_PIXELS := 52.0
const MOON_DISP := 300.0
const SLOT_WIDTH := 360.0
const TAG_FONT_SIZE := 20
const DESC_FONT_SIZE := 14
const TAG_PADDING_X := 22
const TAG_PADDING_Y := 9
const HOVER_SCALE := 1.08

const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)
const C_ACCENT := Color(0.451, 0.616, 1.0, 1.0)
const C_TAG := Color(0.129, 0.122, 0.196, 1.0)
const C_TAG_HOVER := Color(0.18, 0.171, 0.275, 1.0)
const C_TAG_EDGE := Color(0.318, 0.306, 0.463, 1.0)

@onready var viewport: Control = $Viewport
@onready var moon_row: HBoxContainer = $Viewport/MoonRow
@onready var moon_slider: HSlider = $MoonSlider
@onready var back_btn: Button = $BackButton

func _ready():
	get_tree().paused = false
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/PlayerBaseScene.tscn"))
	moon_slider.value_changed.connect(_on_slider)
	get_viewport().size_changed.connect(_relayout)
	_build_moons()
	_relayout()

func _build_moons():
	for c in moon_row.get_children():
		c.queue_free()
	_add_moon(PlayerData.WORKSPACE_MOON_SEED, "Hivemind", "Program your spaceship", _open_workspace)
	for sd in PlayerData.moon_seeds:
		_add_moon(int(sd), "Outpost Moon", "Coming soon", Callable())

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

func _add_moon(moon_seed: int, title: String, desc: String, on_open: Callable):
	var openable: bool = on_open.is_valid()
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(SLOT_WIDTH, 0)
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	var moon_center := CenterContainer.new()
	moon_center.custom_minimum_size = Vector2(0, MOON_DISP * HOVER_SCALE)
	moon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(moon_center)
	var moon_visual: Control = _make_moon_visual(moon_seed)
	moon_center.add_child(moon_visual)

	var tag := PanelContainer.new()
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("panel", _tag_style(false, openable))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_label := _label(title.to_upper(), TAG_FONT_SIZE, C_TEXT if openable else C_DIM)
	tag.add_child(tag_label)
	column.add_child(tag)
	column.add_child(_label(desc, DESC_FONT_SIZE, C_DIM))

	if openable:
		moon_visual.mouse_filter = Control.MOUSE_FILTER_STOP
		moon_visual.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		moon_visual.tooltip_text = "Open %s" % title
		moon_visual.mouse_entered.connect(func(): _set_moon_hover(moon_visual, tag, true))
		moon_visual.mouse_exited.connect(func(): _set_moon_hover(moon_visual, tag, false))
		moon_visual.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				on_open.call()
		)
	moon_row.add_child(column)

func _set_moon_hover(moon_visual: Control, tag: PanelContainer, hovered: bool):
	moon_visual.pivot_offset = moon_visual.size * 0.5
	moon_visual.scale = Vector2.ONE * (HOVER_SCALE if hovered else 1.0)
	tag.add_theme_stylebox_override("panel", _tag_style(hovered, true))

func _open_workspace():
	SHIP_WORKSPACE.return_scene = "res://levels/menus/PlayerBaseScene.tscn"
	get_tree().change_scene_to_file("res://ui/workspace/ShipWorkspace.tscn")

func _tag_style(hovered: bool, openable: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = C_TAG_HOVER if hovered else C_TAG
	style.border_color = C_ACCENT if (hovered or openable) else C_TAG_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = TAG_PADDING_X
	style.content_margin_right = TAG_PADDING_X
	style.content_margin_top = TAG_PADDING_Y
	style.content_margin_bottom = TAG_PADDING_Y
	return style

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

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

func _disable_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_disable_mouse(c)
