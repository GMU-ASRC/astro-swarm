extends RefCounted

const CORNER := 4.0
const NOTCH_LEFT := 12.0
const NOTCH_WIDTH := 16.0
const NOTCH_SLANT := 4.0
const NOTCH_DEPTH := 5.0
const HAT_HEIGHT := 7.0
const HAT_RISE := 10.0
const HAT_MAX_WIDTH := 96.0
const ARM_WIDTH := 16.0

static func outline(size: Vector2, is_hat: bool, mouth: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var top: float = HAT_HEIGHT if is_hat else 0.0
	if is_hat:
		_add_hat_top(points, size.x)
	else:
		_add_notched_top(points, size.x)
	if mouth.size.y > 0.0:
		_add_mouth(points, size.x, mouth)
	points.append(Vector2(size.x, maxf(top + CORNER, size.y - CORNER)))
	points.append(Vector2(size.x - CORNER, size.y))
	_add_tab(points, 0.0, size.y)
	points.append(Vector2(CORNER, size.y))
	points.append(Vector2(0.0, size.y - CORNER))
	return points

static func shifted(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + offset)
	return result

static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not points.is_empty():
		result.append(points[0])
	return result

static func _add_notched_top(points: PackedVector2Array, width: float):
	var notch_end: float = NOTCH_LEFT + NOTCH_SLANT * 2.0 + NOTCH_WIDTH
	points.append(Vector2(0.0, CORNER))
	points.append(Vector2(CORNER, 0.0))
	points.append(Vector2(NOTCH_LEFT, 0.0))
	points.append(Vector2(NOTCH_LEFT + NOTCH_SLANT, NOTCH_DEPTH))
	points.append(Vector2(notch_end - NOTCH_SLANT, NOTCH_DEPTH))
	points.append(Vector2(notch_end, 0.0))
	points.append(Vector2(width - CORNER, 0.0))
	points.append(Vector2(width, CORNER))

static func _add_hat_top(points: PackedVector2Array, width: float):
	var hat_width: float = minf(HAT_MAX_WIDTH, width * 0.6)
	points.append(Vector2(0.0, HAT_HEIGHT))
	points.append(Vector2(HAT_RISE, 0.0))
	points.append(Vector2(hat_width - HAT_RISE, 0.0))
	points.append(Vector2(hat_width, HAT_HEIGHT))
	points.append(Vector2(width - CORNER, HAT_HEIGHT))
	points.append(Vector2(width, HAT_HEIGHT + CORNER))

static func _add_mouth(points: PackedVector2Array, width: float, mouth: Rect2):
	points.append(Vector2(width, mouth.position.y - CORNER))
	points.append(Vector2(width - CORNER, mouth.position.y))
	_add_tab(points, mouth.position.x, mouth.position.y)
	points.append(Vector2(mouth.position.x, mouth.position.y))
	points.append(Vector2(mouth.position.x, mouth.end.y))
	points.append(Vector2(width - CORNER, mouth.end.y))
	points.append(Vector2(width, mouth.end.y + CORNER))

static func _add_tab(points: PackedVector2Array, left: float, y: float):
	var notch_end: float = left + NOTCH_LEFT + NOTCH_SLANT * 2.0 + NOTCH_WIDTH
	points.append(Vector2(notch_end, y))
	points.append(Vector2(notch_end - NOTCH_SLANT, y + NOTCH_DEPTH))
	points.append(Vector2(left + NOTCH_LEFT + NOTCH_SLANT, y + NOTCH_DEPTH))
	points.append(Vector2(left + NOTCH_LEFT, y))
