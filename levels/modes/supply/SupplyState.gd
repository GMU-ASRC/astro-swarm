extends RefCounted

enum Stage { ALLOCATE, ASSAULT, DONE }

const PLANET_A := 0
const PLANET_LETTERS := ["A", "B", "C", "D"]

const ALLOCATE_SECONDS   := 30.0  # seconds of the deployment window
const ASSAULT_SECONDS    := 150.0 # seconds the assault on every planet may run
const ATTACK_DELAY       := 3.0   # seconds into the assault before the first evader arrives
const ATTACK_SPAN        := 60.0  # seconds over which every evader is sent in
const RECORD_FPS         := 15.0  # frames/second written into the submitted replay

const SEED_OFFSET := 493117
const SEED_MODULO := 999983

static var level_id: String = ""
static var planet_count: int = 2
static var defender_total: int = 10
static var running: bool = false
static var deploying: bool = false
static var stage: int = Stage.ALLOCATE
static var assault_elapsed: float = 0.0
static var attack_queue: Array = []
static var next_attack: float = 0.0
static var garrisons: Array = []
static var allocate_remaining: float = ALLOCATE_SECONDS
static var results: Array = []
static var frames: Array = []
static var genome_switch_frames: Array = []
static var trips: int = 0
static var delivered: int = 0
static var cloaked: bool = false
static var shuttle_parked: bool = false
static var shuttle_position: Vector2 = Vector2.ZERO
static var shuttle_rotation: float = 0.0
static var came_from: int = PLANET_A
static var gate_along: float = -1.0
static var crossings: Array = []

static func letter(planet: int) -> String:
	return PLANET_LETTERS[planet]

static func planet_seed(planet: int) -> int:
	var base: int = PlayerData.planet_seed
	if planet == PLANET_A:
		return base
	return (base + SEED_OFFSET * planet) % SEED_MODULO + 1

static func reset(for_level: String, planets: int, scatter: Array):
	level_id = for_level
	planet_count = planets
	running = true
	deploying = false
	stage = Stage.ALLOCATE
	assault_elapsed = 0.0
	attack_queue = []
	next_attack = 0.0
	garrisons = [scatter.duplicate(true)]
	results = [{}]
	for _planet in planets - 1:
		garrisons.append([])
		results.append({})
	allocate_remaining = ALLOCATE_SECONDS
	frames = []
	genome_switch_frames = []
	trips = 0
	delivered = 0
	cloaked = false
	shuttle_parked = false
	came_from = PLANET_A
	gate_along = -1.0
	crossings = []

static func garrison(planet: int) -> Array:
	return garrisons[planet]

# The ships of the planet the player is standing on are live nodes, so the level
# writes their positions back here whenever it hands the scene over.
static func capture(planet: int, placements: Array):
	garrisons[planet] = placements.duplicate(true)

static func detach(planet: int) -> bool:
	if garrisons[planet].is_empty():
		return false
	garrisons[planet].remove_at(garrisons[planet].size() - 1)
	return true

static func fullest_planet_except(planet: int) -> int:
	var best: int = -1
	for other in planet_count:
		if other == planet or garrisons[other].is_empty():
			continue
		if best < 0 or garrisons[other].size() > garrisons[best].size():
			best = other
	return best

static func send_crossing(from_planet: int, to_planet: int, along: float, seconds: float, marker: Dictionary = {}):
	var crossing := {"from": from_planet, "to": to_planet, "along": along, "remaining": seconds}
	crossing.merge(marker)
	crossings.append(crossing)

static func tick_crossings(delta: float) -> Array:
	var arrived: Array = []
	var still: Array = []
	for crossing in crossings:
		crossing["remaining"] = float(crossing["remaining"]) - delta
		if float(crossing["remaining"]) <= 0.0:
			arrived.append(crossing)
		else:
			still.append(crossing)
	crossings = still
	return arrived

static func take_crossings() -> Array:
	var all: Array = crossings
	crossings = []
	return all

static func crossings_to(planet: int) -> int:
	var count: int = 0
	for crossing in crossings:
		if int(crossing["to"]) == planet:
			count += 1
	return count

static func park_shuttle(position: Vector2, rotation: float):
	shuttle_parked = true
	shuttle_position = position
	shuttle_rotation = rotation

# Every planet faces the same number of evaders, but the order they arrive in
# is shuffled, so the next one can land on any planet.
static func begin_assault(rng: RandomNumberGenerator):
	stage = Stage.ASSAULT
	assault_elapsed = 0.0
	attack_queue = []
	for planet in planet_count:
		results[planet] = {
			"defenders": garrisons[planet].size(),
			"destroyed": 0,
			"breached": 0,
			"lost": 0,
			"detect": -1.0,
			"goal": -1.0,
		}
		for _evader in evaders_per_planet():
			attack_queue.append(planet)
	for index in range(attack_queue.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: int = attack_queue[index]
		attack_queue[index] = attack_queue[other]
		attack_queue[other] = held
	next_attack = ATTACK_DELAY

static func attack_interval() -> float:
	return ATTACK_SPAN / float(maxi(1, evaders_total()))

static func evaders_per_planet() -> int:
	return floori(float(defender_total) / float(planet_count))

static func evaders_total() -> int:
	return evaders_per_planet() * planet_count

static func result_total(key: String) -> int:
	var total: int = 0
	for result in results:
		total += int(result.get(key, 0))
	return total

static func destroyed_total() -> int:
	return result_total("destroyed")

static func breached_total() -> int:
	return result_total("breached")

static func all_held() -> bool:
	return breached_total() == 0 and destroyed_total() == evaders_total()

static func hold_rate() -> float:
	return 100.0 * float(destroyed_total()) / float(evaders_total())
