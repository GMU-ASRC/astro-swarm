extends RefCounted

const MOON := preload("res://entities/planet/PlanetMoon.tscn")
const MOON_PIXELS := 52.0

static func make(moon_seed: int, display_size: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(display_size, display_size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var moon := MOON.instantiate() as Control
	holder.add_child(moon)
	moon.generate(moon_seed, MOON_PIXELS)
	var scale_factor: float = display_size / MOON_PIXELS
	moon.scale = Vector2(scale_factor, scale_factor)
	moon.position = Vector2.ZERO
	_ignore_mouse(moon)
	return holder

static func _ignore_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
