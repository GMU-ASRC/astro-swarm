extends CanvasLayer

signal request_stop

@onready var time_label:  Label = $Panel/HBox/TimeLabel
@onready var replay_slider: HSlider = $Panel/HBox/ReplaySlider
@onready var count_label: Label = $Panel/HBox/CountLabel
@onready var play_btn:    Button = $Panel/HBox/PlayButton
@onready var stop_btn:    Button = $Panel/HBox/StopButton
@onready var speed_1x:    Button = $Panel/HBox/SpeedBox/Speed1x
@onready var speed_2x:    Button = $Panel/HBox/SpeedBox/Speed2x
@onready var speed_3x:    Button = $Panel/HBox/SpeedBox/Speed3x

var _last_paused: bool = true
var _last_started: bool = false
var _is_slider_dragging: bool = false
var _export_mode: bool = false

func _ready():
	play_btn.pressed.connect(_on_play_pressed)
	stop_btn.pressed.connect(func(): request_stop.emit())
	speed_1x.pressed.connect(func(): _set_speed(1.0))

	replay_slider.drag_started.connect(func(): _is_slider_dragging = true)
	replay_slider.drag_ended.connect(func(_vc): _is_slider_dragging = false)
	replay_slider.value_changed.connect(_on_slider_changed)
	speed_2x.pressed.connect(func(): _set_speed(2.0))
	speed_3x.pressed.connect(func(): _set_speed(3.0))
	_refresh_play_text()
	_refresh_speed_buttons()

func _process(_delta):
	if SimulationManager.is_replaying:
		time_label.text  = _fmt(SimulationManager.replay_time)
		if not _export_mode:
			replay_slider.visible = true
			count_label.visible = false
			if not _is_slider_dragging:
				var max_time = SimulationManager.current_replay.size() * SimulationManager.RECORD_INTERVAL
				replay_slider.max_value = max_time
				replay_slider.value = SimulationManager.replay_time
	else:
		time_label.text  = _fmt(SimulationManager.simulation_time)
		if not _export_mode:
			replay_slider.visible = false
			count_label.visible = true

	if _export_mode:
		return

	count_label.text = "%d" % get_tree().get_nodes_in_group("robots").size()
	if get_tree().paused != _last_paused or SimulationManager.has_started != _last_started:
		_last_paused  = get_tree().paused
		_last_started = SimulationManager.has_started
		_refresh_play_text()

func _on_slider_changed(val: float):
	if _is_slider_dragging:
		SimulationManager.replay_time = val

func _on_play_pressed():
	if not SimulationManager.has_started:
		SimulationManager.has_started = true
		if not SimulationManager.is_replaying:
			SimulationManager.start_recording()
	get_tree().paused = not get_tree().paused

func _set_speed(scale: float):
	SimulationManager.update_setting("time_scale", scale)
	_refresh_speed_buttons()

func _refresh_speed_buttons():
	var ts: float = SimulationManager.settings.time_scale
	speed_1x.disabled = is_equal_approx(ts, 1.0)
	speed_2x.disabled = is_equal_approx(ts, 2.0)
	speed_3x.disabled = is_equal_approx(ts, 3.0)

func _refresh_play_text():
	stop_btn.visible = SimulationManager.has_started and not get_tree().paused
	if not SimulationManager.has_started or get_tree().paused:
		play_btn.text = "▶"
		play_btn.tooltip_text = "Start" if not SimulationManager.has_started else "Resume"
	else:
		play_btn.text = "⏸"
		play_btn.tooltip_text = "Pause"

func _fmt(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%02d:%02d" % [m, s]

func set_minimal_for_export(enabled: bool):
	_export_mode = enabled
	replay_slider.visible = not enabled
	count_label.visible = not enabled
	speed_1x.visible = not enabled
	speed_2x.visible = not enabled
	speed_3x.visible = not enabled
	play_btn.visible = not enabled
	stop_btn.visible = not enabled
	$Panel/HBox/VSep1.visible = not enabled
	$Panel/HBox/VSep2.visible = not enabled
