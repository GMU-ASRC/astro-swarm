extends Control

@onready var back_btn: Button = $TopBar/HBox/BackButton
@onready var palette_list: VBoxContainer = $Body/Left/LeftVBox/PaletteScroll/PaletteList
@onready var blocks_list: VBoxContainer = $Body/Right/RightVBox/Scroll/BlocksList

const SCRATCH_BLOCK := preload("res://ui/workspace/ScratchBlock.tscn")

const GAME_PALETTE := {
	"condition": ["when_always", "when_sees_enemy", "when_sees_ally", "when_alone", "when_sees_object", "when_sees_rim"],
	"action": ["do_forward", "do_backward", "do_stop", "do_wander", "do_random_walk", "do_turn_left", "do_turn_right", "do_turn_left_by", "do_turn_right_by", "do_face", "do_flee", "do_fire", "do_throttle"],
}

var _drag_block: PanelContainer = null
var _drag_index: int = -1

func _ready():
	get_tree().paused = false
	back_btn.pressed.connect(_on_back)
	_build_palette()
	_load_blocks()

func _build_palette():
	for child in palette_list.get_children():
		child.queue_free()
	for category in ["condition", "action"]:
		var header := Label.new()
		header.text = category.to_upper()
		header.add_theme_font_size_override("font_size", 10)
		header.add_theme_color_override("font_color", Color(0.435, 0.435, 0.498, 1.0))
		palette_list.add_child(header)
		for block_id in GAME_PALETTE.get(category, []):
			var def: Dictionary = SimulationManager.BLOCK_DEFS.get(block_id, {})
			var btn := Button.new()
			btn.text = "  + %s" % def.get("label", block_id)
			btn.focus_mode = Control.FOCUS_NONE
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size = Vector2(0, 32)
			var cat_color: Color = _cat_color(category)
			btn.add_theme_color_override("font_color", cat_color)
			btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
			var sb_h := StyleBoxFlat.new()
			sb_h.bg_color = cat_color
			sb_h.set_corner_radius_all(4)
			sb_h.content_margin_left = 8
			sb_h.content_margin_right = 8
			sb_h.content_margin_top = 4
			sb_h.content_margin_bottom = 4
			btn.add_theme_stylebox_override("hover", sb_h)
			btn.add_theme_stylebox_override("pressed", sb_h)
			var bid: String = block_id
			btn.pressed.connect(func(): _add_block(bid))
			palette_list.add_child(btn)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		palette_list.add_child(spacer)

func _cat_color(category: String) -> Color:
	match category:
		"condition": return Color(0.482, 0.302, 0.686, 1.0)
		"action": return Color(0.255, 0.463, 0.843, 1.0)
	return Color(0.5, 0.5, 0.5, 1.0)

func _load_blocks():
	for child in blocks_list.get_children():
		child.queue_free()
	for b in PlayerData.ship_blocks:
		_spawn_block_widget(b.get("type", ""), b.get("params", {}))

func _add_block(block_id: String):
	var def: Dictionary = SimulationManager.BLOCK_DEFS.get(block_id, {})
	var params := {}
	var input_def = def.get("input", null)
	if input_def != null and input_def is Dictionary:
		params["value"] = input_def.get("default", 0.0)
	_spawn_block_widget(block_id, params)
	_save_blocks()

func _spawn_block_widget(btype: String, params: Dictionary):
	var block := SCRATCH_BLOCK.instantiate()
	blocks_list.add_child(block)
	block.setup(btype, params)
	block.block_changed.connect(func(): _save_blocks())
	block.block_deleted.connect(func():
		block.queue_free()
		await get_tree().process_frame
		_save_blocks()
	)
	block.drag_started.connect(_on_block_drag_started)

func _save_blocks():
	var blocks: Array = []
	for child in blocks_list.get_children():
		if child is PanelContainer and child.has_method("get_block_data"):
			blocks.append(child.get_block_data())
	PlayerData.set_ship_blocks(blocks)

func _on_block_drag_started(block: PanelContainer):
	_drag_block = block
	_drag_index = block.get_index()

func _input(event: InputEvent):
	if _drag_block == null:
		return
	if event is InputEventMouseMotion:
		var mouse_y := blocks_list.get_local_mouse_position().y
		var new_index := _find_insert_index(mouse_y)
		if new_index != _drag_block.get_index():
			blocks_list.move_child(_drag_block, new_index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _drag_block.get_index() != _drag_index:
			_save_blocks()
		_drag_block = null
		_drag_index = -1

func _find_insert_index(mouse_y: float) -> int:
	var count := blocks_list.get_child_count()
	for i in count:
		var child: Control = blocks_list.get_child(i) as Control
		var mid: float = child.position.y + child.size.y * 0.5
		if mouse_y < mid:
			return i
	return count - 1

func _on_back():
	_save_blocks()
	get_tree().change_scene_to_file("res://levels/PlayerBaseScene.tscn")
