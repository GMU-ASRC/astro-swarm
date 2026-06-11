extends VBoxContainer

signal blocks_mutated

const LINE_COLOR := Color(0.255, 0.463, 0.843, 1.0)

static var _active_zone = null

var drop_index: int = -1

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return can_accept(data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	do_drop(data)

func can_accept(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("blocks"):
		return false
	for b in data["blocks"]:
		if not is_instance_valid(b) or b == self or b.is_ancestor_of(self):
			_set_indicator(-1)
			return false
	_set_indicator(_calc_index())
	return true

func do_drop(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY or not data.has("blocks"):
		return
	var idx: int = drop_index if drop_index >= 0 else get_child_count()
	for b in data["blocks"]:
		if not is_instance_valid(b) or b == self or b.is_ancestor_of(self):
			continue
		if b.get_parent() != null:
			b.get_parent().remove_child(b)
		add_child(b)
		move_child(b, clampi(idx, 0, get_child_count() - 1))
		idx += 1
	_set_indicator(-1)
	blocks_mutated.emit()

func _calc_index() -> int:
	var my: float = get_local_mouse_position().y
	for i in get_child_count():
		var c := get_child(i) as Control
		if c == null:
			continue
		if my < c.position.y + c.size.y * 0.5:
			return i
	return get_child_count()

func _set_indicator(value: int):
	if value >= 0:
		if _active_zone != null and is_instance_valid(_active_zone) and _active_zone != self:
			_active_zone._clear_line()
		_active_zone = self
	elif _active_zone == self:
		_active_zone = null
	_set_line(value)

func _set_line(value: int):
	if drop_index != value:
		drop_index = value
		queue_redraw()

func _clear_line():
	_set_line(-1)

static func clear_active():
	if _active_zone != null and is_instance_valid(_active_zone):
		_active_zone._clear_line()
	_active_zone = null

func _notification(what: int):
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		_set_indicator(-1)

func _draw():
	if drop_index < 0:
		return
	var y: float = 0.0
	if drop_index >= get_child_count():
		if get_child_count() > 0:
			var last := get_child(get_child_count() - 1) as Control
			y = last.position.y + last.size.y
	else:
		var c := get_child(drop_index) as Control
		if c != null:
			y = c.position.y
	draw_line(Vector2(0.0, y), Vector2(size.x, y), LINE_COLOR, 3.0)
