extends PanelContainer

signal action_requested(action: String, genome_id: String)

const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")
const FRAME := preload("res://assets/sprites/upgrades/card_frame.svg")

const CARD_WIDTH := 330.0
const FRAME_MARGIN := 12
const PADDING := 22
const PREVIEW_LINES := 4
const NAME_FONT_SIZE := 20
const BODY_FONT_SIZE := 13
const BUTTON_FONT_SIZE := 13

const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)
const C_FAINT := Color(0.45, 0.45, 0.51, 1.0)
const C_ACTIVE := Color(0.40, 0.85, 0.45, 1.0)

var _genome_id: String = ""

func setup(genome: Dictionary, is_active: bool, can_delete: bool, can_add: bool):
	_genome_id = genome["id"]
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("panel", _frame_style())

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var name_label := _label(genome["name"], NAME_FONT_SIZE, C_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(name_label)
	if is_active:
		header.add_child(_label("ACTIVE", BODY_FONT_SIZE, C_ACTIVE))

	var scripts: Array = genome.get("scripts", [])
	column.add_child(_label("%d blocks in %d stacks" % [GenomeBank.block_count(genome), scripts.size()], BODY_FONT_SIZE, C_DIM))

	var preview := _label(_preview_text(scripts), BODY_FONT_SIZE, C_FAINT)
	preview.custom_minimum_size = Vector2(0, BODY_FONT_SIZE * 1.6 * PREVIEW_LINES)
	preview.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	column.add_child(preview)

	column.add_child(_label("Edited %s" % _date_text(int(genome.get("updated", 0))), BODY_FONT_SIZE, C_FAINT))

	var primary_row := _button_row(column)
	_add_button(primary_row, "EDIT", "edit", HUD_BUTTONS.Kind.PRIMARY, false)
	_add_button(primary_row, "ACTIVE" if is_active else "SET ACTIVE", "activate", HUD_BUTTONS.Kind.NEUTRAL, is_active)

	var secondary_row := _button_row(column)
	_add_button(secondary_row, "COPY", "duplicate", HUD_BUTTONS.Kind.NEUTRAL, not can_add)
	_add_button(secondary_row, "RENAME", "rename", HUD_BUTTONS.Kind.NEUTRAL, false)
	_add_button(secondary_row, "DELETE", "delete", HUD_BUTTONS.Kind.NEUTRAL, not can_delete)

func _preview_text(scripts: Array) -> String:
	var lines: Array = []
	for script in scripts:
		var labels: Array = []
		for block in script.get("blocks", []):
			labels.append(_block_label(str(block.get("type", ""))))
		if not labels.is_empty():
			lines.append(" > ".join(labels))
		if lines.size() >= PREVIEW_LINES:
			break
	if lines.is_empty():
		return "Empty program"
	return "\n".join(lines)

func _block_label(block_type: String) -> String:
	var definition: Dictionary = SimulationManager.BLOCK_DEFS.get(block_type, {})
	return str(definition.get("label", block_type)).to_lower()

func _date_text(timestamp: int) -> String:
	if timestamp <= 0:
		return "never"
	return Time.get_date_string_from_unix_time(timestamp)

func _button_row(column: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	return row

func _add_button(row: HBoxContainer, text: String, action: String, kind: int, disabled: bool):
	var button: Button = HUD_BUTTONS.make(text, kind, BUTTON_FONT_SIZE)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.pressed.connect(func(): action_requested.emit(action, _genome_id))
	row.add_child(button)

func _frame_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = FRAME
	style.set_texture_margin_all(FRAME_MARGIN)
	style.content_margin_left = PADDING
	style.content_margin_right = PADDING
	style.content_margin_top = PADDING
	style.content_margin_bottom = PADDING
	return style

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
