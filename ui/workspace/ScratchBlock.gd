extends PanelContainer

signal block_changed
signal block_deleted

const BlockShape := preload("res://ui/workspace/BlockShape.gd")
const BlockFactory := preload("res://ui/workspace/BlockFactory.gd")
const BlockInputs := preload("res://ui/workspace/BlockInputs.gd")
const BlockDeleteButton := preload("res://ui/workspace/BlockDeleteButton.gd")

const CAT_COLORS := {
	"config":    Color(0.275, 0.663, 0.322, 1.0),
	"condition": Color(0.482, 0.302, 0.686, 1.0),
	"logic":     Color(0.851, 0.522, 0.200, 1.0),
	"variable":  Color(0.200, 0.620, 0.600, 1.0),
	"spawn":     Color(0.788, 0.310, 0.502, 1.0),
	"action":    Color(0.255, 0.463, 0.843, 1.0),
}

const CAT_DARK := {
	"config":    Color(0.208, 0.518, 0.247, 1.0),
	"condition": Color(0.361, 0.216, 0.541, 1.0),
	"logic":     Color(0.682, 0.408, 0.137, 1.0),
	"variable":  Color(0.133, 0.451, 0.435, 1.0),
	"spawn":     Color(0.620, 0.216, 0.373, 1.0),
	"action":    Color(0.180, 0.345, 0.682, 1.0),
}

const SHADOW_COLOR := Color(0, 0, 0, 0.35)
const SHADOW_OFFSET := Vector2(0, 3)
const HIGHLIGHT_COLOR := Color(1, 1, 1, 0.22)
const ERROR_COLOR := Color(1.0, 0.22, 0.18, 1.0)
const ERROR_GLOW := Color(1.0, 0.22, 0.18, 0.35)
const MARKER_COLOR := Color(1, 1, 1, 0.95)
const MARKER_THICKNESS := 4.0
const FOOTER_HEIGHT := 14.0
const PREVIEW_MOUTH_SIZE := Vector2(60, 10)

var block_type: String = ""
var block_params: Dictionary = {}
var error_message: String = ""

var _category: String = ""
var _palette: bool = false
var _marker_visible: bool = false
var _marker_below: bool = false

@onready var outer_box: VBoxContainer = $Outer
@onready var label_node: Label = $Outer/HBox/LabelText
@onready var inputs_box: HBoxContainer = $Outer/HBox/InputsBox
@onready var delete_btn: Button = $Outer/HBox/DeleteButton
@onready var drag_handle: Label = $Outer/HBox/DragHandle
@onready var inner_wrap: MarginContainer = $Outer/InnerWrap
@onready var inner_panel: PanelContainer = $Outer/InnerWrap/InnerPanel

func _ready():
	delete_btn.pressed.connect(func(): block_deleted.emit())
	BlockDeleteButton.setup(delete_btn)
	inner_panel.item_rect_changed.connect(queue_redraw)
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	_apply_block_def()

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func setup(btype: String, params: Dictionary):
	block_type = btype
	block_params = params.duplicate()
	if is_inside_tree():
		_apply_block_def()

func setup_preview(btype: String, params: Dictionary = {}):
	_palette = true
	setup(btype, params)

func is_container() -> bool:
	return block_type.begins_with("when_") or block_type.begins_with("if_") or block_type.begins_with("elif_") or block_type == "else"

func is_hat() -> bool:
	return block_type.begins_with("when_")

func get_children_zone() -> VBoxContainer:
	return get_node("Outer/InnerWrap/InnerPanel/Children")

func set_error(message: String):
	if error_message == message:
		return
	error_message = message
	tooltip_text = message
	queue_redraw()

func set_insert_marker(marker_visible: bool, below: bool):
	_marker_visible = marker_visible
	_marker_below = below
	queue_redraw()

func _apply_block_def():
	if block_type == "":
		return
	var def: Dictionary = SimulationManager.BLOCK_DEFS.get(block_type, {})
	_category = def.get("category", "action")
	label_node.text = def.get("label", block_type)
	inner_wrap.visible = is_container()
	_apply_style()
	if _palette:
		BlockInputs.build_compact(self, inputs_box, def)
		get_children_zone().custom_minimum_size = PREVIEW_MOUTH_SIZE
	else:
		BlockInputs.build(self, inputs_box, def)
	delete_btn.visible = not _palette
	if _palette:
		_ignore_mouse_tree(self)
	queue_redraw()

func _ignore_mouse_tree(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_ignore_mouse_tree(c)

func _apply_style():
	var top_margin: float = BlockShape.HAT_HEIGHT + 8.0 if is_hat() else BlockShape.NOTCH_DEPTH + 5.0
	var bottom_margin: float = FOOTER_HEIGHT if is_container() else 7.0
	add_theme_stylebox_override("panel", _margin_box(10.0, top_margin, 6.0, bottom_margin))
	inner_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	inner_wrap.add_theme_constant_override("margin_left", int(BlockShape.ARM_WIDTH))

	label_node.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label_node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label_node.add_theme_constant_override("shadow_offset_y", 1)
	label_node.add_theme_font_size_override("font_size", 13)
	drag_handle.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))

	BlockDeleteButton.style(delete_btn, CAT_DARK.get(_category, CAT_DARK.action))

func _margin_box(left: float, top: float, right: float, bottom: float) -> StyleBoxEmpty:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = left
	box.content_margin_top = top
	box.content_margin_right = right
	box.content_margin_bottom = bottom
	return box

func _mouth_rect() -> Rect2:
	if not is_container() or inner_panel == null:
		return Rect2()
	return Rect2(outer_box.position + inner_wrap.position + inner_panel.position, inner_panel.size)

func _draw():
	if block_type == "":
		return
	var fill: Color = CAT_COLORS.get(_category, CAT_COLORS.action)
	var edge: Color = CAT_DARK.get(_category, CAT_DARK.action)
	var shape: PackedVector2Array = BlockShape.outline(size, is_hat(), _mouth_rect())
	draw_colored_polygon(BlockShape.shifted(shape, SHADOW_OFFSET), SHADOW_COLOR)
	draw_colored_polygon(shape, fill)
	_draw_top_highlight()
	var border: PackedVector2Array = BlockShape.closed(shape)
	if error_message != "":
		draw_polyline(border, ERROR_GLOW, 8.0)
		draw_polyline(border, ERROR_COLOR, 3.0)
	else:
		draw_polyline(border, edge, 2.0)
	if _marker_visible:
		_draw_insert_marker()

func _draw_top_highlight():
	var right: float = size.x - BlockShape.CORNER
	if is_hat():
		var y: float = BlockShape.HAT_HEIGHT + 2.0
		draw_line(Vector2(BlockShape.CORNER, y), Vector2(right, y), HIGHLIGHT_COLOR, 2.0)
		return
	var notch_end: float = BlockShape.NOTCH_LEFT + BlockShape.NOTCH_SLANT * 2.0 + BlockShape.NOTCH_WIDTH
	draw_line(Vector2(BlockShape.CORNER, 2.0), Vector2(BlockShape.NOTCH_LEFT, 2.0), HIGHLIGHT_COLOR, 2.0)
	draw_line(Vector2(notch_end, 2.0), Vector2(right, 2.0), HIGHLIGHT_COLOR, 2.0)

func _draw_insert_marker():
	var y: float = size.y + BlockShape.NOTCH_DEPTH if _marker_below else -MARKER_THICKNESS * 0.5
	draw_rect(Rect2(0.0, y, size.x, MARKER_THICKNESS), MARKER_COLOR)

func get_block_data() -> Dictionary:
	var child_blocks: Array = []
	if is_container():
		for c in get_children_zone().get_children():
			if c.has_method("get_block_data") and not c.is_queued_for_deletion():
				child_blocks.append(c.get_block_data())
	return {"type": block_type, "params": block_params.duplicate(), "children": child_blocks}

func _get_drag_data(at_position: Vector2) -> Variant:
	if _palette:
		return null
	var dragged: Array = _blocks_from_here()
	set_drag_preview(BlockFactory.build_drag_preview(dragged, at_position))
	return {"blocks": dragged, "grab_offset": at_position}

func _blocks_from_here() -> Array:
	var parent := get_parent()
	if parent == null:
		return [self]
	var result: Array = []
	for i in range(get_index(), parent.get_child_count()):
		var sibling := parent.get_child(i)
		if sibling.has_method("get_block_data"):
			result.append(sibling)
	return result

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var zone = _target_zone()
	return zone != null and zone.can_accept(data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var zone = _target_zone()
	if zone != null:
		zone.do_drop(data)

func _target_zone():
	if is_container():
		return get_children_zone()
	var p := get_parent()
	if p != null and p.has_method("do_drop"):
		return p
	return null
