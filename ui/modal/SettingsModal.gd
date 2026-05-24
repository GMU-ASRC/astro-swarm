extends CanvasLayer

@onready var close_btn:   Button = $Root/Panel/VBox/Header/CloseButton
@onready var reset_btn:   Button = $Root/Panel/VBox/Footer/ResetButton
@onready var fit_btn:     Button = $Root/Panel/VBox/Footer/FitWindowButton

@onready var width_slider:  HSlider = $Root/Panel/VBox/Form/WidthSlider
@onready var width_value:   Label   = $Root/Panel/VBox/Form/WidthValue
@onready var height_slider: HSlider = $Root/Panel/VBox/Form/HeightSlider
@onready var height_value:  Label   = $Root/Panel/VBox/Form/HeightValue
@onready var controller_check:  CheckBox = $Root/Panel/VBox/ControllerCheck
@onready var multiplayer_check: CheckBox = $Root/Panel/VBox/MultiplayerCheck

const DEFAULTS := {
	"speed": 3.75, "turn_speed": 2.0, "view_distance": 3.75,
	"fov_degrees": 90.0, "time_scale": 1.0,
	"arena_width": 1280.0, "arena_height": 720.0,
	"controller_mode": false, "multiplayer": false,
}

func _ready():
	visible = false
	close_btn.pressed.connect(close)
	reset_btn.pressed.connect(_reset_defaults)
	fit_btn.pressed.connect(_fit_to_window)

	_bind_px(width_slider,  width_value,  "arena_width",    "%d m")
	_bind_px(height_slider, height_value, "arena_height",   "%d m")
	controller_check.toggled.connect(_on_controller_toggled)
	multiplayer_check.toggled.connect(_on_multiplayer_toggled)
	_load_from_settings()

func _bind(slider: HSlider, lbl: Label, key: String, fmt: String):
	slider.value_changed.connect(func(v):
		SimulationManager.update_setting(key, v)
		lbl.text = fmt % v
	)

func _bind_px(slider: HSlider, lbl: Label, key: String, fmt: String):
	slider.value_changed.connect(func(v):
		SimulationManager.update_setting(key, v * 40.0)
		lbl.text = fmt % v
	)

func _on_controller_toggled(pressed: bool):
	SimulationManager.update_setting("controller_mode", pressed)
	multiplayer_check.disabled = not pressed
	if not pressed and multiplayer_check.button_pressed:
		multiplayer_check.button_pressed = false

func _on_multiplayer_toggled(pressed: bool):
	SimulationManager.update_setting("multiplayer", pressed)

func _load_from_settings():
	width_slider.value = SimulationManager.settings.arena_width / 40.0
	height_slider.value = SimulationManager.settings.arena_height / 40.0
	width_value.text = "%d m" % width_slider.value
	height_value.text = "%d m" % height_slider.value
	controller_check.set_pressed_no_signal(SimulationManager.settings.get("controller_mode", false))
	multiplayer_check.set_pressed_no_signal(SimulationManager.settings.get("multiplayer", false))
	multiplayer_check.disabled = not controller_check.button_pressed

func _reset_defaults():
	for k in DEFAULTS:
		SimulationManager.update_setting(k, DEFAULTS[k])
	_load_from_settings()

func _fit_to_window():
	var s = get_viewport().size
	width_slider.value = s.x / 40.0
	height_slider.value = s.y / 40.0

func open():
	visible = true
	_load_from_settings()

func close():
	visible = false
