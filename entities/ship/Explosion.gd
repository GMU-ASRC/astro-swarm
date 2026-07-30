extends Sprite2D

const TEXTURE_PATH := "res://assets/sprites/effects/explosion.png"
const LIFETIME := 0.45

var display_size: float = 64.0

var _age: float = 0.0
var _base_scale: float = 1.0

func _ready():
	z_index = 8
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture = load(TEXTURE_PATH)
	if texture != null:
		_base_scale = display_size / maxf(1.0, float(texture.get_width()))
	rotation = randf() * TAU
	scale = Vector2(_base_scale, _base_scale)

func _process(delta: float):
	_age += delta
	var t: float = clampf(_age / LIFETIME, 0.0, 1.0)
	var grow: float = _base_scale * (1.0 + t * 0.6)
	scale = Vector2(grow, grow)
	modulate.a = 1.0 - t
	if _age >= LIFETIME:
		queue_free()
