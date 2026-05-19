extends CanvasLayer

signal dismissed

const MAIN_THEME = preload("res://ui/MainTheme.tres")

const PANEL_BG       := Color(0.945, 0.945, 0.957, 1.0)
const PANEL_BORDER   := Color(0.667, 0.667, 0.694, 1.0)
const TEXT_PRIMARY   := Color(0.137, 0.137, 0.196, 1.0)
const TEXT_SECONDARY := Color(0.40, 0.40, 0.45, 1.0)
const ACCENT_BLUE    := Color(0.176, 0.341, 0.714, 1.0)

var _status_label: Label
var _progress_bar: ProgressBar
var _path_label: Label
var _title_label: Label
var _close_btn: Button
var _open_btn: Button
var _folder_to_open: String = ""

func _init():
	layer = 100

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = MAIN_THEME
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", _build_panel_stylebox())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Exporting Video"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_status_label = Label.new()
	_status_label.text = "Preparing…"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 1
	_progress_bar.value = 0
	_progress_bar.show_percentage = true
	_progress_bar.custom_minimum_size = Vector2(0, 20)
	_progress_bar.add_theme_stylebox_override("background", _build_progress_bg())
	_progress_bar.add_theme_stylebox_override("fill", _build_progress_fill())
	_progress_bar.add_theme_color_override("font_color", TEXT_PRIMARY)
	vbox.add_child(_progress_bar)

	_path_label = Label.new()
	_path_label.text = ""
	_path_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_path_label.add_theme_font_size_override("font_size", 11)
	_path_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	_path_label.visible = false
	vbox.add_child(_path_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	_open_btn = Button.new()
	_open_btn.text = "Open Folder"
	_open_btn.focus_mode = Control.FOCUS_NONE
	_open_btn.visible = false
	_open_btn.pressed.connect(_on_open_folder)
	btn_row.add_child(_open_btn)

	_close_btn = Button.new()
	_close_btn.text = "Done"
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.visible = false
	_close_btn.pressed.connect(func(): dismissed.emit())
	btn_row.add_child(_close_btn)

func _build_panel_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	sb.shadow_size = 12
	return sb

func _build_progress_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.835, 0.835, 0.859, 1.0)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb

func _build_progress_fill() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACCENT_BLUE
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb

func set_progress(current: int, total: int):
	_progress_bar.max_value = max(1, total)
	_progress_bar.value = current
	_status_label.text = "Capturing frame %d / %d" % [current, total]

func set_status(text: String):
	_status_label.text = text

func show_success(path: String):
	_title_label.text = "Export Complete"
	_status_label.text = "Saved video to:"
	_path_label.text = path
	_path_label.visible = true
	_progress_bar.value = _progress_bar.max_value
	_folder_to_open = path.get_base_dir()
	_open_btn.text = "Open Folder"
	_open_btn.visible = true
	_close_btn.text = "Done"
	_close_btn.visible = true

func show_error(text: String, path: String = ""):
	_title_label.text = "Export Failed"
	_status_label.text = text
	if path.is_empty():
		_path_label.visible = false
		_open_btn.visible = false
	else:
		_path_label.text = path
		_path_label.visible = true
		_folder_to_open = path
		_open_btn.text = "Open Frames Folder"
		_open_btn.visible = true
	_close_btn.text = "Close"
	_close_btn.visible = true

func _on_open_folder():
	if _folder_to_open.is_empty():
		return
	OS.shell_open(_folder_to_open)
