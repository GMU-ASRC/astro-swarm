extends "res://levels/modes/ScatterBase.gd"

const EXPLOSION := preload("res://entities/ship/Explosion.gd")

const EVADER_BLAST_SIZE   := 90.0  # pixels, drawn size of an evader explosion
const DEFENDER_BLAST_SIZE := 110.0 # pixels, drawn size of a defender explosion

var _evaders: Array = []
var _launched: int = 0
var _destroyed: int = 0
var _breached: int = 0
var _defenders_lost: int = 0

# A level with attrition destroys the defender that made the capture, so the
# line thins as the run goes on.
func _has_attrition() -> bool:
	return false

func _launch_label() -> String:
	return "LAUNCH ASSAULT (S) >"

func _reset_counters():
	_evaders.clear()
	_launched = 0
	_destroyed = 0
	_breached = 0
	_defenders_lost = 0

func _spawn_evader_at(spawn_pos: Vector2) -> Node2D:
	var evader := _make_scripted_evader(spawn_pos)
	_evaders.append(evader)
	_evader = evader
	_launched += 1
	return evader

func _clear_ships():
	super()
	for evader in _evaders:
		if is_instance_valid(evader):
			evader.queue_free()
	_evaders.clear()

func _finish(reason: String):
	for evader in _evaders:
		if is_instance_valid(evader):
			evader.set_physics_process(false)
	super(reason)

func _blast(point: Vector2, size: float):
	var effect := EXPLOSION.new()
	effect.display_size = size
	add_child(effect)
	effect.global_position = point

# Walks every live evader once a frame, logging the first sighting and then
# resolving whichever of the two endings it reached: the planet, or a defender.
func _resolve_evaders():
	var live: Array = []
	for evader in _evaders:
		if not is_instance_valid(evader):
			continue
		if _detect_time < 0.0 and _any_defender_sees(evader):
			_detect_time = _elapsed
		if _evader_reached_goal(evader):
			if _goal_time < 0.0:
				_goal_time = _elapsed
			_breach_evader(evader)
			continue
		var catcher: Node2D = _defender_touching(evader)
		if catcher != null:
			_destroy_evader(evader, catcher)
			continue
		live.append(evader)
	_evaders = live

func _breach_evader(evader: Node2D):
	_breached += 1
	_blast(evader.global_position, EVADER_BLAST_SIZE)
	evader.queue_free()
	_update_count()

func _destroy_evader(evader: Node2D, catcher: Node2D):
	_destroyed += 1
	if _capture_time < 0.0:
		_capture_time = _elapsed
	_blast(evader.global_position, EVADER_BLAST_SIZE)
	evader.queue_free()
	if _has_attrition() and is_instance_valid(catcher):
		_blast(catcher.global_position, DEFENDER_BLAST_SIZE)
		_defender_ships.erase(catcher)
		catcher.queue_free()
		_defenders_lost += 1
	_update_count()

func _live_defenders() -> int:
	var count: int = 0
	for ship in _defender_ships:
		if is_instance_valid(ship):
			count += 1
	return count

func _any_defender_sees(evader: Node2D) -> bool:
	var target: Vector2 = evader.global_position
	for ship in _defender_ships:
		if not is_instance_valid(ship):
			continue
		var to_evader: Vector2 = target - ship.global_position
		if to_evader.length() > ship.view_distance:
			continue
		if absf(angle_difference(ship.rotation, to_evader.angle())) <= deg_to_rad(ship.fov_degrees * 0.5):
			return true
	return false

func _defender_touching(evader: Node2D) -> Node2D:
	var target: Vector2 = evader.global_position
	for ship in _defender_ships:
		if not is_instance_valid(ship):
			continue
		if ship.global_position.distance_to(target) <= ship.hull_radius + evader.hull_radius:
			return ship
	return null

func _evader_reached_goal(evader: Node2D) -> bool:
	return evader.global_position.distance_to(_planet) <= PLANET_RADIUS + GOAL_MARGIN

func _capture_rate() -> float:
	if _launched < 1:
		return 0.0
	return 100.0 * float(_destroyed) / float(_launched)

func _attrition_summary() -> String:
	if not _has_attrition():
		return ""
	return "\nDefenders lost: %d of %d" % [_defenders_lost, _placements.size()]
