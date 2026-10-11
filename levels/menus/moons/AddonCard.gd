extends "res://levels/menus/moons/ShipyardItem.gd"

const SHIP_ADDONS := preload("res://progression/ShipAddons.gd")

const CARD_WIDTH := 300.0
const CARD_ICON_SIZE := 96.0
const ROW_GAP := 14

func refresh():
	if SHIP_ADDONS.is_owned(_item):
		_show_settled("OWNED", "OWNED")
	else:
		_show_price(int(_item["cost"]), "BUY")

func _make_layout() -> BoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	column.add_theme_constant_override("separation", ROW_GAP)
	return column

func _build_columns():
	var icon := _pixel_image(load(_item["icon"]), CARD_ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_layout.add_child(icon)
	_layout.add_child(_centered_label(_item["title"], TITLE_FONT_SIZE, C_TEXT))
	var detail := _centered_label(_item["detail"], DETAIL_FONT_SIZE, C_ACCENT)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_layout.add_child(detail)
	_layout.add_child(_make_cost_box(BoxContainer.ALIGNMENT_CENTER))
	_layout.add_child(_make_buy_button())

func _centered_label(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
