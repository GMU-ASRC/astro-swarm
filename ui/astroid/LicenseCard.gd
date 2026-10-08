extends PanelContainer

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const TERRAN := preload("res://entities/planet/PlanetTerran.tscn")
const BARCODE := preload("res://ui/astroid/LicenseBarcode.gd")
const PROGRESS_BAR := preload("res://ui/astroid/RankProgressBar.gd")
const ACHIEVEMENTS := preload("res://achievements/Achievements.gd")
const RANKS := preload("res://progression/Ranks.gd")

const C_CARD := Color(0.129, 0.122, 0.196, 1.0)
const C_CARD_EDGE := Color(0.451, 0.616, 1.0, 1.0)
const C_BAND := Color(0.451, 0.616, 1.0, 1.0)
const C_BAND_TEXT := Color(0.05, 0.06, 0.12, 1.0)
const C_PHOTO_BG := Color(0.035, 0.031, 0.059, 1.0)
const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)
const C_FIELD_NUMBER := Color(0.451, 0.616, 1.0, 1.0)
const C_LINE := Color(0.318, 0.306, 0.463, 1.0)

const CARD_WIDTH := 760.0
const CORNER := 18
const PHOTO_SIZE := 170.0
const PLANET_PIXELS := 80.0
const ID_DIGITS := 8

func _ready():
	custom_minimum_size = Vector2(CARD_WIDTH, 0)
	add_theme_stylebox_override("panel", _card_style())
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)
	layout.add_child(_build_band())
	var body := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 22)
	layout.add_child(body)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	body.add_child(content)
	content.add_child(_build_identity())
	content.add_child(PROGRESS_BAR.new())
	content.add_child(_build_footer())

func _build_band() -> PanelContainer:
	var band := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_BAND
	style.corner_radius_top_left = CORNER - 2
	style.corner_radius_top_right = CORNER - 2
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	band.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	band.add_child(row)
	var title := _label("ASTRO SWARM", 20, C_BAND_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_label("PILOT LICENSE", 14, C_BAND_TEXT))
	return band

func _build_identity() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.add_child(_build_photo_column())
	var fields := GridContainer.new()
	fields.columns = 2
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("h_separation", 24)
	fields.add_theme_constant_override("v_separation", 14)
	row.add_child(fields)
	fields.add_child(_field(1, "ID NO.", PlayerData.player_id.left(ID_DIGITS).to_upper()))
	fields.add_child(_field(2, "RANK", RANKS.rank_name(PlayerData.level)))
	fields.add_child(_field(3, "CALLSIGN", _or_unknown(PlayerData.username)))
	fields.add_child(_field(4, "COMMAND", "SWARM"))
	fields.add_child(_field(5, "HOME PLANET", _or_unknown(PlayerData.planet_name)))
	fields.add_child(_field(6, "BADGES", str(_earned_count())))
	return row

func _build_photo_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = C_PHOTO_BG
	frame_style.border_color = C_LINE
	frame_style.set_border_width_all(2)
	frame_style.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", frame_style)
	column.add_child(frame)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(PHOTO_SIZE, PHOTO_SIZE)
	holder.clip_contents = true
	frame.add_child(holder)
	var planet := TERRAN.instantiate() as Control
	holder.add_child(planet)
	planet.generate(PlayerData.planet_seed, PLANET_PIXELS)
	var scale_factor: float = PHOTO_SIZE / PLANET_PIXELS
	planet.scale = Vector2(scale_factor, scale_factor)
	_ignore_mouse(planet)
	column.add_child(_label(_or_unknown(PlayerData.username), 14, C_TEXT))
	var signature_line := ColorRect.new()
	signature_line.color = C_LINE
	signature_line.custom_minimum_size = Vector2(PHOTO_SIZE, 2)
	column.add_child(signature_line)
	column.add_child(_label("SIGNATURE", 8, C_DIM))
	return column

func _build_footer() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var barcode := Control.new()
	barcode.set_script(BARCODE)
	barcode.code = PlayerData.player_id
	barcode.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(barcode)
	var note := _label("VALID IN ALL SECTORS", 10, C_DIM)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(note)
	return row

func _field(number: int, caption: String, value: String) -> VBoxContainer:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 2)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var caption_row := HBoxContainer.new()
	caption_row.add_theme_constant_override("separation", 6)
	caption_row.add_child(_label(str(number), 9, C_FIELD_NUMBER))
	caption_row.add_child(_label(caption, 9, C_DIM))
	field.add_child(caption_row)
	field.add_child(_label(value, 16, C_TEXT))
	return field

func _earned_count() -> int:
	var count := 0
	for achievement in ACHIEVEMENTS.ALL:
		if PlayerData.has_achievement(achievement["id"]):
			count += 1
	return count

func _or_unknown(value: String) -> String:
	return value if value != "" else "UNKNOWN"

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = C_CARD
	style.border_color = C_CARD_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(CORNER)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	return style

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _ignore_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
