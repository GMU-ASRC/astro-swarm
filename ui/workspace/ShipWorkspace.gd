extends Control

signal closed

static var return_scene: String = "res://levels/menus/PlayerBaseScene.tscn"

var embedded: bool = false

@onready var back_btn: Button = $TopBar/HBox/BackButton
@onready var top_hbox: HBoxContainer = $TopBar/HBox
@onready var palette_list: VBoxContainer = $Body/Left/LeftVBox/PaletteScroll/PaletteMargin/PaletteList
@onready var canvas: Control = $Body/Right/RightVBox/Scroll/Canvas

var _genome_option: OptionButton
var _save_as_btn: Button
var _loading: bool = false
var _error_banner: PanelContainer

const BlockFactory := preload("res://ui/workspace/BlockFactory.gd")
const ERROR_BANNER := preload("res://ui/workspace/WorkspaceErrorBanner.gd")
const WorkspaceStyle := preload("res://ui/workspace/WorkspaceStyle.gd")
const SHIP_UPGRADES := preload("res://progression/ShipUpgrades.gd")
const SHIP_ADDONS := preload("res://progression/ShipAddons.gd")

const GAME_PALETTE := {
	"config": ["set_speed", "set_turn", "set_view", "set_fov", "set_size"],
	"condition": ["when_start", "when_always", "when_sees", "when_sees_enemy", "when_sees_ally", "when_alone", "when_not_see", "when_near_wall", "when_not_near_wall", "when_sees_wall"],
	"logic": ["if_see", "if_not_see", "if_near_wall", "if_not_near_wall", "elif_see", "elif_not_see", "elif_near_wall", "elif_not_near_wall", "else"],
	"action": ["do_forward", "do_backward", "do_stop", "do_random_walk", "do_turn_left", "do_turn_right", "do_turn_left_by", "do_turn_right_by", "do_face", "do_throttle"],
}

const FARP_SCENES := [
	"res://levels/modes/level1/Level1Scene.tscn",
	"res://levels/modes/level2/Level2Scene.tscn",
	"res://levels/modes/level6/Level6Scene.tscn",
]
const FARP_DISABLED_BLOCKS := ["set_size"]
const GENOME_MOON_SCENE := "res://levels/menus/moons/GenomeMoonScene.tscn"

func _enter_tree():
	SHIP_UPGRADES.editing_ship = true

func _exit_tree():
	SHIP_UPGRADES.editing_ship = false

func _ready():
	if not embedded:
		get_tree().paused = false
	back_btn.text = _back_label()
	back_btn.pressed.connect(_on_back)
	canvas.canvas_mutated.connect(_save_blocks)
	_build_genome_ui()
	WorkspaceStyle.apply(self, WorkspaceStyle.GAME)
	_build_error_banner()
	_build_palette()
	_load_blocks()

func _back_label() -> String:
	if embedded:
		return " ← Resume "
	if return_scene == GENOME_MOON_SCENE:
		return " ← Genome "
	return " ← Level " if FARP_SCENES.has(return_scene) else " ← Base "

func _build_error_banner():
	var scroll: ScrollContainer = $Body/Right/RightVBox/Scroll
	_error_banner = ERROR_BANNER.new()
	scroll.get_parent().add_child(_error_banner)
	scroll.get_parent().move_child(_error_banner, scroll.get_index())

func _update_errors():
	if _error_banner != null:
		_error_banner.show_messages(canvas.highlight_errors())

func _build_genome_ui():
	if not GenomeBank.is_unlocked():
		return
	var spacer: Control = $TopBar/HBox/Spacer
	var nodes: Array = [VSeparator.new()]

	var genome_label := Label.new()
	genome_label.text = "Genome"
	nodes.append(genome_label)

	_genome_option = OptionButton.new()
	_genome_option.focus_mode = Control.FOCUS_NONE
	_genome_option.custom_minimum_size = Vector2(180, 0)
	_genome_option.item_selected.connect(_on_genome_selected)
	nodes.append(_genome_option)

	_save_as_btn = Button.new()
	_save_as_btn.text = "Save as New"
	_save_as_btn.focus_mode = Control.FOCUS_NONE
	_save_as_btn.tooltip_text = "Copy this program into a new genome and keep editing the copy"
	_save_as_btn.pressed.connect(_on_save_as_new)
	nodes.append(_save_as_btn)

	for node in nodes:
		top_hbox.add_child(node)
		top_hbox.move_child(node, spacer.get_index())

	GenomeBank.genomes_changed.connect(_refresh_genome_list)
	_refresh_genome_list()

func _refresh_genome_list():
	if not is_instance_valid(_genome_option):
		return
	_genome_option.clear()
	for index in GenomeBank.genomes.size():
		var genome: Dictionary = GenomeBank.genomes[index]
		_genome_option.add_item(genome["name"], index)
		_genome_option.set_item_metadata(index, genome["id"])
		if genome["id"] == GenomeBank.active_id:
			_genome_option.select(index)
	_save_as_btn.disabled = GenomeBank.is_full()

func _on_genome_selected(index: int):
	var genome_id: String = str(_genome_option.get_item_metadata(index))
	if genome_id == GenomeBank.active_id:
		return
	_save_blocks()
	GenomeBank.activate(genome_id)
	_load_blocks()

func _on_save_as_new():
	_save_blocks()
	var source: Dictionary = GenomeBank.active_genome()
	var new_id: String = GenomeBank.create(source.get("name", GenomeBank.DEFAULT_NAME), PlayerData.get_ship_algorithm())
	if new_id != "":
		GenomeBank.activate(new_id)

func _build_palette():
	for child in palette_list.get_children():
		child.queue_free()
	for category in ["config", "condition", "logic", "action"]:
		_build_palette_category(category, _allowed_blocks(GAME_PALETTE.get(category, [])))

func _allowed_blocks(ids: Array) -> Array:
	var level_restricted: bool = not embedded and FARP_SCENES.has(return_scene)
	var allowed: Array = []
	for block_id in ids:
		if SHIP_ADDONS.is_block_locked(block_id):
			continue
		if level_restricted and FARP_DISABLED_BLOCKS.has(block_id):
			continue
		allowed.append(block_id)
	return allowed

func _build_palette_category(category: String, ids: Array):
	if ids.is_empty():
		return
	var section: VBoxContainer = WorkspaceStyle.add_palette_section(palette_list, _category_label(category), category, WorkspaceStyle.GAME)
	for block_id in ids:
		BlockFactory.add_palette_item(section, block_id, _add_block)

func _category_label(category: String) -> String:
	match category:
		"config":    return "SHIP CONFIG"
		"condition": return "EVENTS"
		"logic":     return "CONDITIONS"
	return category.to_upper()

func _load_blocks():
	_populate_canvas(PlayerData.get_ship_algorithm())

func _populate_canvas(scripts: Array):
	_loading = true
	for child in canvas.get_children():
		child.queue_free()
	for s in scripts:
		var zone: VBoxContainer = canvas.spawn_stack(Vector2(s.get("x", 40.0), s.get("y", 40.0)))
		for b in s.get("blocks", []):
			BlockFactory.create_block(b, zone, _save_blocks)
	canvas.resolve_overlaps()
	_loading = false
	_update_errors()

func _add_block(block_id: String):
	var zone: VBoxContainer = canvas.spawn_stack(_new_stack_position())
	BlockFactory.create_block({"type": block_id}, zone, _save_blocks)
	_save_blocks()

func _new_stack_position() -> Vector2:
	var scroll: ScrollContainer = $Body/Right/RightVBox/Scroll
	var n: int = canvas.get_child_count() % 6
	return Vector2(scroll.scroll_horizontal + 30.0 + n * 28.0, scroll.scroll_vertical + 30.0 + n * 28.0)

func _save_blocks():
	if _loading:
		return
	PlayerData.set_ship_blocks(canvas.collect_scripts())
	_update_errors()

func _on_back():
	_save_blocks()
	if embedded:
		closed.emit()
		return
	get_tree().change_scene_to_file(return_scene)
