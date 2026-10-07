extends RefCounted

const BLOCK_SCENE_PATH := "res://ui/workspace/ScratchBlock.tscn"
const PREVIEW_OPACITY := 0.8
const HEADER_COLOR := Color(0.435, 0.435, 0.498, 1.0)

static func create_block(data: Dictionary, parent_zone: Control, on_changed: Callable):
	var block = load(BLOCK_SCENE_PATH).instantiate()
	parent_zone.add_child(block)
	block.setup(data.get("type", ""), data.get("params", {}))
	block.block_changed.connect(on_changed)
	block.block_deleted.connect(func(): _delete_block(block, on_changed))
	if block.is_container():
		var zone = block.get_children_zone()
		zone.blocks_mutated.connect(on_changed)
		for child_data in data.get("children", []):
			create_block(child_data, zone, on_changed)
	return block

static func create_preview(data: Dictionary, parent: Control):
	var block = load(BLOCK_SCENE_PATH).instantiate()
	parent.add_child(block)
	block.setup_preview(data.get("type", ""), data.get("params", {}))
	if block.is_container():
		for child_data in data.get("children", []):
			create_preview(child_data, block.get_children_zone())
	return block

static func build_drag_preview(blocks: Array, grab_offset: Vector2) -> Control:
	var holder := Control.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.position = -grab_offset
	column.modulate.a = PREVIEW_OPACITY
	holder.add_child(column)
	for block in blocks:
		if is_instance_valid(block):
			create_preview(block.get_block_data(), column)
	return holder

static func add_palette_header(palette_list: Control, text: String):
	var header := Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", HEADER_COLOR)
	palette_list.add_child(header)

static func add_palette_spacer(palette_list: Control):
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	palette_list.add_child(spacer)

static func add_palette_item(palette_list: Control, block_id: String, on_pressed: Callable):
	var item := MarginContainer.new()
	item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_constant_override("margin_bottom", 4)
	palette_list.add_child(item)
	create_preview({"type": block_id}, item)
	item.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			on_pressed.call(block_id)
	)
	item.mouse_entered.connect(func(): item.modulate = Color(1.12, 1.12, 1.12))
	item.mouse_exited.connect(func(): item.modulate = Color(1, 1, 1))

static func _delete_block(block, on_changed: Callable):
	var tree: SceneTree = block.get_tree()
	block.queue_free()
	await tree.process_frame
	on_changed.call()
