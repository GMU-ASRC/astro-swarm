extends Control

static var return_scene: String = "res://levels/menus/PlayerBaseScene.tscn"

@onready var back_btn: Button = $TopBar/HBox/BackButton
@onready var top_hbox: HBoxContainer = $TopBar/HBox
@onready var palette_list: VBoxContainer = $Body/Left/LeftVBox/PaletteScroll/PaletteMargin/PaletteList
@onready var canvas: Control = $Body/Right/RightVBox/Scroll/Canvas

var _name_edit: LineEdit
var _algo_option: OptionButton
var _loading: bool = false
var _warning_label: Label

const SCRATCH_BLOCK := preload("res://ui/workspace/ScratchBlock.tscn")
const SIM := preload("res://autoloads/SimulationManager.gd")

const GAME_PALETTE := {
	"config": ["set_speed", "set_turn", "set_view", "set_fov", "set_size"],
	"condition": ["when_start", "when_always", "when_sees", "when_sees_enemy", "when_sees_ally", "when_alone", "when_near_wall", "when_sees_wall"],
	"logic": ["if_see", "if_within", "if_beyond", "else"],
	"action": ["do_forward", "do_backward", "do_stop", "do_random_walk", "do_turn_left", "do_turn_right", "do_turn_left_by", "do_turn_right_by", "do_face", "do_flee", "do_throttle"],
}

const FARP_SCENES := [
	"res://levels/modes/level1/Level1Scene.tscn",
	"res://levels/modes/level2/Level2Scene.tscn",
	"res://levels/modes/level5/Level5Scene.tscn",
]
const FARP_DISABLED_BLOCKS := ["do_throttle", "set_size"]

func _ready():
	get_tree().paused = false
	back_btn.text = " ← Level " if FARP_SCENES.has(return_scene) else " ← Base "
	back_btn.pressed.connect(_on_back)
	canvas.canvas_mutated.connect(_save_blocks)
	_build_save_load_ui()
	_build_warning_banner()
	_build_palette()
	_load_blocks()
	_update_warning()

func _build_warning_banner():
	_warning_label = Label.new()
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.32, 1.0))
	_warning_label.add_theme_font_size_override("font_size", 12)
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_warning_label.offset_top = 44
	_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_label.visible = false
	add_child(_warning_label)

func _update_warning():
	if _warning_label == null:
		return
	var invalid: bool = SIM.has_unnested_conditional(_current_scripts())
	_warning_label.visible = invalid
	if invalid:
		_warning_label.text = "Warning: a condition block (IF) must be placed inside an event block (WHEN)."

func _build_save_load_ui():
	var spacer: Control = $TopBar/HBox/Spacer

	var sep := VSeparator.new()
	top_hbox.add_child(sep)
	top_hbox.move_child(sep, spacer.get_index())

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Algorithm name"
	_name_edit.custom_minimum_size = Vector2(150, 0)
	_name_edit.max_length = 24
	top_hbox.add_child(_name_edit)
	top_hbox.move_child(_name_edit, spacer.get_index())

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(_on_save_algorithm)
	top_hbox.add_child(save_btn)
	top_hbox.move_child(save_btn, spacer.get_index())

	_algo_option = OptionButton.new()
	_algo_option.focus_mode = Control.FOCUS_NONE
	_algo_option.custom_minimum_size = Vector2(150, 0)
	top_hbox.add_child(_algo_option)
	top_hbox.move_child(_algo_option, spacer.get_index())

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.focus_mode = Control.FOCUS_NONE
	load_btn.pressed.connect(_on_load_algorithm)
	top_hbox.add_child(load_btn)
	top_hbox.move_child(load_btn, spacer.get_index())

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.focus_mode = Control.FOCUS_NONE
	delete_btn.pressed.connect(_on_delete_algorithm)
	top_hbox.add_child(delete_btn)
	top_hbox.move_child(delete_btn, spacer.get_index())

	_refresh_algo_list()

func _refresh_algo_list(select_name: String = ""):
	_algo_option.clear()
	var names: Array = PlayerData.algorithm_names()
	names.sort()
	for n in names:
		_algo_option.add_item(n)
	if select_name != "":
		for i in _algo_option.item_count:
			if _algo_option.get_item_text(i) == select_name:
				_algo_option.select(i)
				break

func _on_save_algorithm():
	var algo_name: String = _name_edit.text.strip_edges()
	if algo_name == "":
		return
	PlayerData.save_algorithm(algo_name, _current_scripts())
	_refresh_algo_list(algo_name)

func _on_load_algorithm():
	if _algo_option.item_count == 0:
		return
	var algo_name: String = _algo_option.get_item_text(_algo_option.selected)
	var scripts: Array = PlayerData.get_algorithm(algo_name)
	_populate_canvas(scripts)
	PlayerData.set_ship_blocks(scripts)
	_name_edit.text = algo_name

func _on_delete_algorithm():
	if _algo_option.item_count == 0:
		return
	var algo_name: String = _algo_option.get_item_text(_algo_option.selected)
	PlayerData.delete_algorithm(algo_name)
	_refresh_algo_list()

func _build_palette():
	for child in palette_list.get_children():
		child.queue_free()
	for category in ["config", "condition", "logic", "action"]:
		_build_palette_category(category, _allowed_blocks(GAME_PALETTE.get(category, [])))

func _allowed_blocks(ids: Array) -> Array:
	if not FARP_SCENES.has(return_scene):
		return ids
	var allowed: Array = []
	for block_id in ids:
		if not FARP_DISABLED_BLOCKS.has(block_id):
			allowed.append(block_id)
	return allowed

func _build_palette_category(category: String, ids: Array):
	if ids.is_empty():
		return
	var header := Label.new()
	header.text = _category_label(category)
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color(0.435, 0.435, 0.498, 1.0))
	palette_list.add_child(header)
	for block_id in ids:
		_make_palette_item(block_id)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	palette_list.add_child(spacer)

func _make_palette_item(block_id: String):
	var item := MarginContainer.new()
	item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var preview := SCRATCH_BLOCK.instantiate()
	item.add_child(preview)
	palette_list.add_child(item)
	preview.setup_preview(block_id)
	item.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_add_block(block_id)
	)
	item.mouse_entered.connect(func(): item.modulate = Color(1.12, 1.12, 1.12))
	item.mouse_exited.connect(func(): item.modulate = Color(1, 1, 1))

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
			_spawn_block_widget(b, zone)
	canvas.resolve_overlaps()
	_loading = false
	_update_warning()

func _add_block(block_id: String):
	var def: Dictionary = SimulationManager.BLOCK_DEFS.get(block_id, {})
	var params := {}
	var input_def = def.get("input", null)
	if input_def != null and input_def is Dictionary:
		params["value"] = input_def.get("default", 0.0)
	var zone: VBoxContainer = canvas.spawn_stack(_new_stack_position())
	_spawn_block_widget({"type": block_id, "params": params, "children": []}, zone)
	_save_blocks()

func _new_stack_position() -> Vector2:
	var scroll: ScrollContainer = $Body/Right/RightVBox/Scroll
	var n: int = canvas.get_child_count() % 6
	return Vector2(scroll.scroll_horizontal + 30.0 + n * 28.0, scroll.scroll_vertical + 30.0 + n * 28.0)

func _spawn_block_widget(data: Dictionary, parent_zone: VBoxContainer):
	var block := SCRATCH_BLOCK.instantiate()
	parent_zone.add_child(block)
	block.setup(data.get("type", ""), data.get("params", {}))
	block.block_changed.connect(_save_blocks)
	block.block_deleted.connect(func():
		block.queue_free()
		await get_tree().process_frame
		_save_blocks()
	)
	if block.is_container():
		var zone: VBoxContainer = block.get_children_zone()
		zone.blocks_mutated.connect(_save_blocks)
		for child_data in data.get("children", []):
			_spawn_block_widget(child_data, zone)

func _current_scripts() -> Array:
	canvas.remove_empty_stacks()
	var scripts: Array = []
	for zone in canvas.get_children():
		if not zone is VBoxContainer:
			continue
		var blocks: Array = []
		for child in zone.get_children():
			if child is PanelContainer and child.has_method("get_block_data"):
				blocks.append(child.get_block_data())
		if blocks.is_empty():
			continue
		scripts.append({"x": zone.position.x, "y": zone.position.y, "blocks": blocks})
	return scripts

func _save_blocks():
	if _loading:
		return
	PlayerData.set_ship_blocks(_current_scripts())
	_update_warning()

func _on_back():
	_save_blocks()
	get_tree().change_scene_to_file(return_scene)
