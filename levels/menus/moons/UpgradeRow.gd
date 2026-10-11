extends "res://levels/menus/moons/ShipyardItem.gd"

const SHIP_UPGRADES := preload("res://progression/ShipUpgrades.gd")
const PIP_ON := preload("res://assets/sprites/upgrades/pip_on.svg")
const PIP_OFF := preload("res://assets/sprites/upgrades/pip_off.svg")

const PIP_SIZE := 24.0
const PIP_GAP := 8
const LIMIT_WIDTH := 210.0
const TITLE_WIDTH := 230.0

var _pips: Array = []
var _limit_label: Label

func refresh():
	var level: int = PlayerData.ship_upgrade_level(_item["id"])
	for index in _pips.size():
		_pips[index].texture = PIP_ON if index < level else PIP_OFF
	_limit_label.text = "LIMIT %s" % SHIP_UPGRADES.limit_text(_item, level)
	if SHIP_UPGRADES.is_maxed(_item):
		_show_settled("MAX LEVEL", "MAXED")
	else:
		_show_price(SHIP_UPGRADES.cost(_item, level), "UPGRADE")

func _build_columns():
	_layout.add_child(_pixel_image(load(_item["icon"]), ICON_SIZE))
	var title := _label(_item["title"], TITLE_FONT_SIZE, C_TEXT)
	title.custom_minimum_size = Vector2(TITLE_WIDTH, 0)
	_layout.add_child(title)
	_layout.add_child(_build_pips())
	_limit_label = _label("", DETAIL_FONT_SIZE, C_ACCENT)
	_limit_label.custom_minimum_size = Vector2(LIMIT_WIDTH, 0)
	_layout.add_child(_limit_label)
	_layout.add_child(_make_cost_box(BoxContainer.ALIGNMENT_END))
	var button := _make_buy_button()
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_layout.add_child(button)

func _build_pips() -> HBoxContainer:
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", PIP_GAP)
	for _index in int(_item["max_level"]):
		var pip := _pixel_image(PIP_OFF, PIP_SIZE)
		pips.add_child(pip)
		_pips.append(pip)
	return pips
