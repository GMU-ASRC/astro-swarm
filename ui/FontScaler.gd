extends Node

const FONT_SIZE_KEYS := ["font_size", "normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]
const CONTROL_META := "font_scaler_sizes"
const THEME_META := "font_scaler_theme_sizes"

var text_scale: float = 1.0
var _base_fallback_size: int = -1
var _scaled_themes: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base_fallback_size = ThemeDB.fallback_font_size
	get_tree().node_added.connect(_on_node_added)

func set_text_scale(value: float):
	text_scale = value
	ThemeDB.fallback_font_size = _scaled(_base_fallback_size)
	_track_theme(ThemeDB.get_project_theme())
	for theme in _scaled_themes:
		_scale_theme(theme)
	_rescale_tree(get_tree().root)

func _on_node_added(node: Node):
	if node is Control:
		call_deferred("_scale_control", node)

func _rescale_tree(node: Node):
	if node is Control:
		_scale_control(node)
	for child in node.get_children():
		_rescale_tree(child)

func _scale_control(control: Control):
	if not is_instance_valid(control):
		return
	if control.theme != null:
		_track_theme(control.theme)
	var sizes: Dictionary = control.get_meta(CONTROL_META, {})
	for key in FONT_SIZE_KEYS:
		if not control.has_theme_font_size_override(key):
			continue
		var current: int = control.get_theme_font_size(key)
		if not sizes.has(key) or sizes[key]["applied"] != current:
			sizes[key] = {"base": current, "applied": current}
		var target: int = _scaled(sizes[key]["base"])
		sizes[key]["applied"] = target
		if target != current:
			control.add_theme_font_size_override(key, target)
	if not sizes.is_empty():
		control.set_meta(CONTROL_META, sizes)

func _track_theme(theme: Theme):
	if theme == null or _scaled_themes.has(theme):
		return
	_scaled_themes.append(theme)
	_scale_theme(theme)

func _scale_theme(theme: Theme):
	if not theme.has_meta(THEME_META):
		theme.set_meta(THEME_META, _theme_base_sizes(theme))
	var base: Dictionary = theme.get_meta(THEME_META)
	if base.has("default"):
		theme.default_font_size = _scaled(base["default"])
	for entry in base.get("types", []):
		theme.set_font_size(entry["name"], entry["type"], _scaled(entry["size"]))

func _theme_base_sizes(theme: Theme) -> Dictionary:
	var base := {"types": []}
	if theme.has_default_font_size():
		base["default"] = theme.default_font_size
	for type_name in theme.get_font_size_type_list():
		for size_name in theme.get_font_size_list(type_name):
			base["types"].append({"type": type_name, "name": size_name, "size": theme.get_font_size(size_name, type_name)})
	return base

func _scaled(size: int) -> int:
	return maxi(1, roundi(size * text_scale))
