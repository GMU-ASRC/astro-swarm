extends Control

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")
const STARFIELD := preload("res://ui/game/Starfield.gd")
const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")
const LICENSE_CARD := preload("res://ui/astroid/LicenseCard.gd")
const ACHIEVEMENTS := preload("res://achievements/Achievements.gd")

const BASE_SCENE := "res://levels/menus/PlayerBaseScene.tscn"

const C_BG := Color(0.035, 0.031, 0.059, 1.0)
const C_PANEL := Color(0.129, 0.122, 0.196, 1.0)
const C_PANEL_EDGE := Color(0.318, 0.306, 0.463, 1.0)
const C_SLOT := Color(0.16, 0.149, 0.243, 1.0)
const C_ACCENT := Color(0.451, 0.616, 1.0, 1.0)
const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)

const PANEL_WIDTH := 760.0
const BADGE_SIZE := 80.0
const BADGE_COLUMNS := 3
const SCREEN_MARGIN := 16.0

func _ready():
	theme = GAME_THEME
	_build_background()
	_build_layout()

func _build_background():
	var fill := ColorRect.new()
	fill.color = C_BG
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fill)
	var starfield := Control.new()
	starfield.set_script(STARFIELD)
	add_child(starfield)

func _build_layout():
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	center.add_child(column)

	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, 16)
	column.add_child(top_gap)
	column.add_child(LICENSE_CARD.new())
	column.add_child(_build_endorsements())


	var bottom_gap := Control.new()
	bottom_gap.custom_minimum_size = Vector2(0, 16)
	column.add_child(bottom_gap)

	var back := HUD_BUTTONS.make("< BACK TO BASE", HUD_BUTTONS.Kind.BACK, 11)
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.position = Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
	back.pressed.connect(func(): get_tree().change_scene_to_file(BASE_SCENE))
	add_child(back)

func _build_endorsements() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_theme_stylebox_override("panel", _box(C_PANEL, C_PANEL_EDGE, 2, 22))
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 14)
	panel.add_child(section)
	section.add_child(_label("ENDORSEMENTS", 14, C_TEXT))

	var earned: Array = []
	for achievement in ACHIEVEMENTS.ALL:
		if PlayerData.has_achievement(achievement["id"]):
			earned.append(achievement)
	if earned.is_empty():
		var empty := _label("No badges yet. Finish levels to earn your first endorsement.", 10, C_DIM)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(empty)
		return panel

	var grid := GridContainer.new()
	grid.columns = BADGE_COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	section.add_child(grid)
	for achievement in earned:
		grid.add_child(_badge_tile(achievement))
	return panel

func _badge_tile(achievement: Dictionary) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", _box(C_SLOT, C_ACCENT, 2, 12))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)

	var icon := TextureRect.new()
	icon.texture = load(achievement["icon"])
	icon.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)

	var title := _label(achievement["title"], 11, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var description := _label(achievement["description"], 9, C_DIM)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	return tile

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _box(fill: Color, edge: Color, border: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(0)
	box.set_content_margin_all(padding)
	return box
