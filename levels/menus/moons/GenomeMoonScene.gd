extends Control

const GENOME_CARD := preload("res://levels/menus/moons/GenomeCard.gd")
const MOON_CATALOG := preload("res://levels/menus/moons/MoonCatalog.gd")
const SHIP_WORKSPACE := preload("res://ui/workspace/ShipWorkspace.gd")
const GENOME_UPGRADES := preload("res://progression/GenomeUpgrades.gd")
const UPGRADE_ROW := preload("res://levels/menus/moons/UpgradeRow.gd")
const GAME_DIALOG := preload("res://ui/modal/GameDialog.gd")

const WORKSPACE_SCENE := "res://ui/workspace/ShipWorkspace.tscn"
const SECTION_FONT_SIZE := 18
const C_SECTION := Color(0.6, 0.62, 0.74, 1.0)

@onready var sections: VBoxContainer = $Scroll/Sections
@onready var cards: HFlowContainer = $Scroll/Sections/Cards
@onready var coin_label: Label = $Toolbar/CoinLabel
@onready var count_label: Label = $Toolbar/CountLabel
@onready var new_btn: Button = $Toolbar/NewButton
@onready var back_btn: Button = $BackButton

var _rename_dialog
var _delete_dialog
var _target_id: String = ""
var _upgrade_rows: Array = []

func _ready():
	get_tree().paused = false
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file(MOON_CATALOG.MOONS_SCENE))
	new_btn.pressed.connect(func(): GenomeBank.create())
	GenomeBank.genomes_changed.connect(_refresh)
	PlayerData.coins_changed.connect(_on_coins_changed)
	PlayerData.ship_upgrades_changed.connect(_refresh_upgrades)
	PlayerData.ship_upgrades_changed.connect(_refresh)
	_build_upgrades()
	_build_dialogs()
	_refresh()
	_refresh_upgrades()
	MOON_CATALOG.show_tutorial_once(self, MOON_CATALOG.GENOME)

func _build_upgrades():
	_insert_before_cards(_section_label("UPGRADES"))
	for upgrade in GENOME_UPGRADES.ALL:
		var row = UPGRADE_ROW.new()
		row.setup(upgrade)
		row.purchase_requested.connect(GENOME_UPGRADES.purchase)
		_insert_before_cards(row)
		_upgrade_rows.append(row)
	_insert_before_cards(_section_label("GENOMES"))

func _insert_before_cards(node: Control):
	sections.add_child(node)
	sections.move_child(node, cards.get_index())

func _on_coins_changed(_amount: int):
	_refresh_upgrades()

func _refresh_upgrades():
	coin_label.text = str(PlayerData.coins)
	for row in _upgrade_rows:
		row.refresh()

func _section_label(title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	label.add_theme_color_override("font_color", C_SECTION)
	return label

func _refresh():
	for child in cards.get_children():
		child.queue_free()
	var can_delete: bool = GenomeBank.genome_count() > 1
	var can_add: bool = not GenomeBank.is_full()
	for genome in GenomeBank.genomes:
		var card = GENOME_CARD.new()
		var is_active: bool = GenomeBank.in_loadout(genome["id"])
		var can_activate: bool = (is_active and GenomeBank.loadout.size() > 1) or (not is_active and not GenomeBank.loadout_full())
		card.setup(genome, is_active, can_activate, can_delete, can_add)
		card.action_requested.connect(_on_card_action)
		card.color_picked.connect(GenomeBank.set_color)
		cards.add_child(card)
	count_label.text = "%d / %d   ACTIVE %d / %d" % [GenomeBank.genome_count(), GenomeBank.MAX_GENOMES, GenomeBank.loadout_genomes().size(), GenomeBank.loadout_limit()]
	new_btn.disabled = not can_add

func _on_card_action(action: String, genome_id: String):
	match action:
		"edit":
			GenomeBank.activate(genome_id)
			SHIP_WORKSPACE.return_scene = MOON_CATALOG.GENOME_SCENE
			get_tree().change_scene_to_file(WORKSPACE_SCENE)
		"activate":
			GenomeBank.toggle_loadout(genome_id)
		"duplicate":
			GenomeBank.duplicate_genome(genome_id)
		"rename":
			_open_rename(genome_id)
		"delete":
			_open_delete(genome_id)

func _build_dialogs():
	_rename_dialog = GAME_DIALOG.new()
	_rename_dialog.confirmed.connect(_confirm_rename)
	add_child(_rename_dialog)

	_delete_dialog = GAME_DIALOG.new()
	_delete_dialog.confirmed.connect(_confirm_delete)
	add_child(_delete_dialog)

func _open_rename(genome_id: String):
	_target_id = genome_id
	var genome_name: String = GenomeBank.get_genome(genome_id).get("name", "")
	_rename_dialog.open("Rename Genome", "", "Rename", false, genome_name, GenomeBank.NAME_MAX_LENGTH)

func _confirm_rename(new_name: String):
	if new_name.strip_edges() == "":
		_rename_dialog.show_error("Give the genome a name.")
		return
	if not GenomeBank.rename(_target_id, new_name):
		_rename_dialog.show_error("Another genome already has that name.")
		return
	_rename_dialog.close()

func _open_delete(genome_id: String):
	_target_id = genome_id
	var genome_name: String = GenomeBank.get_genome(genome_id).get("name", "")
	_delete_dialog.open("Delete Genome", "Delete \"%s\"? This cannot be undone." % genome_name, "Delete", true)

func _confirm_delete(_text: String):
	GenomeBank.remove(_target_id)
	_delete_dialog.close()
