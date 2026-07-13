extends "res://simulations/farp/BenchBase.gd"

const PLACEMENT_SEED_OFFSET := 700000

var _placement_rng := RandomNumberGenerator.new()

func _defender_count() -> int:
	if _placements.is_empty():
		return RING_COUNT
	return _placements.size()

func _placements_for_trial(_trial: int) -> Array:
	# The placement runs grade the layout the player actually submitted; only the
	# enemy spawn varies per trial. The ring sweep still re-randomizes its own ring.
	if not _placements.is_empty():
		return _placements
	return _scatter_layout()

func _scatter_layout() -> Array:
	_placement_rng.seed = _seed + PLACEMENT_SEED_OFFSET
	var out: Array = []
	for _i in _defender_count():
		var pos: Vector2 = _scatter_point()
		for _attempt in SCATTER_ATTEMPTS:
			if _is_clear_of(pos, out):
				break
			pos = _scatter_point()
		out.append({"pos": pos, "rot": _placement_rng.randf() * TAU})
	return out

func _scatter_point() -> Vector2:
	var angle: float = _placement_rng.randf() * TAU
	var radius: float = _placement_rng.randf_range(PLACE_MIN, SCATTER_MAX)
	return PLANET_CENTER + Vector2(radius, 0.0).rotated(angle)

func _is_clear_of(pos: Vector2, placements: Array) -> bool:
	for placement in placements:
		if pos.distance_to(placement.pos) < SCATTER_SPACING:
			return false
	return true
