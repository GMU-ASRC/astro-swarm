extends RefCounted

const BLOCK_SCRIPT := preload("res://ui/workspace/ScratchBlock.gd")

const GAME := {
	"background":   Color(0.086, 0.080, 0.129, 1.0),
	"bar":          Color(0.130, 0.120, 0.200, 1.0),
	"bar_edge":     Color(0.318, 0.306, 0.463, 1.0),
	"sidebar":      Color(0.110, 0.103, 0.168, 1.0),
	"board":        Color(0.067, 0.062, 0.106, 1.0),
	"board_edge":   Color(0.318, 0.306, 0.463, 1.0),
	"grid":         Color(1.0, 1.0, 1.0, 0.07),
	"header":       Color(0.129, 0.122, 0.196, 1.0),
	"accent":       Color(0.451, 0.616, 1.0, 1.0),
	"title":        Color(0.930, 0.940, 1.0, 1.0),
	"dim":          Color(0.500, 0.520, 0.620, 1.0),
	"section_title_darken": 0.0,
}

const SIMULATOR := {
	"background":   Color(0.835, 0.835, 0.859, 1.0),
	"bar":          Color(0.910, 0.910, 0.925, 1.0),
	"bar_edge":     Color(0.667, 0.667, 0.694, 1.0),
	"sidebar":      Color(0.880, 0.880, 0.900, 1.0),
	"board":        Color(0.957, 0.957, 0.969, 1.0),
	"board_edge":   Color(0.667, 0.667, 0.694, 1.0),
	"grid":         Color(0.0, 0.0, 0.0, 0.09),
	"header":       Color(0.945, 0.945, 0.957, 1.0),
	"accent":       Color(0.255, 0.463, 0.843, 1.0),
	"title":        Color(0.118, 0.118, 0.180, 1.0),
	"dim":          Color(0.450, 0.450, 0.510, 1.0),
	"section_title_darken": 0.3,
}

const SIDEBAR_WIDTH := 320.0
const SECTION_TITLE_SIZE := 19

static func apply(root: Control, colors: Dictionary):
	root.get_node("Background").color = colors.background
	_style_panel(root.get_node("TopBar"), _box(colors.bar, colors.bar_edge, [0, 0, 0, 2], [14, 10, 14, 10]))
	_color_label(root.get_node("TopBar/HBox/Title"), colors.title)
	_style_top_bar_fields(root.get_node("TopBar/HBox"), colors)
	_keep_body_below_top_bar(root.get_node("TopBar"), root.get_node("Body"))
	root.get_node("Body").split_offset = int(SIDEBAR_WIDTH)
	root.get_node("Body/Left").custom_minimum_size.x = SIDEBAR_WIDTH
	root.get_node("Body/Left/LeftVBox/PaletteScroll").horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_panel(root.get_node("Body/Left"), _box(colors.sidebar, colors.bar_edge, [0, 0, 2, 0], [12, 14, 8, 12]))
	_color_label(root.get_node("Body/Left/LeftVBox/PaletteTitle"), colors.title)
	_color_label(root.get_node("Body/Left/LeftVBox/PaletteHint"), colors.dim)
	root.get_node("Body/Left/LeftVBox/PaletteScroll/PaletteMargin/PaletteList").add_theme_constant_override("separation", 10)
	_style_panel(root.get_node("Body/Right"), _box(colors.background, colors.background, [0, 0, 0, 0], [16, 14, 16, 16]))
	_style_panel(root.get_node("Body/Right/RightVBox/HeaderBar"), _box(colors.header, colors.bar_edge, [1, 1, 1, 1], [12, 8, 12, 8]))
	_color_label(root.get_node("Body/Right/RightVBox/HeaderBar/Header/HintLabel"), colors.dim)
	var scroll: ScrollContainer = root.get_node("Body/Right/RightVBox/Scroll")
	scroll.add_theme_stylebox_override("panel", _box(colors.board, colors.board_edge, [2, 2, 2, 2], [2, 2, 2, 2]))
	var canvas = scroll.get_node("Canvas")
	canvas.grid_color = colors.grid
	canvas.queue_redraw()

static func _keep_body_below_top_bar(top_bar: Control, body: Control):
	var follow := func(): body.offset_top = top_bar.size.y
	top_bar.resized.connect(follow)
	follow.call()

static func _style_top_bar_fields(bar: Control, colors: Dictionary):
	for child in bar.get_children():
		if child is LineEdit:
			var slot := _box(colors.background, colors.bar_edge, [2, 2, 2, 2], [10, 4, 10, 4])
			child.add_theme_stylebox_override("normal", slot)
			child.add_theme_stylebox_override("focus", _box(colors.background, colors.accent, [2, 2, 2, 2], [10, 4, 10, 4]))
			child.add_theme_color_override("font_color", colors.title)
			child.add_theme_color_override("font_placeholder_color", colors.dim)
			child.add_theme_color_override("caret_color", colors.accent)

static func add_palette_section(palette_list: Control, title: String, category: String, colors: Dictionary) -> VBoxContainer:
	var category_color: Color = BLOCK_SCRIPT.CAT_COLORS.get(category, colors.accent)
	var section := PanelContainer.new()
	section.add_theme_stylebox_override("panel", _box(colors.sidebar, colors.sidebar, [0, 0, 0, 0], [4, 10, 4, 12]))
	palette_list.add_child(section)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	section.add_child(content)
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", SECTION_TITLE_SIZE)
	header.add_theme_color_override("font_color", category_color.darkened(colors.section_title_darken))
	content.add_child(header)
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", 6)
	content.add_child(items)
	return items

static func _style_panel(panel: PanelContainer, box: StyleBoxFlat):
	panel.add_theme_stylebox_override("panel", box)

static func _color_label(label: Label, color: Color):
	label.add_theme_color_override("font_color", color)

static func _box(fill: Color, edge: Color, borders: Array, margins: Array) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.border_width_left = borders[0]
	box.border_width_top = borders[1]
	box.border_width_right = borders[2]
	box.border_width_bottom = borders[3]
	box.content_margin_left = margins[0]
	box.content_margin_top = margins[1]
	box.content_margin_right = margins[2]
	box.content_margin_bottom = margins[3]
	box.set_corner_radius_all(0)
	return box
