extends ColorRect

const FOG_SHADER := preload("res://levels/modes/match/fog.gdshader")
const MAX_CIRCLES := 96

var _material: ShaderMaterial

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_material = ShaderMaterial.new()
	_material.shader = FOG_SHADER
	material = _material

func update_circles(camera: Camera2D, world_circles: Array):
	var view_size: Vector2 = get_viewport_rect().size
	var screen_center: Vector2 = camera.get_screen_center_position()
	var zoom: float = camera.zoom.x
	var packed := PackedVector3Array()
	for circle in world_circles:
		if packed.size() >= MAX_CIRCLES:
			break
		var screen_point: Vector2 = (circle["center"] - screen_center) * zoom + view_size * 0.5
		var screen_radius: float = float(circle["radius"]) * zoom
		if screen_point.x + screen_radius < 0.0 or screen_point.y + screen_radius < 0.0:
			continue
		if screen_point.x - screen_radius > view_size.x or screen_point.y - screen_radius > view_size.y:
			continue
		packed.append(Vector3(screen_point.x, screen_point.y, screen_radius))
	var used_count: int = packed.size()
	while packed.size() < MAX_CIRCLES:
		packed.append(Vector3.ZERO)
	_material.set_shader_parameter("circles", packed)
	_material.set_shader_parameter("circle_count", used_count)
	_material.set_shader_parameter("rect_size", view_size)
