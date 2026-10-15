extends HBoxContainer

signal genome_switched(stage_index: int)

const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")
const GENOME_UPGRADES := preload("res://progression/GenomeUpgrades.gd")
const ACHIEVEMENTS := preload("res://achievements/Achievements.gd")

const COOLDOWN_SECONDS := 5.0
const FONT_SIZE := 9
const C_TEXT := Color(0.6, 0.62, 0.74, 1.0)
const C_BLOCKED := Color(0.9, 0.45, 0.45, 1.0)

const STAGE_COLORS := [
	Color(0.451, 0.616, 1.0, 1.0),
	Color(0.31, 0.82, 0.55, 1.0),
	Color(1.0, 0.70, 0.28, 1.0),
	Color(0.79, 0.48, 1.0, 1.0),
	Color(0.31, 0.85, 0.88, 1.0),
	Color(1.0, 0.48, 0.66, 1.0),
	Color(0.83, 0.88, 0.34, 1.0),
	Color(1.0, 0.54, 0.40, 1.0),
	Color(0.56, 0.64, 0.68, 1.0),
]

static var carried: Dictionary = {}

var _option: OptionButton
var _status_label: Label
var _switches_left: int = 0
var _counting: bool = false
var _locked: bool = false
var _cooldown_left: float = 0.0
var _live_defenders: int = 0
var _last_switch_defenders: int = 0
var _schedule: Array = []

static func stage_color(stage_index: int) -> Color:
	return STAGE_COLORS[clampi(stage_index, 0, STAGE_COLORS.size() - 1)]

func _ready():
	add_theme_constant_override("separation", 6)
	_option = OptionButton.new()
	_option.focus_mode = Control.FOCUS_NONE
	_option.tooltip_text = "Switch the genome your defenders fly. After launch a switch needs a lost defender and a cooldown."
	HUD_BUTTONS.apply(_option, HUD_BUTTONS.Kind.NEUTRAL, FONT_SIZE)
	_option.item_selected.connect(_on_selected)
	add_child(_option)

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

func _on_selected(index: int):
	var genome_id: String = str(_option.get_item_metadata(index))
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
	}

func _refresh_items():
	if not is_instance_valid(_option):
		return
	_option.clear()
	for index in GenomeBank.genomes.size():
		var genome: Dictionary = GenomeBank.genomes[index]
		_option.add_item("GENOME: %s" % str(genome["name"]).to_upper(), index)
		_option.set_item_metadata(index, genome["id"])
		if genome["id"] == GenomeBank.active_id:
			_option.select(index)
	_update_status()

func _update_status():
	if not is_instance_valid(_status_label):
		return
	var total: int = GENOME_UPGRADES.switches_per_level()
	var blocked: bool = _counting and not _can_switch()
	_option.disabled = _locked or blocked or GenomeBank.genome_count() < 2
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
