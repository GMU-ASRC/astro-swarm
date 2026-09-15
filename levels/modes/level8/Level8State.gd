extends RefCounted

enum Stage { ALLOCATE, ASSAULT_A, ASSAULT_B, DONE }

const PLANET_A := 0
const PLANET_B := 1

const TOTAL_DEFENDERS    := 10    # count, defenders that start on planet A
const EVADERS_PER_PLANET := 5     # count, evaders each planet faces
const ALLOCATE_SECONDS   := 150.0 # seconds of the deployment window
const ASSAULT_SECONDS    := 120.0 # seconds each planet's assault may run
const RECORD_FPS         := 15.0  # frames/second written into the submitted replay

const SEED_B_OFFSET := 493117
const SEED_B_MODULO := 999983

static var running: bool = false
static var deploying: bool = false
static var stage: int = Stage.ALLOCATE
static var garrisons: Array = [[], []]
static var allocate_remaining: float = ALLOCATE_SECONDS
static var results: Array = [{}, {}]
static var frames: Array = []
static var trips: int = 0
static var delivered: int = 0
static var cloaked: bool = false
static var shuttle_parked: bool = false
static var shuttle_position: Vector2 = Vector2.ZERO
static var shuttle_rotation: float = 0.0

static func planet_seed(planet: int) -> int:
	var base: int = PlayerData.planet_seed
	if planet == PLANET_A:
		return base
	return (base + SEED_B_OFFSET) % SEED_B_MODULO + 1

static func other_planet(planet: int) -> int:
	return PLANET_B if planet == PLANET_A else PLANET_A

static func reset(scatter: Array):
	running = true
	deploying = false
	stage = Stage.ALLOCATE
	garrisons = [scatter.duplicate(true), []]
	allocate_remaining = ALLOCATE_SECONDS
	results = [{}, {}]
	frames = []
	trips = 0
	delivered = 0
	cloaked = false
	shuttle_parked = false

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

static func park_shuttle(position: Vector2, rotation: float):
	shuttle_parked = true
	shuttle_position = position
	shuttle_rotation = rotation

static func record_result(planet: int, result: Dictionary):
	results[planet] = result

static func evaders_total() -> int:
	return EVADERS_PER_PLANET * 2

static func destroyed_total() -> int:
	return int(results[PLANET_A].get("destroyed", 0)) + int(results[PLANET_B].get("destroyed", 0))

static func breached_total() -> int:
	return int(results[PLANET_A].get("breached", 0)) + int(results[PLANET_B].get("breached", 0))

static func both_held() -> bool:
	return breached_total() == 0 and destroyed_total() == evaders_total()

static func hold_rate() -> float:
	return 100.0 * float(destroyed_total()) / float(evaders_total())
