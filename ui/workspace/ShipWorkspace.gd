extends Control

@onready var back_btn: Button = $TopBar/HBox/BackButton
@onready var palette_list: VBoxContainer = $Body/Left/LeftVBox/PaletteScroll/PaletteList
@onready var canvas: Control = $Body/Right/RightVBox/Scroll/Canvas

const SCRATCH_BLOCK := preload("res://ui/workspace/ScratchBlock.tscn")

const GAME_PALETTE := {
	"condition": ["when_start", "when_always", "when_sees_enemy", "when_sees_ally", "when_alone", "when_sees_object", "when_sees_rim"],
	"logic": ["if_sees", "if_within", "if_beyond"],
	"action": ["do_forward", "do_backward", "do_stop", "do_wander", "do_random_walk", "do_turn_left", "do_turn_right", "do_turn_left_by", "do_turn_right_by", "do_face", "do_flee", "do_fire", "do_throttle"],
}

func _ready():
	get_tree().paused = false
	back_btn.pressed.connect(_on_back)
	canvas.canvas_mutated.connect(_save_blocks)
	_build_palette()
	_load_blocks()

func _build_palette():
	for child in palette_list.get_children():
		child.queue_free()
	for category in ["condition", "logic", "action"]:
		_build_palette_category(category, GAME_PALETTE.get(category, []))

func _build_palette_category(category: String, ids: Array):
	var header := Label.new()
	header.text = _category_label(category)
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color(0.435, 0.435, 0.498, 1.0))
	palette_list.add_child(header)
	for block_id in ids:
		var def: Dictionary = SimulationManager.BLOCK_DEFS.get(block_id, {})
		var btn := Button.new()
		btn.text = def.get("label", block_id)
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 30)
		_style_palette_button(btn, _cat_color(category))
		var bid: String = block_id
		btn.pressed.connect(func(): _add_block(bid))
		palette_list.add_child(btn)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	palette_list.add_child(spacer)

func _style_palette_button(btn: Button, cat_color: Color):
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_font_size_override("font_size", 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = cat_color
	sb.set_corner_radius_all(5)
	sb.border_width_left = 4
	sb.border_color = cat_color.darkened(0.25)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = cat_color.lightened(0.12)
	var sb_pressed: StyleBoxFlat = sb.duplicate()
	sb_pressed.bg_color = cat_color.darkened(0.12)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("focus", sb)

func _category_label(category: String) -> String:
	match category:
		"condition": return "EVENTS"
		"logic":     return "CONDITIONS"
	return category.to_upper()

func _cat_color(category: String) -> Color:
	match category:
		"condition": return Color(0.482, 0.302, 0.686, 1.0)
		"logic":     return Color(0.851, 0.522, 0.200, 1.0)
		"action": return Color(0.255, 0.463, 0.843, 1.0)
	return Color(0.5, 0.5, 0.5, 1.0)

func _load_blocks():
	for child in canvas.get_children():
		child.queue_free()
	for s in PlayerData.get_ship_algorithm():
		var zone: VBoxContainer = canvas.spawn_stack(Vector2(s.get("x", 40.0), s.get("y", 40.0)))
		for b in s.get("blocks", []):
			_spawn_block_widget(b, zone)
	canvas.resolve_overlaps()

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

func _save_blocks():
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
	PlayerData.set_ship_blocks(scripts)

func _on_back():
	_save_blocks()
	get_tree().change_scene_to_file("res://levels/PlayerBaseScene.tscn")
