extends Area2D

var view_distance: float = 150.0
var fov_degrees: float = 90.0
var color: Color = Color(0.141, 0.255, 0.722, 1.0)

var visible_targets: Array = []
var visible_objects: Array = []
var near_wall: bool = false
var _cone_polygon: PackedVector2Array

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var parent = get_parent()
	if parent and "type_id" in parent:
		var cfg := SimulationManager.get_type_config(parent.type_id)
		view_distance = cfg.view_distance
		fov_degrees = cfg.fov_degrees
		color = SimulationManager.get_type(parent.type_id).color
	call_deferred("generate_cone")

func generate_cone():
	var polygon := PackedVector2Array()
	polygon.append(Vector2.ZERO)
	var fov_rad := deg_to_rad(fov_degrees)
	var num_points := 18
	var start_angle := -fov_rad / 2.0
	for i in range(num_points + 1):
		var angle := start_angle + (fov_rad * i / float(num_points))
		polygon.append(Vector2.RIGHT.rotated(angle) * view_distance)
	if has_node("CollisionPolygon2D"):
		$CollisionPolygon2D.polygon = polygon
	_cone_polygon = polygon
	queue_redraw()

func _draw():
	if _cone_polygon.size() < 3:
		return
	var fill := Color(color.r, color.g, color.b, 0.09)
	var edge := Color(color.r, color.g, color.b, 0.40)
	draw_polygon(_cone_polygon, PackedColorArray([fill]))
	draw_line(_cone_polygon[0], _cone_polygon[1], edge, 1.0)
	draw_line(_cone_polygon[0], _cone_polygon[_cone_polygon.size() - 1], edge, 1.0)
	for i in range(1, _cone_polygon.size() - 1):
		draw_line(_cone_polygon[i], _cone_polygon[i + 1], edge, 1.0)

func _on_body_entered(body):
	if body != get_parent():
		if body.is_in_group("robots"):
			if not visible_targets.has(body):
				visible_targets.append(body)
		elif body.is_in_group("obstacles"):
			if not visible_objects.has(body):
				visible_objects.append(body)
			near_wall = true
		elif body is StaticBody2D:
			near_wall = true

func _on_body_exited(body):
	if visible_targets.has(body):
		visible_targets.erase(body)
	if visible_objects.has(body):
		visible_objects.erase(body)
	if body is StaticBody2D:
		var found_wall := false
		for b in get_overlapping_bodies():
			if b is StaticBody2D:
				found_wall = true
				break
		near_wall = found_wall
