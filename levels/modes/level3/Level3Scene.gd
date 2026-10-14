extends "res://levels/modes/WaveBase.gd"

const GROUP_WAVES := 2
const DEFENDER_OPTIONS := [5, 10, 15, 20, 25, 250, 500]
const SPAWN_JITTER := 0.35

func _level_id() -> String:
	return "farp3"

func _level_title() -> String:
	return "LEVEL 3 - HOLD THE WAVES"

func _defender_options() -> Array:
	return DEFENDER_OPTIONS

func _wave_total() -> int:
	return GROUP_WAVES

func _launch_wave():
	_wave += 1
	var wave_size: int = maxi(1, _placements.size())
	var base_angle: float = _rng.randf() * TAU
	for index in wave_size:
		var slice: float = TAU * float(index) / float(wave_size)
		var angle: float = base_angle + slice + _rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER)
		_spawn_evader_at(_planet + Vector2(EVADER_SPAWN_RADIUS, 0.0).rotated(angle))
	_update_count()
