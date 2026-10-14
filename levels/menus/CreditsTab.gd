extends PanelContainer

const WEBSITE_URL := "https://astroswarm.autonomousrobotics.club"

const HEADING_COLOR := Color(0.93, 0.94, 1, 1)
const BODY_COLOR := Color(0.6, 0.62, 0.74, 1)
const NOTE_COLOR := Color(0.45, 0.45, 0.51, 1)

const CREDIT_SECTIONS := [
	{
		"title": "AstroSwarm",
		"entries": [
			["Made by", "Create Lab"],
			["Development", "SirBlobby, YousifA2"],
			["Music", "Cole Peterson (Ogel-Dev)"],
		],
	},
]

func _ready():
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	for section in CREDIT_SECTIONS:
		_add_section(content, section)
		content.add_child(HSeparator.new())

	_add_website_link(content)

func _add_section(content: VBoxContainer, section: Dictionary):
	content.add_child(_make_label(section["title"], 24, HEADING_COLOR))
	for entry in section["entries"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var role_label := _make_label(entry[0], 18, HEADING_COLOR)
		role_label.custom_minimum_size = Vector2(240, 0)
		row.add_child(role_label)
		var name_label := _make_label(entry[1], 18, BODY_COLOR)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(name_label)
		content.add_child(row)

func _add_website_link(content: VBoxContainer):
	content.add_child(_make_label("Website", 24, HEADING_COLOR))
	content.add_child(_make_label("Leaderboards, entries, downloads and the full game manual.", 18, BODY_COLOR))

	var website_button := Button.new()
	website_button.text = " Open Website "
	website_button.focus_mode = Control.FOCUS_NONE
	website_button.add_theme_font_size_override("font_size", 18)
	website_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	website_button.pressed.connect(func(): OS.shell_open(WEBSITE_URL))
	content.add_child(website_button)

	content.add_child(_make_label(WEBSITE_URL, 15, NOTE_COLOR))

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
