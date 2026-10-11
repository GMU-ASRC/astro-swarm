extends Control

const SHIP_UPGRADES := preload("res://progression/ShipUpgrades.gd")
const SHIP_ADDONS := preload("res://progression/ShipAddons.gd")
const UPGRADE_ROW := preload("res://levels/menus/moons/UpgradeRow.gd")
const ADDON_CARD := preload("res://levels/menus/moons/AddonCard.gd")

const MOONS_SCENE := "res://levels/menus/moons/MoonsScene.tscn"
const SECTION_FONT_SIZE := 18
const CARD_GAP := 18
const C_SECTION := Color(0.6, 0.62, 0.74, 1.0)

@onready var sections: VBoxContainer = $Scroll/Sections
@onready var coin_label: Label = $Balance/CoinLabel
@onready var back_btn: Button = $BackButton

var _entries: Array = []

func _ready():
	get_tree().paused = false
	back_btn.pressed.connect(_go_back)
	PlayerData.coins_changed.connect(_on_coins_changed)
	PlayerData.ship_upgrades_changed.connect(_refresh)
	PlayerData.ship_addons_changed.connect(_refresh)
	_add_section("UPGRADES", sections, UPGRADE_ROW, SHIP_UPGRADES.ALL, SHIP_UPGRADES.purchase)
	_add_section("ADDONS", _card_shelf(), ADDON_CARD, SHIP_ADDONS.ALL, SHIP_ADDONS.purchase)
	_refresh()

func _add_section(title: String, holder: Container, item_script: GDScript, items: Array, purchase: Callable):
	sections.add_child(_section_label(title))
	if holder != sections:
		sections.add_child(holder)
	for item in items:
		var entry = item_script.new()
		entry.setup(item)
		entry.purchase_requested.connect(purchase)
		holder.add_child(entry)
		_entries.append(entry)

func _card_shelf() -> HFlowContainer:
	var shelf := HFlowContainer.new()
	shelf.add_theme_constant_override("h_separation", CARD_GAP)
	shelf.add_theme_constant_override("v_separation", CARD_GAP)
	return shelf

func _section_label(title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	label.add_theme_color_override("font_color", C_SECTION)
	return label

func _refresh():
	coin_label.text = str(PlayerData.coins)
	for entry in _entries:
		entry.refresh()

func _on_coins_changed(_amount: int):
	_refresh()

func _go_back():
	get_tree().change_scene_to_file(MOONS_SCENE)
