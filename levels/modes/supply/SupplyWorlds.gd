extends Node2D

# The planets the player is not standing on keep fighting through the assault.
# Their ships live here, hidden under the scene tree root, so they survive the
# scene changes that carry the player from planet to planet.
const STATE := preload("res://levels/modes/supply/SupplyState.gd")

var _layers: Array = []
var _defenders: Array = []
var _evaders: Array = []

func setup(planets: int):
	for _planet in planets:
		var layer := Node2D.new()
		add_child(layer)
		_layers.append(layer)
		_defenders.append([])
		_evaders.append([])

func adopt_defender(planet: int, ship: Node2D):
	ship.reparent(_layers[planet])
	_defenders[planet].append(ship)

func adopt_evader(planet: int, evader: Node2D):
	evader.reparent(_layers[planet])
	_evaders[planet].append(evader)

func take_defenders(planet: int) -> Array:
	var ships: Array = _live(_defenders[planet])
	_defenders[planet] = []
	return ships

func take_evaders(planet: int) -> Array:
	var ships: Array = _live(_evaders[planet])
	_evaders[planet] = []
	return ships

func all_defenders() -> Array:
	var out: Array = []
	for ships in _defenders:
		out.append_array(_live(ships))
	return out

func defender_count(planet: int) -> int:
	return _live(_defenders[planet]).size()

# Sends one of a planet's defenders off through its gate. The ship itself is
# freed here; it comes back to life wherever it lands.
func release_defender(planet: int) -> bool:
	var ships: Array = _live(_defenders[planet])
	if ships.is_empty():
		return false
	var ship: Node2D = ships.pop_back()
	ship.queue_free()
	_defenders[planet] = ships
	return true

func live_defender_count() -> int:
	return all_defenders().size()

func live_evader_count() -> int:
	var count: int = 0
	for ships in _evaders:
		count += _live(ships).size()
	return count

func freeze():
	for ships in _defenders + _evaders:
		for ship in _live(ships):
			ship.set_physics_process(false)

# Settles every evader on the planets nobody is watching, the same way a level
# does for its own: a landing is a breach, a touch is a capture, and with
# attrition the capturing defender goes down with it. Returns the planets that
# took a breach this frame.
func resolve(goal_center: Vector2, goal_radius: float, attrition: bool) -> Array:
	var breached_planets: Array = []
	for planet in _evaders.size():
		if _evaders[planet].is_empty():
			continue
		_defenders[planet] = _live(_defenders[planet])
		var tally: Dictionary = STATE.results[planet]
		var still: Array = []
		for evader in _live(_evaders[planet]):
			if float(tally["detect"]) < 0.0 and _seen(planet, evader):
				tally["detect"] = STATE.assault_elapsed
			if evader.global_position.distance_to(goal_center) <= goal_radius:
				tally["breached"] = int(tally["breached"]) + 1
				if float(tally["goal"]) < 0.0:
					tally["goal"] = STATE.assault_elapsed
				evader.queue_free()
				if not breached_planets.has(planet):
					breached_planets.append(planet)
				continue
			var catcher: Node2D = _touching(planet, evader)
			if catcher == null:
				still.append(evader)
				continue
			tally["destroyed"] = int(tally["destroyed"]) + 1
			evader.queue_free()
			if attrition:
				_defenders[planet].erase(catcher)
				catcher.queue_free()
				tally["lost"] = int(tally["lost"]) + 1
		_evaders[planet] = still
	return breached_planets

func _seen(planet: int, evader: Node2D) -> bool:
	for ship in _defenders[planet]:
		var to_evader: Vector2 = evader.global_position - ship.global_position
		if to_evader.length() > ship.view_distance:
			continue
		if absf(angle_difference(ship.rotation, to_evader.angle())) <= deg_to_rad(ship.fov_degrees * 0.5):
			return true
	return false

func _touching(planet: int, evader: Node2D) -> Node2D:
	for ship in _defenders[planet]:
		if ship.global_position.distance_to(evader.global_position) <= ship.hull_radius + evader.hull_radius:
			return ship
	return null

func _live(ships: Array) -> Array:
	var out: Array = []
	for ship in ships:
		if is_instance_valid(ship) and not ship.is_queued_for_deletion():
			out.append(ship)
	return out
