extends VBoxContainer

signal blocks_mutated

const MARKER_COLOR := Color(1, 1, 1, 0.95)
const MARKER_THICKNESS := 4.0

static var _active_zone = null

var drop_index: int = -1
var _marked_block = null

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return can_accept(data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	do_drop(data)

static func is_block_data(data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("blocks")

func can_accept(data: Variant) -> bool:
	if not is_block_data(data):
		return false
	for b in data["blocks"]:
		if not is_instance_valid(b) or b == self or b.is_ancestor_of(self):
			show_insert_marker(-1)
			return false
	show_insert_marker(_calc_index())
	return true

func do_drop(data: Variant) -> void:
	if not is_block_data(data):
		return
	var insert_index: int = drop_index if drop_index >= 0 else get_child_count()
	show_insert_marker(-1)
	insert_blocks(data["blocks"], insert_index)

func insert_blocks(blocks: Array, insert_index: int):
	for b in blocks:
		if not is_instance_valid(b) or b == self or b.is_ancestor_of(self):
			continue
		if b.get_parent() == self and b.get_index() < insert_index:
			insert_index -= 1
		if b.get_parent() != null:
			b.get_parent().remove_child(b)
		add_child(b)
		move_child(b, clampi(insert_index, 0, get_child_count() - 1))
		insert_index += 1
	blocks_mutated.emit()

func _calc_index() -> int:
	var mouse_y: float = get_local_mouse_position().y
	for i in get_child_count():
		var c := get_child(i) as Control
		if c == null:
			continue
		if mouse_y < c.position.y + c.size.y * 0.5:
			return i
	return get_child_count()

func show_insert_marker(value: int):
	if value >= 0:
		if _active_zone != null and is_instance_valid(_active_zone) and _active_zone != self:
			_active_zone._set_line(-1)
		_active_zone = self
	elif _active_zone == self:
		_active_zone = null
	_set_line(value)

func _set_line(value: int):
	if drop_index == value:
		return
	drop_index = value
	_refresh_marker()
	queue_redraw()

func _refresh_marker():
	if _marked_block != null and is_instance_valid(_marked_block):
		_marked_block.set_insert_marker(false, false)
	_marked_block = null
	if drop_index < 0 or get_child_count() == 0:
		return
	var below: bool = drop_index >= get_child_count()
	var target := get_child(mini(drop_index, get_child_count() - 1))
	if target.has_method("set_insert_marker"):
		_marked_block = target
		_marked_block.set_insert_marker(true, below)

static func clear_active():
	if _active_zone != null and is_instance_valid(_active_zone):
		_active_zone._set_line(-1)
	_active_zone = null

func _notification(what: int):
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		show_insert_marker(-1)

func _draw():
	if drop_index >= 0 and get_child_count() == 0:
		draw_rect(Rect2(0.0, 0.0, size.x, MARKER_THICKNESS), MARKER_COLOR)
