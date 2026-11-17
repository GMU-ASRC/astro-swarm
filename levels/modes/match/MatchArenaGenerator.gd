extends RefCounted

const ARENA_SIZES := [Vector2(8000.0, 4800.0), Vector2(9000.0, 5400.0), Vector2(10000.0, 6000.0)]
const EDGE_GAP := 320.0
const HOME_EDGE_GAP := 700.0
const HOME_MIN_GAP_FRACTION := 0.55
const HOME_CLEARANCE := 750.0
const SITE_SPACING := 620.0
const OPEN_SITES_PER_MEGAPIXEL := 0.3
const PLACEMENT_ATTEMPTS := 300
const STARS_PER_MEGAPIXEL := 40.0
const NEBULAE_PER_MEGAPIXEL := 0.18
const BELTS_PER_MEGAPIXEL := 0.12
const BELT_CLEARANCE := 220.0

const HOME_SITE_RINGS := [
	{"kind": "standard", "distance_min": 750.0, "distance_max": 1100.0},
	{"kind": "rich", "distance_min": 1400.0, "distance_max": 2000.0},
]

const SITE_KINDS := {
	"rich": {"radius_min": 34.0, "radius_max": 46.0, "max_dust": 180.0, "regen": 4.0, "weight": 3},
	"standard": {"radius_min": 50.0, "radius_max": 68.0, "max_dust": 300.0, "regen": 2.0, "weight": 5},
	"giant": {"radius_min": 76.0, "radius_max": 96.0, "max_dust": 520.0, "regen": 1.2, "weight": 2},
}
const NEBULA_COLORS := [
	Color(0.45, 0.25, 0.75, 1.0),
	Color(0.20, 0.35, 0.80, 1.0),
	Color(0.75, 0.25, 0.45, 1.0),
	Color(0.20, 0.60, 0.60, 1.0),
]

static func generate(arena_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = arena_seed
	var arena: Vector2 = ARENA_SIZES[rng.randi_range(0, ARENA_SIZES.size() - 1)]
	var homes: Array = _place_homes(arena, rng)
	var sites: Array = []
	for ring in HOME_SITE_RINGS:
		for home in homes:
			_place_site_near(home, ring, arena, homes, sites, rng)
	var open_count: int = int(_megapixels(arena) * OPEN_SITES_PER_MEGAPIXEL)
	for _index in open_count:
		var kind: String = _pick_kind(rng)
		var radius: float = _random_radius(kind, rng)
		var point: Vector2 = _find_open_point(arena, homes, sites, radius, HOME_CLEARANCE, rng)
		if point != Vector2.INF:
			sites.append(_make_site(point, kind, radius, rng))
	return {
		"arena": arena,
		"homes": homes,
		"home_seeds": [rng.randi(), rng.randi()],
		"sites": sites,
		"stars": _make_stars(arena, rng),
		"nebulae": _make_nebulae(arena, rng),
		"asteroids": _make_belts(arena, homes, sites, rng),
	}

static func _megapixels(arena: Vector2) -> float:
	return arena.x * arena.y / 1000000.0

static func _place_homes(arena: Vector2, rng: RandomNumberGenerator) -> Array:
	var min_gap: float = arena.length() * HOME_MIN_GAP_FRACTION
	var first_home: Vector2 = _random_home_point(arena, rng)
	var second_home: Vector2 = arena - first_home
	for _attempt in PLACEMENT_ATTEMPTS:
		var candidate: Vector2 = _random_home_point(arena, rng)
		if candidate.distance_to(first_home) >= min_gap:
			second_home = candidate
			break
	if rng.randf() < 0.5:
		return [second_home, first_home]
	return [first_home, second_home]

static func _random_home_point(arena: Vector2, rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(HOME_EDGE_GAP, arena.x - HOME_EDGE_GAP), rng.randf_range(HOME_EDGE_GAP, arena.y - HOME_EDGE_GAP))

static func _place_site_near(home: Vector2, ring: Dictionary, arena: Vector2, homes: Array, sites: Array, rng: RandomNumberGenerator):
	var kind: String = ring["kind"]
	for _attempt in PLACEMENT_ATTEMPTS:
		var angle: float = rng.randf() * TAU
		var distance: float = rng.randf_range(ring["distance_min"], ring["distance_max"])
		var point: Vector2 = home + Vector2(distance, 0.0).rotated(angle)
		var radius: float = _random_radius(kind, rng)
		if _is_open(point, radius, arena, homes, sites, float(ring["distance_min"]) - 50.0):
			sites.append(_make_site(point, kind, radius, rng))
			return

static func _find_open_point(arena: Vector2, homes: Array, sites: Array, radius: float, home_clearance: float, rng: RandomNumberGenerator) -> Vector2:
	for _attempt in PLACEMENT_ATTEMPTS:
		var point := Vector2(rng.randf_range(EDGE_GAP, arena.x - EDGE_GAP), rng.randf_range(EDGE_GAP, arena.y - EDGE_GAP))
		if _is_open(point, radius, arena, homes, sites, home_clearance):
			return point
	return Vector2.INF

static func _is_open(point: Vector2, radius: float, arena: Vector2, homes: Array, sites: Array, home_clearance: float) -> bool:
	if point.x < EDGE_GAP or point.y < EDGE_GAP or point.x > arena.x - EDGE_GAP or point.y > arena.y - EDGE_GAP:
		return false
	for home in homes:
		if point.distance_to(home) < home_clearance:
			return false
	for site in sites:
		if point.distance_to(site["position"]) < SITE_SPACING + radius + float(site["radius"]):
			return false
	return true

static func _make_site(point: Vector2, kind: String, radius: float, rng: RandomNumberGenerator) -> Dictionary:
	var settings: Dictionary = SITE_KINDS[kind]
	return {
		"position": point,
		"kind": kind,
		"radius": radius,
		"max_dust": settings["max_dust"],
		"regen": settings["regen"],
		"seed": rng.randi(),
	}

static func _random_radius(kind: String, rng: RandomNumberGenerator) -> float:
	var settings: Dictionary = SITE_KINDS[kind]
	return rng.randf_range(settings["radius_min"], settings["radius_max"])

static func _pick_kind(rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for kind in SITE_KINDS:
		total += int(SITE_KINDS[kind]["weight"])
	var roll: int = rng.randi_range(1, total)
	for kind in SITE_KINDS:
		roll -= int(SITE_KINDS[kind]["weight"])
		if roll <= 0:
			return kind
	return "standard"

static func _make_stars(arena: Vector2, rng: RandomNumberGenerator) -> Array:
	var stars: Array = []
	for _index in int(_megapixels(arena) * STARS_PER_MEGAPIXEL):
		stars.append({
			"pos": Vector2(rng.randf_range(0.0, arena.x), rng.randf_range(0.0, arena.y)),
			"sz": 2.0 if rng.randf() < 0.85 else 4.0,
			"a": rng.randf_range(0.15, 0.6),
		})
	return stars

static func _make_nebulae(arena: Vector2, rng: RandomNumberGenerator) -> Array:
	var nebulae: Array = []
	for _index in maxi(3, int(_megapixels(arena) * NEBULAE_PER_MEGAPIXEL)):
		var radius: float = rng.randf_range(400.0, 900.0)
		var puffs: Array = []
		for _puff in rng.randi_range(4, 7):
			puffs.append({"offset": Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius)) * 0.5, "radius": radius * rng.randf_range(0.35, 0.7)})
		nebulae.append({
			"position": Vector2(rng.randf_range(0.0, arena.x), rng.randf_range(0.0, arena.y)),
			"color": NEBULA_COLORS[rng.randi_range(0, NEBULA_COLORS.size() - 1)],
			"puffs": puffs,
		})
	return nebulae

static func _make_belts(arena: Vector2, homes: Array, sites: Array, rng: RandomNumberGenerator) -> Array:
	var rocks: Array = []
	for _index in maxi(2, int(_megapixels(arena) * BELTS_PER_MEGAPIXEL)):
		var center: Vector2 = _find_open_point(arena, homes, sites, BELT_CLEARANCE, HOME_CLEARANCE + BELT_CLEARANCE, rng)
		if center == Vector2.INF:
			continue
		var direction: float = rng.randf() * PI
		var length: float = rng.randf_range(600.0, 1400.0)
		for _rock in rng.randi_range(30, 55):
			var along: float = rng.randf_range(-0.5, 0.5) * length
			var across: float = rng.randfn(0.0, 70.0)
			rocks.append({
				"pos": center + Vector2(along, across).rotated(direction),
				"sz": float(rng.randi_range(2, 6)) * 2.0,
				"shade": rng.randf_range(0.18, 0.34),
			})
	return rocks
