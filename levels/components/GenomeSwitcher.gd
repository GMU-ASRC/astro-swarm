extends HBoxContainer

signal genome_switched(stage_index: int)

const GENOME_UPGRADES := preload("res://progression/GenomeUpgrades.gd")
const ACHIEVEMENTS := preload("res://achievements/Achievements.gd")

const COOLDOWN_SECONDS := 5.0
const FONT_SIZE := 9
const C_TEXT := Color(0.6, 0.62, 0.74, 1.0)
const C_BLOCKED := Color(0.9, 0.45, 0.45, 1.0)
const C_EMPTY_BOX := Color(1.0, 1.0, 1.0, 0.08)
const C_SELECTED_BORDER := Color(1.0, 1.0, 1.0, 1.0)
const C_IDLE_BORDER := Color(0.0, 0.0, 0.0, 0.45)
const BOX_SIZE := Vector2(26, 22)
const SELECTED_BORDER_WIDTH := 3
const IDLE_BORDER_WIDTH := 1
const DIMMED_ALPHA := 0.45
const EMPTY_BOX_TOOLTIP := "Set genomes active on the genome moon to fill this box."

static var carried: Dictionary = {}

var _boxes: HBoxContainer
var _status_label: Label
var _switches_left: int = 0
var _counting: bool = false
var _locked: bool = false
var _cooldown_left: float = 0.0
var _live_defenders: int = 0
var _last_switch_defenders: int = 0
var _schedule: Array = []

func _ready():
	add_theme_constant_override("separation", 6)
	_boxes = HBoxContainer.new()
	_boxes.add_theme_constant_override("separation", 4)
	_boxes.tooltip_text = "Switch the genome your defenders fly. After launch a switch needs a lost defender and a cooldown."
	add_child(_boxes)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_status_label)

	GenomeBank.genomes_changed.connect(_refresh_items)
	reset_switches()

func _process(delta: float):
	if _cooldown_left <= 0.0:
		return
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_update_status()

func reset_switches():
	GenomeBank.activate_loadout_start()
	_switches_left = GENOME_UPGRADES.switches_per_level()
	_counting = false
	_locked = false
	_cooldown_left = 0.0
	_schedule = []
	_refresh_items()

func start_counting(defenders: int):
	_counting = true
	_live_defenders = defenders
	_last_switch_defenders = defenders
	_cooldown_left = 0.0
	_schedule = [_stage_entry(defenders)]
	_refresh_items()

func is_counting() -> bool:
	return _counting

func update_defenders(defenders: int):
	if defenders == _live_defenders:
		return
	_live_defenders = defenders
	_update_status()

func lock():
	_locked = true
	_refresh_items()

func stage_index() -> int:
	return maxi(0, _schedule.size() - 1)

func schedule() -> Array:
	return _schedule.duplicate(true)

func carry():
	carried = {
		"switches_left": _switches_left,
		"cooldown_left": _cooldown_left,
		"last_switch_defenders": _last_switch_defenders,
		"schedule": _schedule.duplicate(true),
	}

func resume(state: Dictionary):
	_switches_left = int(state.get("switches_left", _switches_left))
	_cooldown_left = float(state.get("cooldown_left", 0.0))
	_last_switch_defenders = int(state.get("last_switch_defenders", 0))
	_schedule = state.get("schedule", []).duplicate(true)
	_counting = not _schedule.is_empty()
	_refresh_items()

func _can_switch() -> bool:
	if _locked:
		return false
	if not _counting:
		return true
	return _switches_left > 0 and _cooldown_left <= 0.0 and _live_defenders < _last_switch_defenders

func _on_box_pressed(genome_id: String):
	if genome_id == GenomeBank.active_id or not _can_switch():
		_refresh_items()
		return
	if _counting:
		_switches_left -= 1
		_cooldown_left = COOLDOWN_SECONDS
		_last_switch_defenders = _live_defenders
	GenomeBank.activate(genome_id)
	if _counting:
		_schedule.append(_stage_entry(_live_defenders))
		ACHIEVEMENTS.check_genome_switch()
	genome_switched.emit(stage_index())

func _stage_entry(defenders: int) -> Dictionary:
	return {
		"name": str(GenomeBank.active_genome().get("name", GenomeBank.DEFAULT_NAME)),
		"algorithm": PlayerData.get_ship_algorithm(),
		"at_defenders": defenders,
		"color": GenomeBank.active_color().to_html(false),
	}

func _refresh_items():
	if not is_instance_valid(_boxes):
		return
	for box in _boxes.get_children():
		box.queue_free()
	var picked: Array = GenomeBank.loadout_genomes()
	for slot in GenomeBank.loadout_limit():
		if slot < picked.size():
			_boxes.add_child(_genome_box(picked[slot]))
		else:
			_boxes.add_child(_empty_box())
	_update_status()

func _genome_box(genome: Dictionary) -> Button:
	var genome_id: String = genome["id"]
	var is_current: bool = genome_id == GenomeBank.active_id
	var box := Button.new()
	box.custom_minimum_size = BOX_SIZE
	box.focus_mode = Control.FOCUS_NONE
	box.tooltip_text = "GENOME: %s" % str(genome["name"]).to_upper()
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box.set_meta("genome_id", genome_id)
	var color: Color = GenomeBank.genome_color(genome)
	var border_color: Color = C_SELECTED_BORDER if is_current else C_IDLE_BORDER
	var border_width: int = SELECTED_BORDER_WIDTH if is_current else IDLE_BORDER_WIDTH
	box.add_theme_stylebox_override("normal", _box_style(color, border_color, border_width))
	box.add_theme_stylebox_override("hover", _box_style(color.lightened(0.2), border_color, border_width))
	box.add_theme_stylebox_override("pressed", _box_style(color.darkened(0.2), border_color, border_width))
	box.add_theme_stylebox_override("disabled", _box_style(Color(color, DIMMED_ALPHA), border_color, border_width))
	box.pressed.connect(func(): _on_box_pressed(genome_id))
	return box

func _empty_box() -> Panel:
	var box := Panel.new()
	box.custom_minimum_size = BOX_SIZE
	box.tooltip_text = EMPTY_BOX_TOOLTIP
	box.add_theme_stylebox_override("panel", _box_style(C_EMPTY_BOX, C_IDLE_BORDER, IDLE_BORDER_WIDTH))
	return box

func _box_style(fill: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(3)
	return style

func _update_status():
	if not is_instance_valid(_status_label):
		return
	var total: int = GENOME_UPGRADES.switches_per_level()
	var blocked: bool = _counting and not _can_switch()
	for box in _boxes.get_children():
		if box is Button:
			box.disabled = (_locked or blocked) and box.get_meta("genome_id") != GenomeBank.active_id
	if not _counting or _locked:
		_status_label.text = "%d/%d SWITCHES" % [_switches_left, total]
	elif _switches_left <= 0:
		_status_label.text = "NO SWITCHES LEFT"
	elif _cooldown_left > 0.0:
		_status_label.text = "COOLDOWN %dS" % ceili(_cooldown_left)
	elif _live_defenders >= _last_switch_defenders:
		_status_label.text = "LOSE A DEFENDER TO SWITCH"
	else:
		_status_label.text = "%d/%d SWITCHES" % [_switches_left, total]
	_status_label.add_theme_color_override("font_color", C_BLOCKED if blocked else C_TEXT)
