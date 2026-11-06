extends RefCounted

const ARENA_SIZES := [Vector2(4800.0, 2700.0), Vector2(5400.0, 3000.0), Vector2(6000.0, 3400.0)]
const HOME_EDGE_GAP := 650.0
const SITE_PAIRS_MIN := 3
const SITE_PAIRS_MAX := 5
const SITE_RADIUS_MIN := 45.0
const SITE_RADIUS_MAX := 75.0
const SITE_HOME_GAP := 800.0
const SITE_GAP := 480.0
const SITE_EDGE_GAP := 220.0
const PLACEMENT_ATTEMPTS := 60
const STAR_COUNT := 900

static func generate(arena_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = arena_seed
	var arena: Vector2 = ARENA_SIZES[rng.randi_range(0, ARENA_SIZES.size() - 1)]
	var first_home := Vector2(HOME_EDGE_GAP + rng.randf_range(0.0, 250.0), rng.randf_range(arena.y * 0.25, arena.y * 0.75))
	var homes: Array = [first_home, arena - first_home]
	var sites: Array = []
	if rng.randf() < 0.6:
		sites.append(_make_site(arena * 0.5, rng))
	var pair_count: int = rng.randi_range(SITE_PAIRS_MIN, SITE_PAIRS_MAX)
	for _pair in pair_count:
		var position: Vector2 = _find_site_position(arena, homes, sites, rng)
		if position == Vector2.INF:
			continue
		var site: Dictionary = _make_site(position, rng)
		sites.append(site)
		var mirrored: Dictionary = site.duplicate()
		mirrored["position"] = arena - position
		mirrored["seed"] = rng.randi()
		sites.append(mirrored)
	return {
		"arena": arena,
		"homes": homes,
		"home_seeds": [rng.randi(), rng.randi()],
		"sites": sites,
		"stars": _make_stars(arena, rng),
	}

static func _make_site(position: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	return {"position": position, "radius": rng.randf_range(SITE_RADIUS_MIN, SITE_RADIUS_MAX), "seed": rng.randi()}

static func _find_site_position(arena: Vector2, homes: Array, sites: Array, rng: RandomNumberGenerator) -> Vector2:
	for _attempt in PLACEMENT_ATTEMPTS:
		var candidate := Vector2(rng.randf_range(SITE_EDGE_GAP, arena.x * 0.5 - SITE_GAP * 0.5), rng.randf_range(SITE_EDGE_GAP, arena.y - SITE_EDGE_GAP))
		if _is_clear(candidate, arena, homes, sites):
			return candidate
	return Vector2.INF

static func _is_clear(candidate: Vector2, arena: Vector2, homes: Array, sites: Array) -> bool:
	for home in homes:
		if candidate.distance_to(home) < SITE_HOME_GAP:
			return false
	for site in sites:
		if candidate.distance_to(site["position"]) < SITE_GAP:
			return false
		if (arena - candidate).distance_to(site["position"]) < SITE_GAP:
			return false
	return candidate.distance_to(arena - candidate) >= SITE_GAP

static func _make_stars(arena: Vector2, rng: RandomNumberGenerator) -> Array:
	var stars: Array = []
	for _i in STAR_COUNT:
		stars.append({
			"pos": Vector2(rng.randf_range(0.0, arena.x), rng.randf_range(0.0, arena.y)),
			"sz": 2.0 if rng.randf() < 0.85 else 4.0,
			"a": rng.randf_range(0.15, 0.6),
		})
	return stars
