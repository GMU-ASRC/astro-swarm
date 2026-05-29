extends Area2D

const HULL_BITS := {0: 16, 1: 32}

var target_team: int = 1
var damage: float = 1.0
var speed: float = 460.0
var color: Color = Color(1, 1, 1, 1)

var _life: float = 2.0

func _ready():
	z_index = 6
	collision_layer = 0
	collision_mask = HULL_BITS[target_team]
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	queue_redraw()

func _physics_process(delta: float):
	global_position += Vector2.RIGHT.rotated(rotation) * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D):
	var ship = area.get_parent()
	if ship != null and ship.is_in_group("ships") and ship.has_method("take_damage") and ship.team == target_team:
		ship.take_damage(damage)
		queue_free()

func _draw():
	draw_line(Vector2(-5.0, 0.0), Vector2(4.0, 0.0), color, 2.0, true)
	draw_circle(Vector2(4.0, 0.0), 2.5, color)
