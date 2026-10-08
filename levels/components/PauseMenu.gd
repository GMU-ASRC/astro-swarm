extends CanvasLayer

signal leave_requested(scene_path: String)

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")
const SETTINGS_SCENE := preload("res://levels/menus/SettingsScene.tscn")

const PLAYER_BASE_SCENE := "res://levels/menus/PlayerBaseScene.tscn"
const MAIN_MENU_SCENE := "res://levels/menus/HomeScene.tscn"
const LEVELS_SCENE := "res://levels/menus/LevelsScene.tscn"

const CARD_COLOR := Color(0.129, 0.122, 0.196, 1.0)
const CARD_EDGE := Color(0.318, 0.306, 0.463, 1.0)
const TITLE_COLOR := Color(0.93, 0.94, 1.0, 1.0)
const BACKDROP_COLOR := Color(0, 0, 0, 0.6)
const CARD_WIDTH := 320.0
const BUTTON_FONT_SIZE := 12

var _panel: Control
var _settings: Control

func _ready():
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false

func is_open() -> bool:
	return _panel.visible or _settings != null

func open():
	if is_open():
		return
	get_tree().paused = true
	_panel.visible = true

func resume():
	_close_settings()
	_panel.visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent):
	if not (event is InputEventKey) or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if _settings != null:
		_close_settings()
	elif _panel.visible:
		resume()
	else:
		open()

func _build():
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_theme_stylebox_override("panel", _card_style())
	center.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(title)

	_add_button(column, "RESUME", HUD_BUTTONS.Kind.PRIMARY, resume)
	_add_button(column, "LEVELS", HUD_BUTTONS.Kind.NEUTRAL, func(): leave_requested.emit(LEVELS_SCENE))
	_add_button(column, "PLAYER BASE", HUD_BUTTONS.Kind.NEUTRAL, func(): leave_requested.emit(PLAYER_BASE_SCENE))
	_add_button(column, "SETTINGS", HUD_BUTTONS.Kind.NEUTRAL, _open_settings)
	_add_button(column, "MAIN MENU", HUD_BUTTONS.Kind.BACK, func(): leave_requested.emit(MAIN_MENU_SCENE))

func _add_button(column: VBoxContainer, text: String, kind: int, handler: Callable):
	var button := HUD_BUTTONS.make(text, kind, BUTTON_FONT_SIZE)
	button.pressed.connect(handler)
	column.add_child(button)

func _open_settings():
	_panel.visible = false
	_settings = SETTINGS_SCENE.instantiate()
	_settings.embedded = true
	_settings.closed.connect(_close_settings)
	add_child(_settings)

func _close_settings():
	if _settings == null:
		return
	_settings.queue_free()
	_settings = null
	if get_tree().paused:
		_panel.visible = true

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.border_color = CARD_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(24)
	return style
