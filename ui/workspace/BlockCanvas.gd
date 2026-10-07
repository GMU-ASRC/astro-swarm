extends Control

signal canvas_mutated

const BLOCK_DROP_ZONE := preload("res://ui/workspace/BlockDropZone.gd")
const SIM := preload("res://autoloads/SimulationManager.gd")

const SNAP_DISTANCE_X := 60.0
const SNAP_DISTANCE_Y := 36.0
const STACK_GAP := 18.0

const ERROR_NOT_IN_EVENT := "If and Else blocks must be placed inside an event block (On start, Always, When ...)."
const ERROR_ELSE_WITHOUT_IF := "An Else block needs an If block directly above it."

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
	zone.add_theme_constant_override("separation", 0)
	zone.position = pos
	add_child(zone)
	zone.blocks_mutated.connect(_on_zone_mutated)
	return zone

func stack_zones() -> Array:
	var zones: Array = []
	for child in get_children():
		if child is VBoxContainer and not child.is_queued_for_deletion():
			zones.append(child)
	return zones

func remove_empty_stacks():
	for zone in stack_zones():
		if zone.get_child_count() == 0:
			zone.queue_free()

func collect_scripts() -> Array:
	remove_empty_stacks()
	var scripts: Array = []
	for zone in stack_zones():
		var blocks: Array = []
		for child in zone.get_children():
			if child.has_method("get_block_data") and not child.is_queued_for_deletion():
				blocks.append(child.get_block_data())
		if blocks.is_empty():
			continue
		scripts.append({"x": zone.position.x, "y": zone.position.y, "blocks": blocks})
	return scripts

func highlight_errors() -> Array:
	var messages: Array = []
	for zone in stack_zones():
		_check_blocks(zone, false, messages)
	return messages

func _check_blocks(zone: Node, inside_event: bool, messages: Array):
	var previous_type: String = ""
	for child in zone.get_children():
		var block = child
		if not block.has_method("get_block_data") or block.is_queued_for_deletion():
			continue
		var block_type: String = block.block_type
		var message: String = ""
		if SIM.is_conditional_block(block_type) and not inside_event:
			message = ERROR_NOT_IN_EVENT
		elif block_type == "else" and not previous_type.begins_with("if_"):
			message = ERROR_ELSE_WITHOUT_IF
		block.set_error(message)
		if message != "" and not messages.has(message):
			messages.append(message)
		if block.is_container():
			_check_blocks(block.get_children_zone(), inside_event or SIM.is_event_block(block_type), messages)
		previous_type = block_type

func resolve_overlaps():
	await get_tree().process_frame
	await get_tree().process_frame
	var placed: Array = []
	var changed := false
	for zone in stack_zones():
		if zone.get_child_count() == 0:
			continue
		var guard := 0
		while guard < 50:
			guard += 1
			var rect := Rect2(zone.position, zone.size)
			var hit = null
			for placed_rect in placed:
				if rect.intersects(placed_rect):
					hit = placed_rect
					break
			if hit == null:
				break
			zone.position.y = hit.position.y + hit.size.y + STACK_GAP
			changed = true
		placed.append(Rect2(zone.position, zone.size))
	if changed:
		canvas_mutated.emit()

func _on_zone_mutated():
	canvas_mutated.emit()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not BLOCK_DROP_ZONE.is_block_data(data):
		return false
	var snap: Dictionary = _find_snap_target(_drop_corner(at_position, data), data["blocks"])
	if snap.is_empty():
		BLOCK_DROP_ZONE.clear_active()
	else:
		snap.zone.show_insert_marker(snap.index)
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	BLOCK_DROP_ZONE.clear_active()
	var blocks: Array = data.get("blocks", [])
	if blocks.is_empty():
		return
	var corner: Vector2 = _drop_corner(at_position, data)
	var snap: Dictionary = _find_snap_target(corner, blocks)
	if snap.is_empty():
		var new_zone = spawn_stack(corner)
		new_zone.insert_blocks(blocks, 0)
	else:
		if snap.index == 0:
			snap.zone.position.y = corner.y
		snap.zone.insert_blocks(blocks, snap.index)
	resolve_overlaps()

func _drop_corner(at_position: Vector2, data: Dictionary) -> Vector2:
	var corner: Vector2 = at_position - data.get("grab_offset", Vector2.ZERO)
	return Vector2(maxf(0.0, corner.x), maxf(0.0, corner.y))

func _find_snap_target(corner: Vector2, blocks: Array) -> Dictionary:
	var dragged_height: float = _total_height(blocks)
	var best: Dictionary = {}
	var best_distance: float = INF
	for zone in stack_zones():
		if zone.get_child_count() == 0 or _contains_any(zone, blocks):
			continue
		if absf(corner.x - zone.position.x) > SNAP_DISTANCE_X:
			continue
		var below_distance: float = absf(corner.y - (zone.position.y + zone.size.y))
		if below_distance <= SNAP_DISTANCE_Y and below_distance < best_distance:
			best = {"zone": zone, "index": zone.get_child_count()}
			best_distance = below_distance
		var above_distance: float = absf(corner.y + dragged_height - zone.position.y)
		if above_distance <= SNAP_DISTANCE_Y and above_distance < best_distance:
			best = {"zone": zone, "index": 0}
			best_distance = above_distance
	return best

func _contains_any(zone: Node, blocks: Array) -> bool:
	for b in blocks:
		if is_instance_valid(b) and b.get_parent() == zone:
			return true
	return false

func _total_height(blocks: Array) -> float:
	var total := 0.0
	for b in blocks:
		if is_instance_valid(b):
			total += b.size.y
	return total
