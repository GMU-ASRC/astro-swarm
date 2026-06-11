extends Control

signal canvas_mutated

const BLOCK_DROP_ZONE := preload("res://ui/workspace/BlockDropZone.gd")

var _panning: bool = false

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_panning = event.pressed
	elif event is InputEventMouseMotion and _panning:
		var scroll := get_parent() as ScrollContainer
		if scroll != null:
			scroll.scroll_horizontal -= int(event.relative.x)
			scroll.scroll_vertical -= int(event.relative.y)

func spawn_stack(pos: Vector2) -> VBoxContainer:
	var zone := VBoxContainer.new()
	zone.set_script(BLOCK_DROP_ZONE)
	zone.add_theme_constant_override("separation", 4)
	zone.position = pos
	add_child(zone)
	zone.blocks_mutated.connect(_on_zone_mutated)
	return zone

func remove_empty_stacks():
	for child in get_children():
		if child is VBoxContainer and child.get_child_count() == 0:
			child.queue_free()

func resolve_overlaps():
	await get_tree().process_frame
	await get_tree().process_frame
	var placed: Array = []
	var changed := false
	for s in get_children():
		if not (s is VBoxContainer) or s.get_child_count() == 0:
			continue
		var guard := 0
		while guard < 50:
			guard += 1
			var rect := Rect2(s.position, s.size)
			var hit = null
			for pr in placed:
				if rect.intersects(pr):
					hit = pr
					break
			if hit == null:
				break
			s.position.y = hit.position.y + hit.size.y + 14.0
			changed = true
		placed.append(Rect2(s.position, s.size))
	if changed:
		canvas_mutated.emit()

func _on_zone_mutated():
	canvas_mutated.emit()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("blocks"):
		BLOCK_DROP_ZONE.clear_active()
		return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	BLOCK_DROP_ZONE.clear_active()
	var blocks: Array = data.get("blocks", [])
	if blocks.is_empty():
		return
	var zone := spawn_stack(at_position)
	for b in blocks:
		if is_instance_valid(b):
			if b.get_parent() != null:
				b.get_parent().remove_child(b)
			zone.add_child(b)
	canvas_mutated.emit()
