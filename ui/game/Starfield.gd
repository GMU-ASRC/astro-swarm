extends Control

const LAYERS := [
	{ "count": 70, "scale": 0.20, "min_arm": 0, "max_arm": 1, "alpha": 0.45, "tw": 0.25 },
	{ "count": 45, "scale": 0.50, "min_arm": 1, "max_arm": 1, "alpha": 0.70, "tw": 0.45 },
	{ "count": 24, "scale": 1.00, "min_arm": 1, "max_arm": 2, "alpha": 1.00, "tw": 0.75 },
]

const STAR_COLORS := [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(0.55, 0.85, 1.0, 1.0),
	Color(0.45, 0.60, 1.0, 1.0),
	Color(1.0, 0.85, 0.55, 1.0),
	Color(1.0, 0.60, 0.85, 1.0),
	Color(0.78, 0.60, 1.0, 1.0),
	Color(0.60, 1.0, 0.70, 1.0),
	Color(1.0, 0.55, 0.45, 1.0),
]

var STAR_SEED := randi_range(0, 9999999)
const PIXEL := 2.0
const MAX_SHIFT := 28.0
const EASE := 9.0

var _layers: Array = []
var _time: float = 0.0
var _mouse_norm: Vector2 = Vector2.ZERO
var _mouse_target: Vector2 = Vector2.ZERO

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_regenerate)
	_regenerate()

func _regenerate():
	_layers.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	var area: Vector2 = size
	if area.x < 1.0 or area.y < 1.0:
		area = get_viewport_rect().size
	for cfg in LAYERS:
		var stars: Array = []
		var n: int = int(cfg["count"])
		for i in n:
			stars.append({
				"x": rng.randf() * area.x,
				"y": rng.randf() * area.y,
				"arm": rng.randi_range(int(cfg["min_arm"]), int(cfg["max_arm"])),
				"phase": rng.randf() * TAU,
				"tw": rng.randf_range(0.6, 1.6),
				"col": _pick_color(rng),
			})
		_layers.append({ "cfg": cfg, "stars": stars })
	queue_redraw()

func _pick_color(rng: RandomNumberGenerator) -> Color:
	if rng.randf() < 0.35:
		return STAR_COLORS[0]
	return STAR_COLORS[rng.randi_range(1, STAR_COLORS.size() - 1)]

func _process(delta: float):
	_time += delta
	var area: Vector2 = size
	if area.x > 1.0 and area.y > 1.0:
		var m: Vector2 = get_local_mouse_position()
		var n: Vector2 = (m - area * 0.5) / (area * 0.5)
		_mouse_target = n.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	_mouse_norm = _mouse_norm.lerp(_mouse_target, clampf(delta * EASE, 0.0, 1.0))
	queue_redraw()

func _draw():
	var area: Vector2 = size
	if area.x < 1.0 or area.y < 1.0:
		return
	for layer in _layers:
		var cfg: Dictionary = layer["cfg"]
		var scale_amt: float = float(cfg["scale"])
		var base_alpha: float = float(cfg["alpha"])
		var tw_amt: float = float(cfg["tw"])
		var off: Vector2 = -_mouse_norm * MAX_SHIFT * scale_amt
		for star in layer["stars"]:
			var px: float = snappedf(fposmod(float(star["x"]) + off.x, area.x), PIXEL)
			var py: float = snappedf(fposmod(float(star["y"]) + off.y, area.y), PIXEL)
			var pulse: float = 0.5 + 0.5 * sin(_time * float(star["tw"]) * 2.0 + float(star["phase"]))
			var twinkle: float = 1.0 - tw_amt + tw_amt * pulse
			var col: Color = star["col"]
			col.a = base_alpha * twinkle
			var arm: int = int(round(float(star["arm"]) * (0.4 + 0.6 * pulse)))
			if arm <= 0:
				draw_rect(Rect2(px, py, PIXEL, PIXEL), col, true)
			else:
				_draw_plus(Vector2(px, py), arm, col)

func _draw_plus(p: Vector2, arm: int, col: Color):
	draw_rect(Rect2(p.x, p.y, PIXEL, PIXEL), col, true)
	for i in range(1, arm + 1):
		var d: float = float(i) * PIXEL
		draw_rect(Rect2(p.x, p.y - d, PIXEL, PIXEL), col, true)
		draw_rect(Rect2(p.x, p.y + d, PIXEL, PIXEL), col, true)
		draw_rect(Rect2(p.x - d, p.y, PIXEL, PIXEL), col, true)
		draw_rect(Rect2(p.x + d, p.y, PIXEL, PIXEL), col, true)
