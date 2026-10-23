extends "res://levels/modes/FARPBase.gd"

const SPACING_FILL := 0.8
const DEFENDER_COUNT_OPTIONS := [5, 25, 50, 100, 250, 500]
const ATTRITION_DEFENDER_COUNT_OPTIONS := [5, 10, 15, 20]

var _rng := RandomNumberGenerator.new()
var _defender_count: int = RING_COUNT
var _count_picker: OptionButton

func _launch_label() -> String:
	return "LAUNCH EVADER (S) >"

func _setup_level():
	_rng.randomize()
	if not _defender_options().is_empty():
		_defender_count = _saved_defender_count()
	_add_top_button("REROLL (R)", _reroll_level)
	if not _defender_options().is_empty():
		_build_count_picker()
	_launch_btn.text = _launch_label()
	_place_saved_layout()

func _restart_level():
	_place_saved_layout()
	_phase_label.text = _level_title()
	_launch_btn.text = _launch_label()

# Only REROLL changes the layout: restarting or coming back from the workspace
# replays the scatter the player last rolled.
func _place_saved_layout():
	var saved: Array = PlayerData.get_level_placements(_level_id())
	if saved.is_empty():
		_roll_layout()
		return
	for placement in _placements_from_payload(saved):
		_placements.append(placement)
		_spawn_defender(placement, PlayerData.ship_blocks)
	_update_count()

func _roll_layout():
	for placement in _random_ring_placements(_scatter_count(), _rng):
		_placements.append(placement)
		_spawn_defender(placement, PlayerData.ship_blocks)
	_update_count()
	PlayerData.set_level_placements(_level_id(), _placements_payload())

func _defender_options() -> Array:
	return []

func _scatter_count() -> int:
	return _defender_count

func _scatter_spacing() -> float:
	var band_area: float = PI * (SCATTER_MAX * SCATTER_MAX - PLACE_MIN * PLACE_MIN)
	return minf(SCATTER_SPACING, sqrt(band_area / float(_defender_count)) * SPACING_FILL)

func _saved_defender_count() -> int:
	var options: Array = _defender_options()
	var saved_size: int = PlayerData.get_level_placements(_level_id()).size()
	return saved_size if options.has(saved_size) else options[0]

func _build_count_picker():
	var options: Array = _defender_options()
	_count_picker = OptionButton.new()
	_count_picker.focus_mode = Control.FOCUS_NONE
	HUD_BUTTONS.apply(_count_picker, HUD_BUTTONS.Kind.NEUTRAL, 9)
	for option in options:
		_count_picker.add_item("%d DEFENDERS" % option)
	_count_picker.select(options.find(_defender_count))
	_count_picker.item_selected.connect(_on_count_selected)
	_top_bar.add_child(_count_picker)

func _on_count_selected(index: int):
	var options: Array = _defender_options()
	if _phase != Phase.SETUP:
		_count_picker.select(options.find(_defender_count))
		return
	_defender_count = options[index]
	_reroll_level()

func _can_reroll() -> bool:
	return _phase == Phase.SETUP

func _reroll_level():
	if _phase != Phase.SETUP:
		return
	_clear_ships()
	_placements.clear()
	_rng.randomize()
	_roll_layout()
	queue_redraw()

func _draw_level():
	if _phase != Phase.SETUP:
		return
	draw_circle(_planet, _scatter_max_radius(), ZONE_FILL)
	_draw_dashed_circle(_planet, _scatter_max_radius(), Color(0.451, 0.616, 1.0, 0.35), 1.5)
	_draw_dashed_circle(_planet, PLACE_MIN, Color(0.6, 0.62, 0.74, 0.25), 1.0)
